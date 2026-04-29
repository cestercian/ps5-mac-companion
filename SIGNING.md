# Free-tier signing test (no $99 needed)

We want to know if the macOS 26 lightbar/trigger gating is unlocked by *any*
real signing identity (not just ad-hoc). The free Apple Developer tier lets
you sign with a "Personal Team" identity. If the lightbar starts changing
after this, we've answered the question without paying.

## Steps

1. **Open the Xcode project**
   ```
   open PS5MacCompanion.xcodeproj
   ```

2. **Add your Apple ID to Xcode** (one-time, free)
   - Xcode → Settings (⌘,) → Accounts
   - Click `+` → Apple ID → sign in with your normal Apple ID
   - You don't need to enroll in the paid Developer Program

3. **Set the signing team on the target**
   - Click the `PS5MacCompanion` project icon in the left sidebar
   - Select the `PS5MacCompanion` target
   - Click the **Signing & Capabilities** tab
   - Check **Automatically manage signing**
   - In the **Team** dropdown, pick `Your Name (Personal Team)`
   - The bundle identifier may need to be unique — Xcode will warn you;
     change it to something like `com.<yourname>.ps5maccompanion`

4. **Run** (⌘R)
   - Xcode builds + signs + launches the app
   - On first run macOS may prompt for Input Monitoring or controller
     permissions — accept

5. **Test**
   - Plug in your DualSense via USB-C
   - Click the menubar gamecontroller icon
   - Try the color preset buttons (Pink, Lime, Cyan, etc.)
   - Open Settings → Triggers → set L2 to Weapon, squeeze L2

6. **Read the result**
   - **If the lightbar follows your color picks AND triggers engage**:
     the gating was the signing identity. Free-tier signing unlocks it.
     You can use the app as-is.
   - **If the lightbar still doesn't change**: free-tier signing isn't
     enough. The gating is probably either a paid Developer ID,
     notarization, or App Store sandbox capability. At that point, the
     practical paths are (a) shelve lightbar/triggers and lean on the
     features that DO work (rumble, input, battery, profiles), or
     (b) enroll in the paid Apple Developer Program ($99/yr) and try
     again.

## What success looks like in the log

Run this in another terminal to watch the live log:
```
tail -f ~/Library/Containers/com.<yourname>.ps5maccompanion/Data/Library/Logs/DualSenseMac.log
```

Or use Console.app and filter for `PS5MacCompanion`.

When you set a color, you should see in the log:
```
GCBridge.setLightbar: set to (R,G,B)
```

And after a setMode call, the readback:
```
GCBridge.readback L2: mode=N status=N arm=N
```

Where `mode` ≠ 0 — that means Apple actually applied our setMode call.
With ad-hoc signing today, `mode` is always 0 even after we set it.

## If Xcode complains about the bundle ID

Free-tier signing requires a globally-unique bundle ID. Just change it:
- Project → target → General tab → Bundle Identifier
- Set to `com.<yourname>.ps5maccompanion`
- Re-build
