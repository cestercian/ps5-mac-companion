import Foundation

struct DualSenseInput {
    var leftStickX: UInt8 = 128
    var leftStickY: UInt8 = 128
    var rightStickX: UInt8 = 128
    var rightStickY: UInt8 = 128
    var leftTrigger: UInt8 = 0
    var rightTrigger: UInt8 = 0

    var dpad: DPad = .neutral
    var square = false
    var cross = false
    var circle = false
    var triangle = false
    var l1 = false
    var r1 = false
    var l2 = false
    var r2 = false
    var create = false
    var options = false
    var l3 = false
    var r3 = false
    var psButton = false
    var touchpadClick = false
    var muteButton = false

    var batteryLevel: UInt8 = 0
    var batteryCharging = false
    var headphonesConnected = false

    enum DPad: UInt8 {
        case north = 0, northEast, east, southEast, south, southWest, west, northWest, neutral = 8
    }

    /// Parse a USB DualSense input report.
    ///
    /// On macOS, IOHIDDeviceRegisterInputReportCallback delivers the report buffer
    /// WITH the leading report-ID byte. So `data[0] == 0x01` (the input report ID),
    /// `data[1]` is left-stick X, `data[53]` is the battery byte, etc.
    /// Confirmed empirically by hex-dumping the first packets.
    static func parse(usbReport data: Data) -> DualSenseInput? {
        // Need at least bytes 0..54 to read battery + connection state.
        guard data.count >= 55 else { return nil }
        // Sanity-check the report ID — bail if this isn't a 0x01 input report.
        guard data[0] == 0x01 else { return nil }

        var input = DualSenseInput()

        input.leftStickX = data[1]
        input.leftStickY = data[2]
        input.rightStickX = data[3]
        input.rightStickY = data[4]
        input.leftTrigger = data[5]
        input.rightTrigger = data[6]

        let buttons1 = data[8]
        let buttons2 = data[9]
        let buttons3 = data[10]

        let dpadRaw = buttons1 & 0x0F
        input.dpad = DPad(rawValue: dpadRaw) ?? .neutral

        input.square   = (buttons1 & 0x10) != 0
        input.cross    = (buttons1 & 0x20) != 0
        input.circle   = (buttons1 & 0x40) != 0
        input.triangle = (buttons1 & 0x80) != 0

        input.l1      = (buttons2 & 0x01) != 0
        input.r1      = (buttons2 & 0x02) != 0
        input.l2      = (buttons2 & 0x04) != 0
        input.r2      = (buttons2 & 0x08) != 0
        input.create  = (buttons2 & 0x10) != 0
        input.options = (buttons2 & 0x20) != 0
        input.l3      = (buttons2 & 0x40) != 0
        input.r3      = (buttons2 & 0x80) != 0

        input.psButton      = (buttons3 & 0x01) != 0
        input.touchpadClick = (buttons3 & 0x02) != 0
        input.muteButton    = (buttons3 & 0x04) != 0

        // Battery: low nibble = level (0-10 → 0-100%), high nibble = state.
        let batteryByte = data[53]
        let rawLevel = batteryByte & 0x0F
        input.batteryLevel = min(rawLevel, 10) * 10
        let chargeStatus = (batteryByte & 0xF0) >> 4
        input.batteryCharging = chargeStatus == 0x01 || chargeStatus == 0x02

        let connectionByte = data[54]
        input.headphonesConnected = (connectionByte & 0x01) != 0

        return input
    }
}
