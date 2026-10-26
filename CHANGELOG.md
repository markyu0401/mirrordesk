# Changelog

All notable changes to MirrorDesk are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.5.4] - 2026-10-26

### Added

- **Mirror → Dim phone screen**: keeps the phone unlocked but sets its screen brightness to 0 (the system clamps it to 1), so the full DeX taskbar stays visible while the phone screen looks off. The previous brightness and brightness mode are restored when mirroring stops.

### Changed

- Documented that Samsung replaces the full DeX taskbar with a reduced lock-screen bar whenever the keyguard is showing; there is no native setting or adb switch to keep the full bar on the lock screen.

## [1.5.3] - 2026-10-26

### Added

- **Mirror → Keep phone awake**: sets the phone's screen timeout to never and enables stay-on while mirroring; restores the previous values on stop.
- **Mirror → Auto-unlock when phone locks**: polls the keyguard every 2 s and wakes/dismisses it when the phone locks, so the full DeX taskbar returns.

### Fixed

- The DeX taskbar collapsing to the reduced lock-screen bar when the phone locks.

## [1.5.2] - 2026-10-26

### Changed

- The mirroring engine is now a nested accessory app (`LSUIElement`) inside `MirrorDesk.app`; macOS shows only MirrorDesk in the Dock and the app switcher.
- The engine is signed and bundled; no separate scrcpy install.

### Fixed

- A separate `scrcpy` app appearing in the Dock.

## [1.5.1] - 2026-10-26

### Fixed

- The title-bar toolbar drifting behind the window during drags: the follow timer now runs at 60 Hz in the common run-loop mode.
- App Nap throttling the tracker while the mirror was in the background (latency-critical activity assertion).

## [1.5.0] - 2026-10-26

### Added

- Language switcher in the README (English / 简体中文).

### Changed

- The toolbar is docked in the window's title bar at the top-right, next to the native traffic lights; it is a compact 148×26 transparent strip (Back / Home / Recents / All apps / mode), not a floating pill.
- Menu item renamed to **Show title-bar toolbar**.
- The toolbar only appears while the mirror window is focused and on the current Space.

## [1.4.0] - 2026-10-26

### Added

- **Mirror → Input → Low latency mode**: video buffer 0 ms and 16M bitrate.
- README notes on why the cursor feels remote and how the buffer trades latency for smoothness.

## [1.3.0] - 2026-10-26

### Added

- **Mirror → Input → Pointer speed** (0–7).
- Corrected pointer-acceleration toggle: on Samsung, `mouse_pointer_acceleration=1` means acceleration is **off**.

### Fixed

- Cursor overshoot/jump on fast trackpad swipes.

## [1.2.0] - 2026-10-26

### Changed

- English-only UI, README, alerts, connection script, and notification app names.

### Fixed

- The automatic adb retry no longer quits the app when the old scrcpy process terminates (`retryScheduled` guard).

## [1.1.0] - 2026-10-26

### Added

- **Mirror → Input → Scroll speed** (writes `mouse_scrolling_speed`).
- **Mirror → Input → Absolute mouse (no capture)**.
- ⌥ releases/recaptures the default UHID mouse.

### Changed

- The floating toolbar only appears with the mirror window (same Space, focused) and sits at the top-center inside the window.
- Hide it with **Mirror → Show floating toolbar**.

## [1.0.0] - 2026-10-26

### Added

- Initial public release: Android screen mirroring and Samsung DeX desktop on macOS.
- Wireless ADB (LAN/Tailscale) or USB; self-contained scrcpy 5.0.1 + adb.
- Phone screen and DeX desktop modes.
- Toolbar: Back / Home / Recents / All apps / mode switch.
- Audio, clipboard, drag-and-drop push, pull files, notification mirroring, Touch ID gate.
- Apple Silicon, macOS 13+.

[Unreleased]: https://github.com/markyu0401/mirrordesk/compare/v1.5.4...HEAD
[1.5.4]: https://github.com/markyu0401/mirrordesk/compare/v1.5.3...v1.5.4
[1.5.3]: https://github.com/markyu0401/mirrordesk/compare/v1.5.2...v1.5.3
[1.5.2]: https://github.com/markyu0401/mirrordesk/compare/v1.5.1...v1.5.2
[1.5.1]: https://github.com/markyu0401/mirrordesk/compare/v1.5...v1.5.1
[1.5.0]: https://github.com/markyu0401/mirrordesk/compare/v1.4...v1.5
[1.4.0]: https://github.com/markyu0401/mirrordesk/compare/v1.3...v1.4
[1.3.0]: https://github.com/markyu0401/mirrordesk/compare/v1.2...v1.3
[1.2.0]: https://github.com/markyu0401/mirrordesk/compare/v1.1...v1.2
[1.1.0]: https://github.com/markyu0401/mirrordesk/compare/v1.0...v1.1
[1.0.0]: https://github.com/markyu0401/mirrordesk/releases/tag/v1.0
