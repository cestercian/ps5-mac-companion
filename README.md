# PS5MacCompanion

> A native macOS companion app for the PlayStation 5 DualSense controller.

A SwiftUI menubar app that talks to your DualSense over USB-C / Bluetooth and
exposes its features — battery, lightbar, adaptive triggers, rumble motors,
player LEDs, and a live input visualizer — through Apple's `GameController`
framework and raw IOKit HID.

> [!IMPORTANT]
> **macOS 26 limitation:** Apple silently no-ops third-party `setMode` /
> `setColor` writes for adaptive triggers and lightbar. The features that
> worked on macOS 11–14 are gated on macOS 26, likely behind an Apple
> Developer ID + notarization or App Store sandbox capability. See
> [SIGNING.md](SIGNING.md) for the empirical signing test you can run with a
> free Apple ID.

## Status at a glance

| Feature | macOS 13–14 | macOS 26 (ad-hoc signed) |
|---|---|---|
| Connection detection | ✅ | ✅ |
| Battery readout | ✅ | ✅ |
| Stick / button / d-pad input | ✅ | ✅ |
| Touchpad input | ✅ | ✅ |
| Rumble (left motor) | ✅ | ✅ |
| Rumble (right motor) | ✅ | ⚠️ partial |
| Lightbar — initial color | ✅ | ✅ |
| Lightbar — subsequent changes | ✅ | ❌ silently dropped |
| Adaptive triggers | ✅ | ❌ silently dropped |
| Player LEDs / mic LED | ✅ | ⚠️ partial |
| Settings persistence | ✅ | ✅ |

See [Known Issues](#known-issues) for the full diagnostic story.

## Quick start

### Build & run from source

Requirements: macOS 13+ and either Xcode or the Swift toolchain.

**Option A — Xcode (recommended for testing free-tier signing):**
```bash
git clone https://github.com/cestercian/ps5-mac-companion.git
cd ps5-mac-companion
open PS5MacCompanion.xcodeproj
```
Then in Xcode: select the target → Signing & Capabilities → check
"Automatically manage signing" → pick your Personal Team → ⌘R.

**Option B — Swift Package Manager:**
```bash
git clone https://github.com/cestercian/ps5-mac-companion.git
cd ps5-mac-companion
swift run DualSenseMac
```

Plug in your DualSense via USB-C. A controller icon appears in the menubar.

## Features

- **Menubar quick controls** — battery, connection status, color presets,
  test rumble, settings shortcut.
- **Settings window with 5 tabs:**
  - **Lightbar** — RGB color picker + presets.
  - **Triggers** — L2/R2 adaptive trigger effects: Off, Feedback, Weapon,
    Vibration, Slope.
  - **Motors** — independent left/right rumble strength sliders + test button.
  - **LEDs** — Player LED pattern + brightness, mic LED mode.
  - **Input Tester** — live visualizer for sticks, triggers, buttons,
    d-pad, touchpad click, battery, headphones detection.
- **Profile persistence** — settings auto-save to
  `~/Library/Application Support/DualSenseMac/profile.json` and re-apply
  on next launch.
- **Per-handle haptics** — uses Apple's `GCHaptics` with separate engines
  bound to `.leftHandle` and `.rightHandle` for independent rumble control.
- **Detailed logging** — comprehensive `NSLog` output for debugging
  controller state, output writes, and macOS framework responses.

## Architecture

```
Sources/DualSenseMac/
├── App/
│   ├── DualSenseMacApp.swift   @main, MenuBarExtra + Settings Window scenes
│   └── AppState.swift          ObservableObject; profile + 30 Hz keepalive
├── HID/
│   ├── HIDDevice.swift         IOHIDManager wrapper (open / read / write)
│   ├── DualSenseDevice.swift   Vendor 0x054C / Product 0x0CE6 USB matching
│   ├── InputReport.swift       Parse 64-byte USB input report → DualSenseInput
│   ├── OutputReport.swift      Build 47-byte USB output report (rafaelvaloto layout)
│   └── GameControllerBridge.swift  GCDeviceLight + GCDualSenseAdaptiveTrigger
│                                   + GCHaptics path (Apple's official APIs)
├── Protocol/                   Codable models for each output feature
│   ├── LightbarEffect.swift
│   ├── TriggerEffect.swift     Off / Feedback / Weapon / Vibration / Slope
│   ├── RumbleMotors.swift
│   ├── PlayerLED.swift
│   └── MicLED.swift
├── UI/                         SwiftUI views (menubar + 5 tabs)
└── Persistence/
    ├── Profile.swift
    └── ProfileStore.swift      JSON to ~/Library/Application Support/
```

We deliberately use **two parallel paths** to drive the controller:
1. **Raw IOKit HID** — direct output reports per the Linux kernel driver +
   `rafaelvaloto/Dualsense-Multiplatform` byte layout.
2. **`GameController.framework`** — Apple's official APIs (`GCDeviceLight`,
   `GCDualSenseAdaptiveTrigger`, `GCHaptics`).

