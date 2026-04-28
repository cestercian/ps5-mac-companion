import Foundation

enum MicLED: UInt8, CaseIterable, Codable {
    case off = 0
    case on = 1
    case pulse = 2

    var displayName: String {
        switch self {
        case .off: return "Off"
        case .on: return "On"
        case .pulse: return "Pulse"
        }
    }
}
