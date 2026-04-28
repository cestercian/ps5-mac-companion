import SwiftUI

struct TriggersTab: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Adaptive Triggers").font(.title2).bold()

            HStack(alignment: .top, spacing: 24) {
                TriggerEditor(
                    title: "L2 (Left)",
                    effect: Binding(
                        get: { state.profile.leftTrigger },
                        set: { state.profile.leftTrigger = $0 }
                    )
                )
                TriggerEditor(
                    title: "R2 (Right)",
                    effect: Binding(
                        get: { state.profile.rightTrigger },
                        set: { state.profile.rightTrigger = $0 }
                    )
                )
            }
            Spacer()
        }
        .padding()
    }
}

private struct TriggerEditor: View {
    let title: String
    @Binding var effect: TriggerEffect

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            Picker("Effect", selection: kindBinding) {
                ForEach(TriggerEffect.allKinds, id: \.displayName) { kind in
                    Text(kind.displayName).tag(kind.displayName)
                }
            }
            .labelsHidden()

            paramsView
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 8))
    }

    private var kindBinding: Binding<String> {
        Binding(
            get: { effect.displayName },
            set: { newName in
                if let preset = TriggerEffect.allKinds.first(where: { $0.displayName == newName }) {
                    effect = preset
                }
            }
        )
    }

    @ViewBuilder
    private var paramsView: some View {
        switch effect {
        case .off:
            Text("No resistance applied.")
                .font(.caption)
                .foregroundColor(.secondary)

        case .feedback(let position, let strength):
            slider("Start position", value: Double(position), range: 0...9) { v in
                effect = .feedback(position: UInt8(v), strength: strength)
            }
            slider("Strength", value: Double(strength), range: 0...8) { v in
                effect = .feedback(position: position, strength: UInt8(v))
            }

        case .weapon(let start, let end, let strength):
            slider("Start", value: Double(start), range: 2...7) { v in
                let newStart = UInt8(v)
                let safeEnd = max(end, newStart + 1)
                effect = .weapon(start: newStart, end: min(safeEnd, 8), strength: strength)
            }
            slider("End", value: Double(end), range: 3...8) { v in
                let newEnd = UInt8(v)
                let safeStart = min(start, newEnd - 1)
                effect = .weapon(start: max(safeStart, 2), end: newEnd, strength: strength)
            }
            slider("Strength", value: Double(strength), range: 1...8) { v in
                effect = .weapon(start: start, end: end, strength: UInt8(v))
            }

        case .vibration(let frequency, let position, let amplitude):
            slider("Frequency (Hz)", value: Double(frequency), range: 1...80) { v in
                effect = .vibration(frequency: UInt8(v), position: position, amplitude: amplitude)
            }
            slider("Start position", value: Double(position), range: 0...9) { v in
                effect = .vibration(frequency: frequency, position: UInt8(v), amplitude: amplitude)
            }
            slider("Amplitude", value: Double(amplitude), range: 0...8) { v in
                effect = .vibration(frequency: frequency, position: position, amplitude: UInt8(v))
            }

        case .slope(let start, let end, let startStrength, let endStrength):
            slider("Start", value: Double(start), range: 0...8) { v in
                let newStart = UInt8(v)
                let safeEnd = max(end, newStart + 1)
                effect = .slope(start: newStart, end: min(safeEnd, 9), startStrength: startStrength, endStrength: endStrength)
            }
            slider("End", value: Double(end), range: 1...9) { v in
                let newEnd = UInt8(v)
                let safeStart = min(start, newEnd - 1)
                effect = .slope(start: safeStart, end: newEnd, startStrength: startStrength, endStrength: endStrength)
            }
            slider("Start strength", value: Double(startStrength), range: 0...8) { v in
                effect = .slope(start: start, end: end, startStrength: UInt8(v), endStrength: endStrength)
            }
            slider("End strength", value: Double(endStrength), range: 0...8) { v in
                effect = .slope(start: start, end: end, startStrength: startStrength, endStrength: UInt8(v))
            }
        }
    }

    private func slider(_ label: String,
                        value: Double,
                        range: ClosedRange<Double>,
                        onChange: @escaping (Double) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label).font(.caption)
                Spacer()
                Text(String(format: "%.0f", value)).font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }
            Slider(value: Binding(get: { value }, set: { onChange($0) }), in: range, step: 1)
        }
    }
}
