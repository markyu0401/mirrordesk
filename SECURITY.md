# Security

MirrorDesk controls your phone through **ADB (Android Debug Bridge)**. Enabling Wireless debugging and pairing a computer grants that computer full device control — installing apps, reading data, sending input, taking screenshots. Only pair Macs you trust, and turn Wireless debugging off when you are done.

## What MirrorDesk does with your data

- **Local only.** No analytics, telemetry, accounts, ads, or cloud relay. The only network traffic is ADB to your phone (LAN or Tailscale).
- **Notifications** are read locally with `adb shell cmd notification list/get` and posted to macOS Notification Center. Nothing is uploaded.
- **Pairing keys** are managed by adb and stored in `~/.android/adbkey` (standard adb behavior).
- **State** (last known phone address) is stored in `~/.local/share/mirrordesk/state`.

## Touch ID gate

Mirroring can be gated behind Touch ID or your Mac login password (`Mirror → Require Touch ID`, on by default). This does not change the fact that ADB itself has full control of the phone.

## Signing

Release builds are **ad-hoc signed**, not notarized by Apple. Build from source if you prefer to inspect and compile everything yourself.

## Reporting a vulnerability

Please open a private security advisory on GitHub (Security → Advisories → New draft security advisory) instead of a public issue. Include reproduction steps and the affected version.
