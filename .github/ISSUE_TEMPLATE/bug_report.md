---
name: Bug report
about: Something doesn't work as documented
title: "[bug] "
labels: bug
assignees: ""
---

## What happened
<!-- A clear description of the bug. -->

## What you expected to happen
<!-- What you thought would happen. -->

## Reproduction steps
1.
2.
3.

## Environment
- macOS version: <!-- e.g. 14.4 / 26.4.1 -->
- DualSense firmware: <!-- find via System Settings → Game Controllers → Identify -->
- Connection: USB-C / Bluetooth
- Build: SwiftPM (`swift run`) / Xcode (signed with: ad-hoc / Personal Team / Developer ID)

## Logs

Please include relevant log output. Run the app from a terminal:
```bash
swift run DualSenseMac 2>&1 | tee /tmp/ps5mac.log
```

Then attach `/tmp/ps5mac.log` (or paste the relevant lines).

If a feature is silently no-op'ing (no error but the controller doesn't
respond), grep for the `GCBridge.readback` line — it tells us what the
controller's actual state is after our write:

```bash
grep "GCBridge.readback" /tmp/ps5mac.log | tail -5
```
