import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var settingsWindow: NSWindow?
    weak var state: AppState?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    @objc func openSettings() {
        NSLog("AppDelegate.openSettings: invoked (state=%@, existingWindow=%@)",
              state == nil ? "NIL" : "set",
              settingsWindow == nil ? "no" : "yes")
        if let win = settingsWindow {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        guard let state = state else {
            NSLog("AppDelegate.openSettings: state is NIL — bailing")
            return
        }
        let host = NSHostingController(rootView: SettingsWindow().environmentObject(state))
        let win = NSWindow(contentViewController: host)
        win.title = "DualSenseMac"
        win.setContentSize(NSSize(width: 560, height: 460))
        win.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        win.center()
        win.isReleasedWhenClosed = false
        settingsWindow = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct DualSenseMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra("DualSenseMac", systemImage: "gamecontroller") {
            MenuBarRootView()
                .environmentObject(state)
        }
        .menuBarExtraStyle(.window)

        // SwiftUI-managed settings window. Trigger from the menubar with
        // openWindow(id: "settings"). Defaults to closed; the menu bar item
        // remains the primary surface.
        WindowGroup("DualSenseMac Settings", id: "settings") {
            SettingsWindow()
                .environmentObject(state)
                .frame(minWidth: 540, minHeight: 440)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 560, height: 460)
    }
}
