# PS5MacCompanion

> A native macOS companion app for the PlayStation 5 DualSense controller.

A SwiftUI menubar app that talks to your DualSense over USB-C / Bluetooth and
exposes its features — battery, lightbar, adaptive triggers, rumble motors,
player LEDs, and a live input visualizer — through Apple's `GameController`
framework and raw IOKit HID.

> **Important.** macOS 26 silently no-ops third-party `setMode` / `setColor`
> writes for adaptive triggers and lightbar. The features that worked on
> macOS 11 through 14 are gated on macOS 26, likely behind an Apple
> Developer ID with notarization or an App Store sandbox capability. See
> [`SIGNING.md`](SIGNING.md) for the empirical signing test you can run
> with a free Apple ID.

## Status at a glance

Tested on macOS 13, macOS 14, and macOS 26.4 with DualSense over USB-C and
Bluetooth.

| Feature                              | macOS 13 / 14 | macOS 26 (ad-hoc signed) |
| ------------------------------------ | :-----------: | :----------------------: |
| Connection detection                 |       ✓       |             ✓            |
| Battery readout                      |       ✓       |             ✓            |
| Stick / button / d-pad input         |       ✓       |             ✓            |
| Touchpad input                       |       ✓       |             ✓            |
| Rumble (left motor)                  |       ✓       |             ✓            |
| Rumble (right motor)                 |       ✓       |     Partial              |
| Lightbar (initial color on attach)   |       ✓       |             ✓            |
| Lightbar (subsequent changes)        |       ✓       |     Blocked              |
| Adaptive triggers                    |       ✓       |     Blocked              |
| Player LEDs / mic LED                |       ✓       |     Partial              |
| Settings persistence                 |       ✓       |             ✓            |

