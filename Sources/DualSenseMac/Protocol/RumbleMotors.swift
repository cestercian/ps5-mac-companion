import Foundation

struct RumbleState: Equatable, Codable {
    var leftStrength: UInt8 = 0   // low-frequency motor
    var rightStrength: UInt8 = 0  // high-frequency motor

    static let off = RumbleState()
}
