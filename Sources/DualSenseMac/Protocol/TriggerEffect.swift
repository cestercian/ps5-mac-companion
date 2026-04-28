import Foundation

/// DualSense adaptive-trigger effects.
///
/// Byte encoding follows the rafaelvaloto/Dualsense-Multiplatform reference
/// (verified working on macOS / Windows / Linux). Each effect produces an
/// 11-byte buffer: `[mode][param0]...[param9]`.
///
/// Mode IDs are Sony's documented values:
///   0x00  Reset / off
///   0x01  Continuous resistance (single-position constant force)
///   0x21  Section resistance (start..end, with start/mid/end strength)
///   0x25  Weapon (resistance + snap-back at trip point)
///   0x26  Automatic gun / vibration (frequency + amplitude in active region)
enum TriggerEffect: Equatable, Codable, Hashable {
    case off
    case feedback(position: UInt8, strength: UInt8)
    case weapon(start: UInt8, end: UInt8, strength: UInt8)
    case vibration(frequency: UInt8, position: UInt8, amplitude: UInt8)
    case slope(start: UInt8, end: UInt8, startStrength: UInt8, endStrength: UInt8)

    static let allKinds: [TriggerEffect] = [
        .off,
        .feedback(position: 2, strength: 6),
        .weapon(start: 2, end: 6, strength: 8),
        .vibration(frequency: 30, position: 2, amplitude: 6),
        .slope(start: 1, end: 8, startStrength: 1, endStrength: 8)
    ]

    var displayName: String {
        switch self {
        case .off: return "Off"
        case .feedback: return "Feedback"
        case .weapon: return "Weapon"
        case .vibration: return "Vibration"
        case .slope: return "Slope"
        }
    }

    /// Encode into the 11 bytes that get copied into the output report at
    /// offsets 10..20 (right trigger) and 21..31 (left trigger).
    func encode() -> [UInt8] {
        var t = [UInt8](repeating: 0, count: 11)
        switch self {
        case .off:
            // Mode 0x00: reset trigger to default (no resistance).
            t[0] = 0x00

        case .feedback(let position, let strength):
            // Mode 0x21: uniform resistance from `position` to end of trigger.
            // Use start/mid/end strength all equal so the resistance is constant
            // across the active region.
            let pos = min(position, 9)
            let str = scaleStrength(strength)
            t[0] = 0x21
            t[1] = pos
            t[2] = 9
            t[3] = str
            t[5] = str
            t[6] = str

        case .weapon(let start, let end, let strength):
            // Mode 0x25: weapon trigger. Resistance from `start` to `end`,
            // snap-back past `end`. Three simple parameters — no bitmask.
            let s = max(2, min(start, 7))
            let e = max(s + 1, min(end, 8))
            t[0] = 0x25
            t[1] = s
            t[2] = e
            t[3] = scaleStrength(strength)

        case .vibration(let frequency, let position, let amplitude):
            // Mode 0x26: automatic-gun-style vibration in active region.
            let pos = min(position, 9)
            t[0] = 0x26
            t[1] = pos
            t[2] = 9
            t[3] = scaleStrength(amplitude)
            t[9] = max(1, frequency)  // frequency in Hz; 0 disables the effect

        case .slope(let start, let end, let startStrength, let endStrength):
            // Mode 0x21 with varying strength — start/mid/end positions of the
            // strength ramp across the resistance region.
            let s = min(start, 8)
            let e = max(s + 1, min(end, 9))
            let ss = scaleStrength(startStrength)
            let es = scaleStrength(endStrength)
            t[0] = 0x21
            t[1] = s
            t[2] = e
            t[3] = ss
            t[5] = UInt8((UInt16(ss) + UInt16(es)) / 2)
            t[6] = es
        }
        return t
    }

    /// UI exposes 0..8 as a "human" strength scale; the controller takes a full
    /// byte (0..255). Multiply through with saturation so the slider has range.
    private func scaleStrength(_ ui: UInt8) -> UInt8 {
        let scaled = UInt32(ui) * 32
        return UInt8(min(scaled, 255))
    }
}
