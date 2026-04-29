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
        // Extract sendable values (GCController is reference-typed and safe to
        // pass across actors; Notification is not Sendable so we never close
        // over it inside an async hop).
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil, queue: .main
        ) { [weak self] note in
            let c = note.object as? GCController
            DispatchQueue.main.async { [weak self] in
                if let self, let c { self.handleConnect(c) }
            }
        }
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil, queue: .main
        ) { [weak self] note in
            let c = note.object as? GCController
            DispatchQueue.main.async { [weak self] in
                if let self, let c { self.handleDisconnect(c) }
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

        // Claim the controller as Player 1. This signals to macOS's
        // GameController framework that our app is actively using the
        // controller — without it, setMode/setColor calls may be treated as
        // background hints and silently dropped.
        c.playerIndex = .index1

        // Register a no-op value handler. The act of installing a handler
        // tells the framework we're consuming controller events, which moves
        // us from "observer" to "active user" status for output features.
        c.extendedGamepad?.valueChangedHandler = { _, _ in
            // Just claiming — actual input parsing happens via raw HID.
        }

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
        let names = h.supportedLocalities.map { $0.rawValue }.joined(separator: ", ")
        NSLog("GCBridge.haptics.supportedLocalities: [%@]", names)

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
        guard let c = controller else { return }
        // Prefer extendedGamepad cast (Apple's idiomatic path); fall back to
        // physicalInputProfile in case the cast doesn't resolve on some firmware.
        let dualsense = (c.extendedGamepad as? GCDualSenseGamepad)
            ?? (c.physicalInputProfile as? GCDualSenseGamepad)
        guard let dualsense else { return }
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

        // 250ms after a mode change, read back trigger.mode + trigger.status
        // and log them — proves whether macOS actually accepted the setMode
        // call. Apple's header explicitly notes the mode property reflects
        // physical state and updates after a controller round-trip.
        if leftChanged || rightChanged {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                guard let self,
                      let dualsense = (self.controller?.extendedGamepad as? GCDualSenseGamepad)
                        ?? (self.controller?.physicalInputProfile as? GCDualSenseGamepad)
                else { return }
                NSLog("GCBridge.readback L2: mode=%ld status=%ld arm=%.2f | R2: mode=%ld status=%ld arm=%.2f",
                      dualsense.leftTrigger.mode.rawValue,
                      dualsense.leftTrigger.status.rawValue,
                      dualsense.leftTrigger.armPosition,
                      dualsense.rightTrigger.mode.rawValue,
                      dualsense.rightTrigger.status.rawValue,
                      dualsense.rightTrigger.armPosition)
            }
        }
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
            // CRITICAL: Per Apple's header docs, `frequency` is NORMALIZED 0..1 —
            // NOT a Hz value. Our UI exposes 1..80 (Hz-like) so we divide.
            // amplitude is also normalized 0..1.
            let startPos = Float(min(position, 9)) / 9.0
            let amp = Float(min(amplitude, 8)) / 8.0
            let freq = min(max(Float(frequency) / 80.0, 0), 1)
            // Use the simpler single-value API (macOS 11.3+) instead of the
            // positional 10-element variant (12.3+). More compatible and matches
            // our UI's per-trigger semantics.
            trigger.setModeVibrationWithStartPosition(startPos, amplitude: amp, frequency: freq)
            if shouldLog { NSLog("GCBridge.%@: vibration startPos=%.2f amp=%.2f freq=%.2f (raw input freq=%d)",
                                 label, startPos, amp, freq, frequency) }

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
