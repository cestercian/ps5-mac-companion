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
            // When the user toggles notifications, start/stop the watcher.
            if oldValue.notificationsEnabled != profile.notificationsEnabled {
                if profile.notificationsEnabled {
                    startNotificationWatcher()
                } else {
                    notificationWatcher.stop()
                }
            }
            ProfileStore.save(profile)
            scheduleOutputPush()
        }
    }

    private let manager = DualSenseManager()
    private let gcBridge = GameControllerBridge()
    private let notificationWatcher = NotificationWatcher()
    private var device: HIDDevice?
    private var pushWorkItem: DispatchWorkItem?
    private var keepaliveTimer: Timer?
    private var pushesLogged = 0
    private var notificationRumbleTimer: Timer?

    @Published private(set) var hasFullDiskAccess: Bool = NotificationWatcher.hasFullDiskAccess()

    init() {
        self.profile = ProfileStore.load()
        manager.onConnect = { [weak self] hid, transport in
            DispatchQueue.main.async { [weak self] in
                self?.handleConnect(hid: hid, transport: transport)
            }
        }
        manager.onDisconnect = { [weak self] in
            DispatchQueue.main.async { [weak self] in
                self?.handleDisconnect()
            }
        }
        // GameController bridge: when it attaches, push the current lightbar via
        // Apple's official API immediately.
        gcBridge.onAttach = { [weak self] in
            guard let self else { return }
            self.gcBridge.setLightbar(self.profile.lightbar)
        }
        // Wire up the notification → vibration callback. The watcher fires
        // on the main thread; we just trigger a rumble pulse that runs for
        // profile.notificationRumbleDurationMs milliseconds.
        notificationWatcher.onNewNotifications = { [weak self] _ in
            self?.fireNotificationRumble()
        }

        // Defer HID start until after the SwiftUI scene graph + run loop are fully up.
        DispatchQueue.main.async { [weak self] in
            self?.manager.start()
            // If the user already had notifications enabled in the persisted
            // profile, kick the watcher on too.
            if self?.profile.notificationsEnabled == true {
                self?.startNotificationWatcher()
            }
        }
    }

    private func startNotificationWatcher() {
        // Refresh FDA status — the user may have just granted it via System Settings.
        hasFullDiskAccess = NotificationWatcher.hasFullDiskAccess()
        if !hasFullDiskAccess {
            NSLog("AppState: cannot start NotificationWatcher — Full Disk Access not granted")
            return
        }
        notificationWatcher.start()
    }

    /// Fires a 3-second (configurable) rumble pulse on both motors when a
    /// new system notification arrives. Cancels any in-flight notification
    /// rumble so back-to-back notifications don't queue up forever.
    private func fireNotificationRumble() {
        notificationRumbleTimer?.invalidate()
        let strength = profile.notificationRumbleStrength
        profile.rumble = RumbleState(leftStrength: strength, rightStrength: strength)
        let duration = TimeInterval(profile.notificationRumbleDurationMs) / 1000.0
        notificationRumbleTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                self?.profile.rumble = .off
            }
        }
    }

    /// Re-check whether our app currently has Full Disk Access. Call this
    /// after the user grants access via System Settings so the UI updates.
    func refreshFullDiskAccess() {
        hasFullDiskAccess = NotificationWatcher.hasFullDiskAccess()
        // If the user just granted FDA AND notifications are enabled in
        // their profile but the watcher isn't running, start it now.
        if hasFullDiskAccess && profile.notificationsEnabled && !notificationWatcher.isRunning {
            notificationWatcher.start()
        }
    }

    private func handleConnect(hid: HIDDevice, transport: DualSenseTransport) {
        device = hid
        self.transport = transport
        connected = true
        hid.onInputReport = { [weak self] data in
            guard let parsed = DualSenseInput.parse(usbReport: data) else { return }
            DispatchQueue.main.async { [weak self] in
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
            // Timer with default scheduling fires on the run loop it was
            // installed on (main runloop here) — no Task hop needed.
            DispatchQueue.main.async { [weak self] in self?.pushOutput() }
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
        // The work item runs on the main queue (we schedule it via
        // asyncAfter on .main below), so we can call pushOutput directly.
        let work = DispatchWorkItem { [weak self] in
            self?.pushOutput()
        }
        pushWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.033, execute: work)
    }

    func pushOutput() {
        // All three driveable features via GameController.framework — the only
        // paths macOS 26 honors reliably. Raw HID writes are silently filtered
        // for lightbar/triggers/rumble.
        gcBridge.setLightbar(profile.lightbar)
        gcBridge.setTriggers(left: profile.leftTrigger, right: profile.rightTrigger)
        gcBridge.setRumble(profile.rumble)

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
