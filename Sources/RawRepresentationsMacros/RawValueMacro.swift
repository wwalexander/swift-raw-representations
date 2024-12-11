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
        guard let variableDeclaration = declaration.as(VariableDeclSyntax.self) else {
            return []
        }

        let rewriter = Rewriter()
        return [rewriter.visit(variableDeclaration)]
    }
}

final class Rewriter: SyntaxRewriter {
    override func visit(_ node: VariableDeclSyntax) -> DeclSyntax {
        guard
            let binding = node.bindings.first,
            let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier,
            let type = binding.typeAnnotation?.type,
            let switchExpression = binding
                .accessorBlock?
                .accessors
                .as(CodeBlockItemListSyntax.self)?
                .first?
                .item
                .as(ExpressionStmtSyntax.self)?
                .expression
                .as(SwitchExprSyntax.self)
        else {
            return DeclSyntax(node)
        }

        let publicModifier = node
            .modifiers
            .first { $0.name == .keyword(.public) }

        return DeclSyntax(
            InitializerDeclSyntax(
                modifiers: DeclModifierListSyntax {
                    if let publicModifier {
                        publicModifier
                    }
                },
                optionalMark: .postfixQuestionMarkToken(),
                signature: FunctionSignatureSyntax(parameterClause: FunctionParameterClauseSyntax(
                    parameters: .init {
                        .init(firstName: identifier, type: type)
                    }
                ))
            ) {
                visit(switchExpression)
            }
        )
    }


    override func visit(_ node: SwitchExprSyntax) -> ExprSyntax {
        var cases = visit(node.cases)

        cases.append(
            .switchCase(
                SwitchCaseSyntax(
                    label: .default(
                        SwitchDefaultLabelSyntax()
                    ),
                    statements: CodeBlockItemListSyntax {
                        CodeBlockItemSyntax(
                            item: CodeBlockItemSyntax.Item.stmt(
                                StmtSyntax(
                                    ReturnStmtSyntax(
                                        expression: ExprSyntax(
                                            NilLiteralExprSyntax()
                                        )
                                    )
                                )
                            )
                        )
                    }
                )
            )
        )

        return ExprSyntax(
            SwitchExprSyntax(
                subject: DeclReferenceExprSyntax(baseName: .identifier("rawValue")),
                cases: cases
            )
        )
    }

    override func visit(_ node: SwitchCaseSyntax) -> SwitchCaseSyntax {
        guard
            let previousLabel = node
                .label
                .as(SwitchCaseLabelSyntax.self)?
                .caseItems
                .first?
                .pattern
                .as(ExpressionPatternSyntax.self)?
                .expression,
            let previousStatements = node
                .statements
                .first?
                .item
                .as(ExprSyntax.self)
        else {
            return SwitchCaseSyntax(
                label: .case(
                    SwitchCaseLabelSyntax(
                        caseItems: SwitchCaseItemListSyntax {
                            SwitchCaseItemSyntax(pattern: WildcardPatternSyntax())
                        }
                    )
                )
            ) {
                BreakStmtSyntax()
            }
        }


        return SwitchCaseSyntax(
            label: .case(
                SwitchCaseLabelSyntax {
                    SwitchCaseItemListSyntax {
                        SwitchCaseItemSyntax(
                            pattern: ExpressionPatternSyntax(
                                expression: previousStatements
                            )
                        )
                    }
                }
            )
        ) {
            SequenceExprSyntax {
                DeclReferenceExprSyntax(baseName: .identifier("self"))
                AssignmentExprSyntax()
                previousLabel
            }
        }
    }
}
