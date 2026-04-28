import Foundation

struct PlayerLED: Equatable, Codable {
    enum Pattern: UInt8, CaseIterable, Codable {
        case off = 0
        case player1 = 0b00100  // center LED
        case player2 = 0b01010
        case player3 = 0b10101
        case player4 = 0b11011
        case all     = 0b11111

        var displayName: String {
            switch self {
            case .off: return "Off"
            case .player1: return "Player 1"
            case .player2: return "Player 2"
            case .player3: return "Player 3"
            case .player4: return "Player 4"
            case .all: return "All on"
            }
        }
    }

    enum Brightness: UInt8, CaseIterable, Codable {
        case high = 0, medium = 1, low = 2

        var displayName: String {
            switch self {
            case .high: return "High"
            case .medium: return "Medium"
            case .low: return "Low"
            }
        }
    }

    var pattern: Pattern = .off
    var brightness: Brightness = .medium
}
