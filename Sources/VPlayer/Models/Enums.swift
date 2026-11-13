import Foundation

enum RepeatMode: String, CaseIterable, Identifiable {
    case off
    case all
    case one

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: return "Repetir desligado"
        case .all: return "Repetir todos"
        case .one: return "Repetir a atual"
        }
    }

    var symbol: String {
        switch self {
        case .off, .all: return "repeat"
        case .one: return "repeat.1"
        }
    }
}

enum EQPreset: String, CaseIterable, Identifiable {
    case flat
    case rock
    case pop
    case jazz
    case classical
    case bass
    case vocal
    case electronic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .flat: return "Flat"
        case .rock: return "Rock"
        case .pop: return "Pop"
        case .jazz: return "Jazz"
        case .classical: return "Clássico"
        case .bass: return "Bass Boost"
        case .vocal: return "Vocal"
        case .electronic: return "Eletrônico"
        }
    }

    var gains: [Float] {
        switch self {
        case .flat: return [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        case .rock: return [4.5, 3.5, 1.5, -1, -1.5, 0, 2.5, 4, 4.5, 4]
        case .pop: return [-1, 1, 3, 4, 3, 0, -1, -1, 0, 1]
        case .jazz: return [3, 2, 1, 2, -1, -1, 0, 1, 3, 3]
        case .classical: return [4, 3, 2, 0, -1, -1, 0, 2, 3, 4]
        case .bass: return [7, 6, 5, 3, 1, 0, 0, 0, 0, 0]
        case .vocal: return [-3, -2, 0, 2, 4, 4, 3, 1, 0, -1]
        case .electronic: return [5, 4, 1, 0, -2, 1, 1, 0, 3, 5]
        }
    }
}

enum EQBand {
    static let frequencies: [Float] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]

    static func label(_ value: Float) -> String {
        if value >= 1000 {
            let kilo = value / 1000
            return kilo == kilo.rounded() ? "\(Int(kilo))k" : String(format: "%.1fk", kilo)
        }
        return "\(Int(value))"
    }
}
