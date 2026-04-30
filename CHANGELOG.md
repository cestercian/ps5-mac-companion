# Changelog

All notable changes to this project will be documented in this file. The
format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- **Vibrate on system notifications.** New `NotificationWatcher` polls the
  macOS Notification Center SQLite database (`~/Library/Group
  Containers/group.com.apple.usernoted/db2/db`) once per second and
  triggers a 3-second rumble pulse on both motors for each new notification
  from any app. Requires Full Disk Access. UI toggle in the menubar with a
  deep-link button to the right pane in System Settings if access isn't
  granted yet.
- Profile fields: `notificationsEnabled` (Bool),
  `notificationRumbleDurationMs` (Int), `notificationRumbleStrength` (UInt8).

## [0.1.0] — 2026-04-29

First public release. v1 baseline: native menubar app for the DualSense
controller on macOS 13+.

### Added

- IOKit HID layer: connection detection (USB-C, Bluetooth), input report
  parsing, output report writing.
- `GameController.framework` bridge: `GCDeviceLight`, `GCDualSenseAdaptiveTrigger`,
  and `GCHaptics` paths for system-supported features.
- SwiftUI menubar app with 6 quick color presets, test rumble button,
  and an Open Settings shortcut.
- Settings window with 5 tabs: Lightbar, Triggers, Motors, LEDs, Input Tester.
- 5 trigger effect modes: Off, Feedback, Weapon, Vibration, Slope.
- Profile persistence to `~/Library/Application Support/DualSenseMac/profile.json`
  with auto-save and re-apply on launch.
- Per-handle rumble via two `CHHapticEngine` instances (`.leftHandle`,
  `.rightHandle`).
- Live input visualizer for sticks, triggers, buttons, d-pad, touchpad,
  battery, and headphones detection.
- Diagnostic logging on every output write and a 250ms-deferred trigger
  status readback (`mode`, `status`, `armPosition`).
- Xcode project (xcodegen-generated) for free-tier signing experiments.
- `SIGNING.md` walkthrough for empirical signing-identity testing.

### Known Issues

- macOS 26 silently no-ops third-party `GCDeviceLight.color` and
  `GCDualSenseAdaptiveTrigger.setMode*` writes after the initial
  attach-time write. Trigger `mode` reads back as `0` (Off) regardless
  of `setMode` parameters. Plausibly gated behind a paid Developer ID,
  notarization, or App Store sandbox capability — see [SIGNING.md].
- Right rumble motor (high-frequency) is partial on macOS 26 — `GCHaptics`
  with `.rightHandle` locality fires inconsistently for some payload
  intensities.
- Player LED brightness "high" is silently absorbed (likely the same
  byte-0 reserved-as-default issue as lightbar).