See [Known Issues](#known-issues) for the full diagnostic story behind the
"Blocked" rows.

## Quick start

Requirements: macOS 13 or newer, plus either Xcode 15+ or the Swift 5.9+
command-line toolchain.

### Option A — Xcode

This is the recommended path if you want to test free-tier signing. See
[`SIGNING.md`](SIGNING.md) for the full walkthrough.

```bash
git clone https://github.com/cestercian/ps5-mac-companion.git
cd ps5-mac-companion
open PS5MacCompanion.xcodeproj
```

In Xcode: select the `PS5MacCompanion` target, open the **Signing &
Capabilities** tab, check **Automatically manage signing**, pick your
Personal Team in the **Team** dropdown, then run with `⌘R`.

### Option B — Swift Package Manager

```bash
git clone https://github.com/cestercian/ps5-mac-companion.git
cd ps5-mac-companion
swift run DualSenseMac
```

Either way, plug your DualSense into the Mac via USB-C and a controller
icon appears in the menubar.

## Features

The following are wired end-to-end in v0.1.0:

- **Menubar quick controls** — battery, connection status, six color
  preset swatches, test rumble, settings shortcut.
- **Settings window with five tabs**:
  - **Lightbar** — RGB color picker plus presets.
  - **Triggers** — L2 / R2 adaptive trigger effects: Off, Feedback,
    Weapon, Vibration, Slope.
  - **Motors** — independent left and right rumble strength sliders
    plus a test button.
  - **LEDs** — Player LED pattern + brightness, mic LED mode.
  - **Input Tester** — live visualizer for sticks, triggers, buttons,
    d-pad, touchpad click, battery, and headphones detection.
- **Profile persistence** — settings auto-save to
  `~/Library/Application Support/DualSenseMac/profile.json` and re-apply
  on next launch.
- **Per-handle haptics** — uses Apple's `GCHaptics` with separate
  `CHHapticEngine` instances bound to `.leftHandle` and `.rightHandle`
  for independent rumble control.
- **Comprehensive logging** — every output write and a 250 ms-deferred
  trigger status readback is logged via `NSLog` to both stderr and the
  unified log (visible in `Console.app`).

## Architecture

```text
Sources/DualSenseMac/
  App/
    DualSenseMacApp.swift      // @main, MenuBarExtra + Settings Window scenes
    AppState.swift             // ObservableObject; profile + 30 Hz keepalive
  HID/
    HIDDevice.swift            // IOHIDManager wrapper (open / read / write)
    DualSenseDevice.swift      // Vendor 0x054C / Product 0x0CE6 USB matching
    InputReport.swift          // Parse 64-byte USB input report
    OutputReport.swift         // Build 47-byte USB output report
    GameControllerBridge.swift // GCDeviceLight + GCDualSenseAdaptiveTrigger
                               // + GCHaptics path (Apple's official APIs)
  Protocol/                    // Codable models for each output feature
    LightbarEffect.swift
    TriggerEffect.swift        // Off / Feedback / Weapon / Vibration / Slope
    RumbleMotors.swift
    PlayerLED.swift
    MicLED.swift
  UI/                          // SwiftUI views (menubar + 5 tabs)
  Persistence/
    Profile.swift
    ProfileStore.swift         // JSON to ~/Library/Application Support/
```

The app deliberately drives the controller through **two parallel paths**:

1. **Raw IOKit HID** — direct output reports per the Linux kernel driver
   plus the byte layout from the `rafaelvaloto/Dualsense-Multiplatform`
   reference library.
2. **`GameController.framework`** — Apple's official APIs
   (`GCDeviceLight`, `GCDualSenseAdaptiveTrigger`, `GCHaptics`).

When both paths fail to produce a visible effect, the feature is genuinely
blocked at the operating-system level rather than missing in our code. See
the next section.

## Known issues

Most of the late-stage development for this app went into diagnosing a hard
macOS 26 wall. The clinching evidence is the diagnostic readback our app
performs 250 ms after every `setMode` call:

```text
GCBridge.readback L2: mode=0 status=0 arm=0.00 | R2: mode=0 status=0 arm=0.00
```

After we call `setModeWeaponWithStartPosition(...)` on Apple's official
`GCDualSenseAdaptiveTrigger`, the trigger's `mode` property — which
Apple's header documentation says "reflects the physical state of the
triggers" — reads back as `0` (Off). Apple's framework accepted the call
silently and never applied it. We tested every documented lever:

- Set `GCSupportsControllerUserInteraction = true` in `Info.plist`.
- Set `GCSupportsGameMode = true` in `Info.plist`.
- Set `GCSupportedGameControllers = [ExtendedGamepad]` in `Info.plist`.
- Assigned `controller.playerIndex = .index1`.
- Registered a `valueChangedHandler` on the extended gamepad.
- Ran the app under `.regular` activation policy (foreground app, no
  `LSUIElement`).
- Tried both `c.physicalInputProfile as? GCDualSenseGamepad` and
  `c.extendedGamepad as? GCDualSenseGamepad` casts.
- Code-signed ad-hoc.

None of these unlock the feature. The remaining hypotheses, ranked by
likelihood:

1. Apple grants this only to App-Store-distributed apps with the right
   sandbox capability (DualSenseM, the App Store reference, has it).
2. There is a private entitlement that Apple grants only on review.
3. macOS 26 has a bug.

If you have a paid Apple Developer account and can test signing this
project with a Developer ID and notarization, please open an issue with
what `mode` reads back as. That would resolve the question definitively.

## Credits

Inspired by, and drawing protocol details from:

- [DualSenseM](https://apps.apple.com/us/app/dualsensem/id1598693570) by
  Paliverse Apps — Mac App Store reference; the feature parity goal.
- [`Paliverse/DualSenseX`](https://github.com/Paliverse/DualSenseX) —
  Windows trigger effect set and parameters.
- [`rafaelvaloto/Dualsense-Multiplatform`](https://github.com/rafaelvaloto/Dualsense-Multiplatform)
  — C++ protocol library; the verified output-report byte layout
  (especially `flag1 = 0x57` and `0x07` at offset 39 for USB).
- [`nondebug/dualsense`](https://github.com/nondebug/dualsense) — the
  most readable USB plus Bluetooth report reference available.
- [`Ohjurot/DualSense-Windows`](https://github.com/Ohjurot/DualSense-Windows)
  — clean C++ implementation; cross-checked output report bit flags.
- [`flok/pydualsense`](https://github.com/flok/pydualsense) — Python
  reference for trigger effect parameter bytes.
- [`yesbotics/dualsense-controller-python`](https://github.com/yesbotics/dualsense-controller-python)
  — additional protocol notes.
- Linux kernel `hid-playstation` driver — definitive source for the
  `dualsense_output_report_common` byte layout.
- [`MichaelWeed/ps5-controller-control-macbook`](https://github.com/MichaelWeed/ps5-controller-control-macbook)
  — productivity-layer inspiration for v2.

## License

MIT — see [`LICENSE`](LICENSE).

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md). Bug reports and PRs welcome.
