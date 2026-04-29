import SwiftUI

struct MotorsTab: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rumble Motors").font(.title2).bold()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Left (low frequency)")
                    Spacer()
                    Text("\(state.profile.rumble.leftStrength)")
                        .font(.body.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                Slider(value: Binding(
                    get: { Double(state.profile.rumble.leftStrength) },
                    set: { v in defer_ { state.profile.rumble.leftStrength = UInt8(v) } }
                ), in: 0...255, step: 1)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Right (high frequency)")
                    Spacer()
                    Text("\(state.profile.rumble.rightStrength)")
                        .font(.body.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                Slider(value: Binding(
                    get: { Double(state.profile.rumble.rightStrength) },
                    set: { v in defer_ { state.profile.rumble.rightStrength = UInt8(v) } }
                ), in: 0...255, step: 1)
            }

            HStack {
                Button("Test Rumble (500ms)") { state.testRumble(milliseconds: 500) }
                    .disabled(!state.connected)
                Button("Stop") { defer_ { state.profile.rumble = .off } }
            }

            Spacer()
        }
        .padding()
    }
}