When both paths fail, the feature is genuinely blocked at the OS level —
not a bug in our code. See [Known Issues](#known-issues).

## Known issues

The bulk of the development of this app revealed a hard macOS 26 wall.
The diagnostic readback proves it:

```
GCBridge.readback L2: mode=0 status=0 arm=0.00 | R2: mode=0 status=0 arm=0.00
```

After we call `setModeWeaponWithStartPosition(...)` on Apple's official
`GCDualSenseAdaptiveTrigger`, the trigger's `mode` property — which the
header docs say "reflects the physical state of the triggers" — reads back
as `0` (Off). Apple's framework accepted the call silently and never
applied it. We tested with:

- ✅ `GCSupportsControllerUserInteraction = true`
- ✅ `GCSupportsGameMode = true`
- ✅ `GCSupportedGameControllers = [ExtendedGamepad]`
- ✅ `controller.playerIndex = .index1`
- ✅ `valueChangedHandler` registered
- ✅ Foreground (regular) activation policy
- ✅ Ad-hoc code signing
- ✅ Both `physicalInputProfile` and `extendedGamepad` casts

None of these unlock the feature. The remaining hypotheses (most likely
first):
1. Apple grants this only to App-Store-distributed apps with the right
   sandbox capability (e.g. `DualSenseM` is App Store).
2. There's a private entitlement.
3. macOS 26 has a bug.

Run `SIGNING.md`'s walkthrough to test free-tier signing yourself.

## Credits

Inspired by and drawing protocol details from:

- [DualSenseM](https://apps.apple.com/us/app/dualsensem/id1598693570) by Paliverse Apps — Mac App Store reference; the feature parity goal.
- [`Paliverse/DualSenseX`](https://github.com/Paliverse/DualSenseX) — Windows trigger effect set + parameters.
- [`rafaelvaloto/Dualsense-Multiplatform`](https://github.com/rafaelvaloto/Dualsense-Multiplatform) — C++ protocol library; the verified output-report byte layout (especially `flag1=0x57` and `0x07` at offset 39 for USB).
- [`nondebug/dualsense`](https://github.com/nondebug/dualsense) — most readable USB + BT report reference.
- [`Ohjurot/DualSense-Windows`](https://github.com/Ohjurot/DualSense-Windows) — clean C++ implementation; cross-checked output report bit flags.
- [`flok/pydualsense`](https://github.com/flok/pydualsense) — Python reference for trigger effect parameter bytes.
- [`yesbotics/dualsense-controller-python`](https://github.com/yesbotics/dualsense-controller-python) — additional protocol notes.
- Linux kernel `hid-playstation` driver — definitive source for `dualsense_output_report_common` byte layout.
- [`MichaelWeed/ps5-controller-control-macbook`](https://github.com/MichaelWeed/ps5-controller-control-macbook) — productivity-layer inspiration for v2.

## License

MIT — see [LICENSE](LICENSE).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Bug reports and PRs welcome.
