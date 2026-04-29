import SwiftUI

struct LightbarTab: View {
    @EnvironmentObject var state: AppState

    private let presets: [(String, LightbarColor)] = [
        ("Sony Blue", .defaultBlue),
        ("Hot Pink", LightbarColor(red: 255, green: 30, blue: 110)),
        ("Cyan", LightbarColor(red: 0, green: 200, blue: 255)),
        ("Lime", LightbarColor(red: 80, green: 255, blue: 60)),
        ("Sunset", LightbarColor(red: 255, green: 90, blue: 0)),
        ("Off", .off)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Lightbar").font(.title2).bold()

            ColorPicker("Color", selection: Binding(
                get: { state.profile.lightbar.swiftUIColor },
                set: { newColor in
                    let lc = LightbarColor(swiftUIColor: newColor)
                    defer_ { state.profile.lightbar = lc }
                }
            ), supportsOpacity: false)

            Text("Presets").font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(presets, id: \.0) { name, color in
                    Button {
                        defer_ { state.profile.lightbar = color }
                    } label: {
                        HStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(color.swiftUIColor)
                                .frame(width: 18, height: 18)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(.secondary.opacity(0.4), lineWidth: 0.5)
                                )
                            Text(name)
                            Spacer()
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }

            Spacer()
        }
        .padding()
    }
}
