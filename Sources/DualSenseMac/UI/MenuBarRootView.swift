import SwiftUI
import AppKit

struct MenuBarRootView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.openWindow) private var openWindow

    private func presetSwatch(_ color: LightbarColor, _ tooltip: String) -> some View {
        Button {
            NSLog("MenuBar preset tapped: %@ (%d,%d,%d)",
                  tooltip, color.red, color.green, color.blue)
            defer_ { state.profile.lightbar = color }
        } label: {
            RoundedRectangle(cornerRadius: 4)
                .fill(color.swiftUIColor)
                .frame(width: 24, height: 18)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(.secondary.opacity(0.4), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: state.connected ? "gamecontroller.fill" : "gamecontroller")
                    .foregroundColor(state.connected ? .green : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.connected ? "Connected" : "Disconnected")
                        .font(.headline)
                    if state.connected {
                        Text("\(state.transport == .usb ? "USB" : "Bluetooth") · Battery \(state.input.batteryLevel)%\(state.input.batteryCharging ? " ⚡︎" : "")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            Divider()

            ColorPicker("Lightbar", selection: Binding(
                get: { state.profile.lightbar.swiftUIColor },
                set: { newColor in
                    let lc = LightbarColor(swiftUIColor: newColor)
                    NSLog("MenuBar.ColorPicker.set: user picked (%d,%d,%d)",
                          lc.red, lc.green, lc.blue)
                    defer_ { state.profile.lightbar = lc }
                }
            ), supportsOpacity: false)

            // Quick presets — bypass the OS color-picker window entirely.
            HStack(spacing: 6) {
                presetSwatch(LightbarColor(red: 0, green: 30, blue: 80), "Blue")
                presetSwatch(LightbarColor(red: 255, green: 30, blue: 110), "Pink")
                presetSwatch(LightbarColor(red: 0, green: 200, blue: 255), "Cyan")
                presetSwatch(LightbarColor(red: 80, green: 255, blue: 60), "Lime")
                presetSwatch(LightbarColor(red: 255, green: 90, blue: 0), "Orange")
                presetSwatch(LightbarColor(red: 0, green: 0, blue: 0), "Off")
            }

            Button("Test Rumble") { state.testRumble() }
                .disabled(!state.connected)

            Divider()

            Button("Open Settings…") {
                NSApp.setActivationPolicy(.regular)
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(12)
        .frame(width: 260)
    }
}
