import SwiftUI

struct LEDsTab: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("LEDs").font(.title2).bold()

            GroupBox("Player LED") {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Pattern", selection: Binding(
                        get: { state.profile.playerLED.pattern },
                        set: { state.profile.playerLED.pattern = $0 }
                    )) {
                        ForEach(PlayerLED.Pattern.allCases, id: \.self) { p in
                            Text(p.displayName).tag(p)
                        }
                    }
                    Picker("Brightness", selection: Binding(
                        get: { state.profile.playerLED.brightness },
                        set: { state.profile.playerLED.brightness = $0 }
                    )) {
                        ForEach(PlayerLED.Brightness.allCases, id: \.self) { b in
                            Text(b.displayName).tag(b)
                        }
                    }
                }
                .padding(8)
            }

            GroupBox("Mic LED") {
                Picker("Mode", selection: Binding(
                    get: { state.profile.micLED },
                    set: { state.profile.micLED = $0 }
                )) {
                    ForEach(MicLED.allCases, id: \.self) { m in
                        Text(m.displayName).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding(8)
            }

            Spacer()
        }
        .padding()
    }
}
