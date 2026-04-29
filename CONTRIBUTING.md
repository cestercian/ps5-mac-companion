# Contributing

Thanks for taking an interest. This project is small and easy to get into.

## Dev environment

- macOS 13+
- Xcode 15+ (for the .xcodeproj-based signing flow) **or** the Swift 5.9+
  command-line toolchain (for `swift build` / `swift run`)
- A DualSense controller for empirical testing

## Build & run

### From Xcode
```bash
open PS5MacCompanion.xcodeproj
# select target → Signing & Capabilities → pick your team → ⌘R
```

### From the command line
```bash
swift build
swift run DualSenseMac
```

### Regenerate the .xcodeproj after editing project.yml
```bash
brew install xcodegen   # if not already installed
xcodegen generate
```

## Project layout

See [README.md → Architecture](README.md#architecture) for the full
breakdown. The two pieces most contributors will touch:

- **`Sources/DualSenseMac/HID/`** — the protocol layer (input parsing,
  output report bytes, GameController framework bridge).
- **`Sources/DualSenseMac/UI/`** — SwiftUI menubar + tabs.

## Where to look first if you want to help

1. **macOS 26 output-write gating.** The biggest open question: which
   signing identity / entitlement / Info.plist key actually unlocks
   `GCDualSenseAdaptiveTrigger.setMode*` and `GCDeviceLight.color`
   subsequent writes. See [SIGNING.md](SIGNING.md) for the test
   methodology. If you have a paid Apple Developer account, please
   try running this signed with Developer ID and notarized, and
   report back in an issue with what `mode` reads back as.
2. **Bluetooth output report.** Currently we write USB-format output
   reports (47 bytes). On Bluetooth the controller ignores them — we'd
   need to build the 78-byte BT format with the `0xA2 0x31` prefix and
   CRC32 trailer. See `nondebug/dualsense` for the layout.
3. **Notification → vibration.** macOS doesn't expose a global notification
   stream. The realistic options: poll the Notification Center SQLite db,
   use the Accessibility API to scrape the NC popup, or wire per-app
   integrations (Slack/Discord/Mail). All have trade-offs documented in
   the original plan.
4. **Productivity layer.** Map face buttons to keyboard shortcuts via
   `CGEventTap` (similar to MichaelWeed's Karabiner config but native).

## Coding style

- Swift 5.9 conventions; no third-party dependencies.
- All `@Published` mutations from SwiftUI binding setters MUST be wrapped
  in `defer_(_:)` (defined in `LEDsTab.swift`). Mutating `@Published`
  state synchronously inside a render cycle triggers SwiftUI's
  "Publishing changes from within view updates" runtime error.
- Use `NSLog` for diagnostic logging. It routes to both stderr (visible
  in `swift run` output) and the unified log (visible in `Console.app`).
- Avoid third-party Swift packages — keeping the dependency graph empty
  makes it trivial to audit and to ship as a notarized binary later.

## Running with a debugger

```bash
lldb .build/debug/DualSenseMac
(lldb) run
```

The app opens HID immediately on launch, and the keepalive timer fires
every ~33 ms. Set breakpoints in `AppState.pushOutput` or
`GameControllerBridge.apply(...)` to watch the data flow.

## Submitting a PR

1. Open an issue first if it's a substantive change — happy to discuss
   approach.
2. Keep commits small and well-described.
3. Run `swift build` cleanly (no warnings).
4. Test on real hardware. State which controller firmware revision
   (`Settings → Game Controllers → identify`) you tested on.

## Code of conduct

See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md). The short version:
be kind, focus on the code, assume good intent.
