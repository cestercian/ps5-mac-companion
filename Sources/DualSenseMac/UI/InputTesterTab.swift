import SwiftUI

struct InputTesterTab: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Input Tester").font(.title2).bold()
                if !state.connected {
                    Text("Connect your DualSense via USB-C to see live input.")
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 24) {
                    StickView(name: "Left Stick", x: state.input.leftStickX, y: state.input.leftStickY)
                    StickView(name: "Right Stick", x: state.input.rightStickX, y: state.input.rightStickY)
                }

                HStack(spacing: 24) {
                    TriggerBar(name: "L2", value: state.input.leftTrigger)
                    TriggerBar(name: "R2", value: state.input.rightTrigger)
                }

                ButtonGrid()

                HStack {
                    Text("Battery: \(state.input.batteryLevel)%\(state.input.batteryCharging ? " ⚡︎" : "")")
                    Spacer()
                    Text("Headphones: \(state.input.headphonesConnected ? "yes" : "no")")
                        .foregroundColor(.secondary)
                }
                .font(.caption)
            }
            .padding()
        }
    }
}

private struct StickView: View {
    let name: String
    let x: UInt8
    let y: UInt8

    var body: some View {
        VStack(spacing: 4) {
            Text(name).font(.caption)
            ZStack {
                Circle()
                    .stroke(.secondary.opacity(0.4))
                    .frame(width: 80, height: 80)
                Circle()
                    .fill(.blue)
                    .frame(width: 8, height: 8)
                    .offset(x: CGFloat(Double(x) - 128) / 128 * 36,
                            y: CGFloat(Double(y) - 128) / 128 * 36)
            }
            Text("\(x), \(y)").font(.caption2.monospacedDigit()).foregroundColor(.secondary)
        }
    }
}

private struct TriggerBar: View {
    let name: String
    let value: UInt8

    var body: some View {
        VStack(spacing: 2) {
            Text("\(name): \(value)").font(.caption.monospacedDigit())
            ProgressView(value: Double(value), total: 255)
                .frame(width: 120)
        }
    }
}

private struct ButtonGrid: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        let columns = [GridItem(.adaptive(minimum: 70))]
        LazyVGrid(columns: columns, spacing: 6) {
            chip("△", state.input.triangle)
            chip("○", state.input.circle)
            chip("✕", state.input.cross)
            chip("□", state.input.square)
            chip("L1", state.input.l1)
            chip("R1", state.input.r1)
            chip("L3", state.input.l3)
            chip("R3", state.input.r3)
            chip("Create", state.input.create)
            chip("Options", state.input.options)
            chip("PS", state.input.psButton)
            chip("Touchpad", state.input.touchpadClick)
            chip("Mute", state.input.muteButton)
            chip("DPad", state.input.dpad != .neutral)
        }
    }

    private func chip(_ label: String, _ on: Bool) -> some View {
        Text(label)
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(on ? Color.accentColor : Color.secondary.opacity(0.15),
                        in: Capsule())
            .foregroundColor(on ? .white : .primary)
    }
}
