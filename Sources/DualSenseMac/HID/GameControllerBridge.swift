import Foundation
import GameController
import CoreHaptics

/// Wraps Apple's `GameController.framework` so we can drive the lightbar via the
/// system-supported path. Raw HID output reports work for rumble + triggers but
/// macOS 26 silently filters our lightbar writes — Apple's `GCDeviceLight` API
/// is the only reliable way to change lightbar color on this OS.
@MainActor
final class GameControllerBridge {
    private(set) var controller: GCController?
    var onAttach: (() -> Void)?

    init() {
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil, queue: .main
        ) { [weak self] note in
            Task { @MainActor in
                if let c = note.object as? GCController { self?.handleConnect(c) }
            }
        }
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil, queue: .main
        ) { [weak self] note in
            Task { @MainActor in
                if let c = note.object as? GCController { self?.handleDisconnect(c) }
            }
        }
        // Pick up controllers that were already paired before the app launched.
        for c in GCController.controllers() { handleConnect(c) }
    }

    private func handleConnect(_ c: GCController) {
        guard c.extendedGamepad is GCDualSenseGamepad
              || (c.vendorName ?? "").lowercased().contains("dualsense") else {
            return
        }
        controller = c
        NSLog("GameControllerBridge: attached to %@ (light=%@, haptics=%@)",
              c.vendorName ?? "?",
              c.light != nil ? "yes" : "no",
              c.haptics != nil ? "yes" : "no")
        setupHaptics(for: c)
        onAttach?()
    }

    private func handleDisconnect(_ c: GCController) {
        if controller === c {
            controller = nil
            try? leftPlayer?.stop(atTime: 0)
            try? rightPlayer?.stop(atTime: 0)
            leftPlayer = nil
            rightPlayer = nil
            leftHaptic?.stop(completionHandler: nil)
            rightHaptic?.stop(completionHandler: nil)
            leftHaptic = nil
            rightHaptic = nil
        }
    }

    /// Build per-handle CHHapticEngine instances. DualSense exposes
    /// `.leftHandle` and `.rightHandle` as separate haptic localities so we can
    /// drive the two motors independently — Apple's official path for rumble.
    private func setupHaptics(for c: GCController) {
        guard let h = c.haptics else {
            NSLog("GCBridge.setupHaptics: controller has no haptics support")
            return
        }
        if h.supportedLocalities.contains(.leftHandle) {
            leftHaptic = h.createEngine(withLocality: .leftHandle)
            try? leftHaptic?.start()
            leftHaptic?.resetHandler = { [weak self] in
                try? self?.leftHaptic?.start()
            }
        }
        if h.supportedLocalities.contains(.rightHandle) {
            rightHaptic = h.createEngine(withLocality: .rightHandle)
            try? rightHaptic?.start()
            rightHaptic?.resetHandler = { [weak self] in
                try? self?.rightHaptic?.start()
            }
        }
        NSLog("GCBridge.setupHaptics: leftHaptic=%@ rightHaptic=%@",
              leftHaptic == nil ? "nil" : "ok",
              rightHaptic == nil ? "nil" : "ok")
    }

    /// Drive both rumble motors via Apple's haptic engines. Replaces our raw
    /// HID rumble bytes when the official path is available — should fix the
    /// "right motor doesn't rumble" issue caused by macOS filtering raw HID writes.
    func setRumble(_ rumble: RumbleState) {
        let key = (rumble.leftStrength, rumble.rightStrength)
        if key == lastRumble { return }
        lastRumble = key

        applyHaptic(strength: rumble.leftStrength,
                    engine: leftHaptic,
                    player: &leftPlayer,
                    label: "left")
        applyHaptic(strength: rumble.rightStrength,
                    engine: rightHaptic,
                    player: &rightPlayer,
                    label: "right")
    }

    private func applyHaptic(strength: UInt8,
                             engine: CHHapticEngine?,
                             player: inout CHHapticAdvancedPatternPlayer?,
                             label: String) {
        guard let engine = engine else { return }
        // Stop any in-flight player; we replace the pattern entirely each call.
        try? player?.stop(atTime: 0)
        player = nil

        if strength == 0 {
            NSLog("GCBridge.haptic.%@: stop", label)
            return
        }
        let intensity = Float(strength) / 255.0
        let intParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
        let sharpParam = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [intParam, sharpParam],
            relativeTime: 0,
            duration: 30 // long; we'll stop it explicitly when strength goes to 0
        )
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let p = try engine.makeAdvancedPlayer(with: pattern)
            try p.start(atTime: CHHapticTimeImmediate)
            player = p
            NSLog("GCBridge.haptic.%@: start intensity=%.2f", label, intensity)
        } catch {
            NSLog("GCBridge.haptic.%@: error %@", label, error.localizedDescription)
        }
    }

    private var lastLightbarApplied: (UInt8, UInt8, UInt8)?
    private var lastLeftTrigger: TriggerEffect?
    private var lastRightTrigger: TriggerEffect?
    private var rightLogCount = 0
    private var leftLogCount = 0
    private var leftHaptic: CHHapticEngine?
    private var rightHaptic: CHHapticEngine?
    private var leftPlayer: CHHapticAdvancedPatternPlayer?
    private var rightPlayer: CHHapticAdvancedPatternPlayer?
    private var lastRumble: (UInt8, UInt8) = (0, 0)

    /// Sets the lightbar via `GCDeviceLight.color` — only when the color
    /// actually changes. Hammering this property at 30 Hz appears to cause
    /// subsequent writes to be silently coalesced/ignored on macOS 26.
    func setLightbar(_ color: LightbarColor) {
        guard let c = controller else { return }
        guard let light = c.light else { return }
        let key = (color.red, color.green, color.blue)
        if let last = lastLightbarApplied, last == key { return }
        lastLightbarApplied = key
        light.color = GCColor(
            red: Float(color.red) / 255.0,
            green: Float(color.green) / 255.0,
            blue: Float(color.blue) / 255.0
        )
        NSLog("GCBridge.setLightbar: set to (%d,%d,%d)", color.red, color.green, color.blue)
    }

    /// Sets adaptive trigger effects via Apple's official `GCDualSenseAdaptiveTrigger`.
    /// Re-applies every call (no dedup) so the framework can't lose the mode
    /// between renders, and so changes via the UI take effect immediately.
    func setTriggers(left: TriggerEffect, right: TriggerEffect) {
        guard let c = controller,
              let dualsense = c.physicalInputProfile as? GCDualSenseGamepad else {
            return
        }
        // Always re-apply both. Log only when value changes (to keep log readable)
        // or the first 3 times after attach (to confirm fire path).
        let leftChanged = lastLeftTrigger != left
        let rightChanged = lastRightTrigger != right
        apply(effect: left, to: dualsense.leftTrigger, label: "L2",
              shouldLog: leftChanged || leftLogCount < 3)
        apply(effect: right, to: dualsense.rightTrigger, label: "R2",
              shouldLog: rightChanged || rightLogCount < 3)
        if leftChanged { leftLogCount = 0 }
        if rightChanged { rightLogCount = 0 }
        leftLogCount += 1
        rightLogCount += 1
        lastLeftTrigger = left
        lastRightTrigger = right
    }

    private func apply(effect: TriggerEffect,
                       to trigger: GCDualSenseAdaptiveTrigger,
                       label: String,
                       shouldLog: Bool = true) {
        // GCDualSenseAdaptiveTrigger position params are Float 0.0..1.0.
        // Our internal 0..9 / 0..8 ranges map proportionally.
        switch effect {
        case .off:
            trigger.setModeOff()
            if shouldLog { NSLog("GCBridge.%@: off", label) }

        case .feedback(let position, let strength):
            let pos = Float(min(position, 9)) / 9.0
            let str = Float(min(strength, 8)) / 8.0
            trigger.setModeFeedbackWithStartPosition(pos, resistiveStrength: str)
            if shouldLog { NSLog("GCBridge.%@: feedback pos=%.2f str=%.2f", label, pos, str) }

        case .weapon(let start, let end, let strength):
            let s = Float(max(2, min(start, 7))) / 9.0
            let e = Float(max(start + 1, min(end, 8))) / 9.0
            let str = Float(min(strength, 8)) / 8.0
            trigger.setModeWeaponWithStartPosition(s, endPosition: e, resistiveStrength: str)
            if shouldLog { NSLog("GCBridge.%@: weapon s=%.2f e=%.2f str=%.2f", label, s, e, str) }

        case .vibration(let frequency, let position, let amplitude):
            let pos = Int(min(position, 9))
            let amp = Float(min(amplitude, 8)) / 8.0
            let freq = Float(max(1, frequency))
            func a(_ i: Int) -> Float { i >= pos ? amp : 0 }
            let amps = GCDualSenseAdaptiveTrigger.PositionalAmplitudes(values: (
                a(0), a(1), a(2), a(3), a(4),
                a(5), a(6), a(7), a(8), a(9)
            ))
            trigger.setModeVibration(amplitudes: amps, frequency: freq)
            if shouldLog { NSLog("GCBridge.%@: vibration startPos=%d amp=%.2f freq=%.0f", label, pos, amp, freq) }

        case .slope(let start, let end, let startStrength, let endStrength):
            let s = Float(min(start, 8)) / 9.0
            let e = Float(max(start + 1, min(end, 9))) / 9.0
            let ss = Float(min(startStrength, 8)) / 8.0
            let es = Float(min(endStrength, 8)) / 8.0
            trigger.setModeSlopeFeedback(
                startPosition: s, endPosition: e,
                startStrength: ss, endStrength: es)
            if shouldLog { NSLog("GCBridge.%@: slope s=%.2f e=%.2f ss=%.2f es=%.2f",
                                 label, s, e, ss, es) }
        }
    }
}
