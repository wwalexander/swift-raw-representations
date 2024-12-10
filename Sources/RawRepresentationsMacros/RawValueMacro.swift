import SwiftDiagnostics
import SwiftCompilerPlugin
import SwiftSyntaxBuilder
import SwiftSyntax
import SwiftSyntaxMacros

@main
struct RawRepresentationsMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        RawValueMacro.self,
    ]
}

struct RawValueMacro: PeerMacro {
    static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws(DiagnosticsError) -> [DeclSyntax] {
        guard let variableDeclaration = declaration.as(VariableDeclSyntax.self)
        else { throw .init(.requiresVariableDeclaration, declaration) }

        guard let binding = variableDeclaration.bindings.first
        else { throw .init(.requiresBinding, variableDeclaration.bindings) }

        guard let typeAnnotation = binding.typeAnnotation
        else { throw .init(.requiresTypeAnnotation, binding) }

        let rawType = typeAnnotation.type

        guard let accessorBlock = binding.accessorBlock
        else { throw .init(.requiresAccessorBlock, binding) }

        guard let codeBlock = accessorBlock.accessors.as(CodeBlockItemListSyntax.self)
        else { throw .init(.requiresCodeBlock, accessorBlock.accessors) }

        guard let codeBlockItem = codeBlock.first
        else { throw .init(.requiresCodeBlockItem, codeBlock) }

        guard let expressionStatement = codeBlockItem.item.as(ExpressionStmtSyntax.self)
        else { throw .init(.requiresCodeBlockItemExpression, codeBlockItem.item) }

        guard let switchExpression = expressionStatement.expression.as(SwitchExprSyntax.self)
        else { throw .init(.requiresSwitch, expressionStatement.expression) }


        guard let switchSubject = switchExpression.subject.as(DeclReferenceExprSyntax.self),
              case "self" = switchSubject.baseName.text
        else { throw .init(.requiresSwitchSubject, switchExpression.subject) }

        var codeBlockItems: [CodeBlockItemSyntax] = []

        for element in switchExpression.cases {
            guard let `case` = element.as(SwitchCaseSyntax.self)
            else { throw .init(.requiresSwitchCase, element)}

            guard let label = `case`.label.as(SwitchCaseLabelSyntax.self)
            else { throw .init(.requiresSwitchCaseLabel, `case`.label) }

            let caseItems = label.caseItems

            guard let item = caseItems.first,
                  caseItems.dropFirst().isEmpty
            else { throw .init(.requiresSwitchCaseLabelItem, caseItems) }

            let pattern = item.pattern

            let statements = `case`.statements

            guard let statement = statements.first,
                  statements.dropFirst().isEmpty
            else { throw .init(.requiresSwitchCaseStatement, statements) }

            guard let expression = statement.item.as(ExprSyntax.self)
            else { throw .init(.requiresSwitchCaseStatementItem, statement.item) }

            codeBlockItems.append(
                "case \(expression): self = \(pattern)"
            )
        }

        return [
            DeclSyntax(
                InitializerDeclSyntax(
                    optionalMark: .postfixQuestionMarkToken(),
                    signature: .init(
                        parameterClause: .init(
                            parameters: .init {
                                .init(
                                    firstName: .identifier("rawValue"),
                                    type: rawType
                                )
                            }
                        )
                    ),
                    body: .init {
                        .init {
                            CodeBlockItemListSyntax {
                                "switch rawValue {"
                                codeBlockItems
                                "default: return nil"
                                "}"
                            }
                        }
                    }
                )
            )
        ]
    }
}

enum RawRepresentableMacroDiagnostic: DiagnosticMessage {
    case requiresVariableDeclaration
    case requiresBinding
    case requiresTypeAnnotation
    case requiresAccessorBlock
    case requiresCodeBlock
    case requiresCodeBlockItem
    case requiresCodeBlockItemExpression
    case requiresSwitch
    case requiresSwitchSubject
    case requiresSwitchCase
    case requiresSwitchCaseLabel
    case requiresSwitchCaseLabelItem
    case requiresSwitchCaseStatement
    case requiresSwitchCaseStatementItem

    var message: String {
        switch self {
        case .requiresVariableDeclaration: "RawRepresentable macro requires a variable declaration"
        case .requiresBinding: "Variable declaration requires a binding"
        case .requiresTypeAnnotation: "Binding requires a type annotation"
        case .requiresAccessorBlock: "Binding requires an accessor block"
        case .requiresCodeBlock: "Accessor block requires a code block"
        case .requiresCodeBlockItem: "Code block requires an item"
        case .requiresCodeBlockItemExpression: "Item requires an expression"
        case .requiresSwitch: "Expression requires a switch expression"
        case .requiresSwitchSubject: "Switch expression requires a subject"
        case .requiresSwitchCase: "Switch expression requires a case"
        case .requiresSwitchCaseLabel: "Switch case requires a label"
        case .requiresSwitchCaseLabelItem: "Switch case label requires an item"
        case .requiresSwitchCaseStatement: "Switch case requires a statement"
        case .requiresSwitchCaseStatementItem: "Switch case statement requires an item"
        }
    }

    var severity: DiagnosticSeverity {
        .error
    }

    var diagnosticID: MessageID {
        .init(domain: "Swift", id: "RawRepresentable.\(self)")
    }
}

fileprivate extension DiagnosticsError {
    init(
        _ message: RawRepresentableMacroDiagnostic,
        _ node: some SyntaxProtocol
    ) {
        self.init(
            diagnostics: [
                .init(
                    node: node,
                    message: message
                )
            ]
        )
    }
}
