import SwiftUI

/// Defers a closure to the next main-runloop tick so that SwiftUI binding
/// setters don't mutate `@Published` state during a view-update cycle (which
/// triggers the "Publishing changes from within view updates is not allowed"
/// purple warning and can cause undefined behavior).
@inlinable
func defer_(_ work: @escaping () -> Void) {
    DispatchQueue.main.async(execute: work)
}

struct LEDsTab: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("LEDs").font(.title2).bold()

            GroupBox("Player LED") {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Pattern", selection: Binding(
                        get: { state.profile.playerLED.pattern },
                        set: { newValue in defer_ { state.profile.playerLED.pattern = newValue } }
                    )) {
                        ForEach(PlayerLED.Pattern.allCases, id: \.self) { p in
                            Text(p.displayName).tag(p)
                        }
                    }
                    Picker("Brightness", selection: Binding(
                        get: { state.profile.playerLED.brightness },
                        set: { newValue in defer_ { state.profile.playerLED.brightness = newValue } }
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
                    set: { newValue in defer_ { state.profile.micLED = newValue } }
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
