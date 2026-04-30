import Foundation

struct Profile: Codable, Equatable {
    var name: String = "Default"
    var lightbar: LightbarColor = .debugMagenta
    var leftTrigger: TriggerEffect = .off
    var rightTrigger: TriggerEffect = .off
    var rumble: RumbleState = .off
    var playerLED = PlayerLED()
    var micLED: MicLED = .off

    /// When true, AppState's NotificationWatcher polls the macOS Notification
    /// Center DB and fires a rumble pulse for each new notification.
    var notificationsEnabled: Bool = false
    /// Length of the rumble pulse (in milliseconds) fired per notification.
    var notificationRumbleDurationMs: Int = 3000
    /// Strength (0–255) of the notification pulse, applied to BOTH motors.
    var notificationRumbleStrength: UInt8 = 200

    static let defaultProfile = Profile()
}
