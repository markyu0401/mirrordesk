# Contributing

Thanks for helping! A few ground rules:

- **Bug reports**: include macOS version, Android version/phone model, whether you are on Wi-Fi or USB, and the contents of `~/Library/Logs/MirrorDesk.log`.
- **Pull requests**: keep them focused; describe what you tested (which mode, which phone). The app is a single Swift file plus a zsh connection script — keep it simple and dependency-free.
- **DeX quirks** are undocumented Samsung behavior. If you find a workaround, document it in the PR.
- **Do not** add telemetry, accounts, cloud services, or phone-side apps.

## Build

```sh
./build.sh
```

Requires Xcode command line tools. The script downloads the official scrcpy macOS arm64 release, verifies its SHA-256, compiles the app, generates the icon, and ad-hoc signs it.

## Code layout

- `Sources/main.swift` — the AppKit app (window toolbar, lifecycle, notifications, Touch ID, pairing).
- `Resources/mirrordesk` — zsh script that resolves the phone (cache → Bonjour → LAN/Tailscale), restarts adb if wedged, and launches scrcpy.
- `Resources/Info.plist` — bundle metadata.
- `scripts/make-icon.swift` — generates the app icon.
