import Foundation

/// Builds a 47-byte USB DualSense output report payload.
/// Byte layout follows the Linux `dualsensectl` and DualSense-Windows references —
/// the leading report ID (0x02) is supplied separately to `IOHIDDeviceSetReport`.
///
/// Layout (offsets are 0-based after the report ID):
///   0    valid_flag0          enable rumble
///   1    valid_flag1          enable mic LED, lightbar, player LEDs (bit 3 must be CLEAR)
///   2    motor_right
///   3    motor_left
///   4..7 audio volumes + flags
///   8    mute_button_led
///   9    power_save_control
///   10   right_trigger_motor_mode
///   11..20 right_trigger_param (10 bytes)
///   21   left_trigger_motor_mode
///   22..31 left_trigger_param (10 bytes)
///   32..35 reserved
///   36   reduce_motor_power
///   37   audio_flags2
///   38   valid_flag2
///   39..40 reserved
///   41   lightbar_setup
///   42   led_brightness
///   43   player_leds
///   44   lightbar_red
///   45   lightbar_green
///   46   lightbar_blue
struct OutputReport {
    var rumble: RumbleState = .off
    var lightbar: LightbarColor = .defaultBlue
    var playerLED = PlayerLED()
    var micLED: MicLED = .off
    var leftTrigger: TriggerEffect = .off
    var rightTrigger: TriggerEffect = .off

    func encodeUSB() -> Data {
        var b = [UInt8](repeating: 0, count: 47)

        // valid_flag0 (VibrationMode in rafaelvaloto/Dualsense-Multiplatform): 0xFF.
        b[0] = 0xFF

        // valid_flag1 (FeatureMode in rafaelvaloto): 0x57 = 0b01010111.
        //   bit 0 = mic mute LED control
        //   bit 1 = power save control
        //   bit 2 = LIGHTBAR control       <- required for lightbar
        //   bit 3 = RELEASE LEDS           <- MUST stay 0
        //   bit 4 = player LED control
        //   bit 6 = LED brightness control
        // This is the value the rafaelvaloto library uses in production and is
        // what makes the lightbar actually respond on macOS.
        b[1] = 0x57

        // Rumble.
        b[2] = rumble.rightStrength
        b[3] = rumble.leftStrength

        // Mic LED.
        b[8] = micLED.rawValue

        // Right trigger effect (mode + 10 params).
        let rt = rightTrigger.encode()
        for i in 0..<11 { b[10 + i] = rt[i] }

        // Left trigger effect (mode + 10 params).
        let lt = leftTrigger.encode()
        for i in 0..<11 { b[21 + i] = lt[i] }

        // The rafaelvaloto reference library writes 0x07 at byte 39 (Output[39] in
        // their code, MutableBuffer[40] including the report ID). This appears to
        // be the actual valid_flag2 byte for USB mode — without it the lightbar
        // isn't applied. Byte 38 stays 0.
        b[39] = 0x07

        // Player LED brightness (42), pattern (43).
        b[42] = playerLED.brightness.rawValue
        b[43] = playerLED.pattern.rawValue

        // Lightbar RGB at the correct offsets.
        b[44] = lightbar.red
        b[45] = lightbar.green
        b[46] = lightbar.blue

        return Data(b)
    }
}
