import Foundation

struct Profile: Codable, Equatable {
    var name: String = "Default"
    var lightbar: LightbarColor = .debugMagenta
    var leftTrigger: TriggerEffect = .off
    var rightTrigger: TriggerEffect = .off
    var rumble: RumbleState = .off
    var playerLED = PlayerLED()
    var micLED: MicLED = .off

    static let defaultProfile = Profile()
}
