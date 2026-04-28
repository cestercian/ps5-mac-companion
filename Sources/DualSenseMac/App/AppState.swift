import Foundation
import Combine
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var connected: Bool = false
    @Published var transport: DualSenseTransport = .usb
    @Published var input: DualSenseInput = DualSenseInput()
    @Published var profile: Profile {
        didSet {
            if oldValue.lightbar != profile.lightbar {
                NSLog("AppState: profile.lightbar changed (%d,%d,%d) -> (%d,%d,%d)",
                      oldValue.lightbar.red, oldValue.lightbar.green, oldValue.lightbar.blue,
                      profile.lightbar.red, profile.lightbar.green, profile.lightbar.blue)
            }
            ProfileStore.save(profile)
            scheduleOutputPush()
        }
    }

    private let manager = DualSenseManager()
    private let gcBridge = GameControllerBridge()
    private var device: HIDDevice?
    private var pushWorkItem: DispatchWorkItem?
    private var keepaliveTimer: Timer?
    private var pushesLogged = 0

    init() {
        self.profile = ProfileStore.load()
        manager.onConnect = { [weak self] hid, transport in
            Task { @MainActor in
                self?.handleConnect(hid: hid, transport: transport)
            }
        }
        manager.onDisconnect = { [weak self] in
            Task { @MainActor in
                self?.handleDisconnect()
            }
        }
        // GameController bridge: when it attaches, push the current lightbar via
        // Apple's official API immediately.
        gcBridge.onAttach = { [weak self] in
            guard let self else { return }
            self.gcBridge.setLightbar(self.profile.lightbar)
        }
        // Defer HID start until after the SwiftUI scene graph + run loop are fully up.
        DispatchQueue.main.async { [weak self] in
            self?.manager.start()
        }
    }

    private func handleConnect(hid: HIDDevice, transport: DualSenseTransport) {
        device = hid
        self.transport = transport
        connected = true
        hid.onInputReport = { [weak self] data in
            guard let parsed = DualSenseInput.parse(usbReport: data) else { return }
            Task { @MainActor in
                guard let self else { return }
                if self.input.batteryLevel != parsed.batteryLevel
                    || self.input.batteryCharging != parsed.batteryCharging {
                    NSLog("AppState: battery now %d%% charging=%@",
                          parsed.batteryLevel, parsed.batteryCharging ? "Y" : "N")
                }
                self.input = parsed
            }
        }
        // Push current profile to the controller right away so its state matches the UI.
        pushOutput()
        // Re-assert the output state at 5 Hz so any system overrides are stomped on.
        // 30 Hz so system overrides get stomped within ~33 ms.
        keepaliveTimer?.invalidate()
        keepaliveTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pushOutput() }
        }
    }

    private func handleDisconnect() {
        device = nil
        connected = false
        keepaliveTimer?.invalidate()
        keepaliveTimer = nil
    }

    /// Coalesce rapid UI changes (slider drags) into ~30Hz output writes.
    private func scheduleOutputPush() {
        pushWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in self?.pushOutput() }
        }
        pushWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.033, execute: work)
    }

    func pushOutput() {
        // Lightbar + triggers via GameController.framework — these are the paths
        // macOS 26 honors reliably (raw HID writes are silently filtered). We
        // still send raw HID for rumble + LEDs (those DO work).
        gcBridge.setLightbar(profile.lightbar)
        gcBridge.setTriggers(left: profile.leftTrigger, right: profile.rightTrigger)

        guard let device else { return }
        let report = OutputReport(
            rumble: profile.rumble,
            lightbar: profile.lightbar,
            playerLED: profile.playerLED,
            micLED: profile.micLED,
            leftTrigger: profile.leftTrigger,
            rightTrigger: profile.rightTrigger
        )
        let payload = report.encodeUSB()
        _ = device.writeOutputReport(reportID: DualSenseManager.usbOutputReportID, data: payload)
    }

    func testRumble(milliseconds: Int = 300) {
        profile.rumble = RumbleState(leftStrength: 200, rightStrength: 200)
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(milliseconds)) { [weak self] in
            // Always reset to .off — never to whatever was there before — so a fast
            // second click can't strand the motor in a non-zero "previous" state.
            self?.profile.rumble = .off
        }
    }
}
