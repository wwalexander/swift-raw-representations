import RawRepresentations

final class RaceClass {
    enum ID: UInt8, CaseIterable {
        case coupes
        case sports

        @RawValue var rawValue: String {
            switch self {
            case .coupes: "cou"
            case .sports: "spo"
            }
        }
    }
}

