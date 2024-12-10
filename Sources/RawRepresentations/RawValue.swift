@attached(peer, conformances: RawRepresentable, names: named(init(rawValue:)))
public macro RawValue() = #externalMacro(
    module: "RawRepresentationsMacros",
    type: "RawValueMacro"
)
