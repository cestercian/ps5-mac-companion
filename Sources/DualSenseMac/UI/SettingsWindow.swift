import SwiftUI

struct SettingsWindow: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        TabView {
            LightbarTab()
                .tabItem { Label("Lightbar", systemImage: "lightbulb.fill") }

            TriggersTab()
                .tabItem { Label("Triggers", systemImage: "slider.horizontal.3") }

            MotorsTab()
                .tabItem { Label("Motors", systemImage: "waveform") }

            LEDsTab()
                .tabItem { Label("LEDs", systemImage: "circle.grid.3x3.fill") }

            InputTesterTab()
                .tabItem { Label("Input Tester", systemImage: "dot.radiowaves.left.and.right") }
        }
        .padding(16)
    }
}
