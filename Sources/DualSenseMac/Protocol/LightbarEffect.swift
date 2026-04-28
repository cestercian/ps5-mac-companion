import Foundation
import SwiftUI

struct LightbarColor: Equatable, Codable {
    var red: UInt8
    var green: UInt8
    var blue: UInt8

    static let off = LightbarColor(red: 0, green: 0, blue: 0)
    static let defaultBlue = LightbarColor(red: 0, green: 30, blue: 80)
    /// Bright magenta — used as the v0.2 default so it's unmistakably visible
    /// when the protocol is talking to the controller correctly.
    static let debugMagenta = LightbarColor(red: 255, green: 0, blue: 200)
}

extension LightbarColor {
    init(swiftUIColor: Color) {
        #if canImport(AppKit)
        let fallback = NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)
        let ns = NSColor(swiftUIColor).usingColorSpace(.sRGB) ?? fallback
        self.red = UInt8(max(0, min(1, ns.redComponent)) * 255)
        self.green = UInt8(max(0, min(1, ns.greenComponent)) * 255)
        self.blue = UInt8(max(0, min(1, ns.blueComponent)) * 255)
        #else
        self.red = 0; self.green = 0; self.blue = 0
        #endif
    }

    var swiftUIColor: Color {
        Color(.sRGB,
              red: Double(red) / 255.0,
              green: Double(green) / 255.0,
              blue: Double(blue) / 255.0,
              opacity: 1)
    }
}
