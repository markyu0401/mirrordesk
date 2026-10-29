# MirrorDesk

Native Android screen mirroring for macOS — **no adb, no Developer mode, no emulator layer**.

MirrorDesk pairs your Android phone with a native macOS client over your local network or Tailscale. The phone runs a small companion app that captures the screen with `MediaProjection`, encodes it with `MediaCodec`, and streams H.264 over TCP. The Mac decodes with `VideoToolbox` and renders with Metal. Input is injected on the phone through an `AccessibilityService`.

## Status

**M1 — Android companion app MVP.** M0 (foundation, docs, CI, ADRs) is done. See [docs/PLAN.md](docs/PLAN.md) for the detailed plan and [docs/ROADMAP.md](docs/ROADMAP.md) for milestones.

## Why

The previous MirrorDesk wrapped scrcpy and adb: it required Developer options and Wireless debugging, and the SDL/FFmpeg pipeline felt like a layer. This rewrite removes adb from the user path:

- **No Developer mode** — the companion app uses the public `MediaProjection` and `AccessibilityService` APIs.
- **No adb** — the transport is a direct TCP connection, paired by QR code.
- **Native Mac client** — AppKit + VideoToolbox + Metal, no SDL window.
- **Low latency** — hardware encode/decode, 120 fps, zero video buffer.

The trade-off: this mirrors the **phone screen**, not Samsung DeX. A true DeX desktop needs a system virtual display and shell privileges; that remains the old adb path.

## Architecture

```
┌─────────────────────────┐         TCP (LAN / Tailscale)        ┌──────────────────────────┐
│ Android companion app   │ ───────────────────────────────────▶ │ macOS native client      │
│                         │                                      │                          │
│ MediaProjection         │  H.264 Annex-B + input messages      │ Network.framework        │
│ MediaCodec (H.264)      │ ◀─────────────────────────────────── │ VideoToolbox + Metal     │
│ AccessibilityService    │         input events                 │ AppKit window            │
│ QR pairing + server     │                                      │ QR pairing               │
└─────────────────────────┘                                      └──────────────────────────┘
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and [docs/PROTOCOL.md](docs/PROTOCOL.md).

## Build

### Android

```bash
cd android
./gradlew assembleDebug
```

Requires Android SDK 35+ and JDK 17.

### macOS

```bash
cd macos
swift build
swift test
```

Requires macOS 13+ and Xcode 15+.

## Usage

1. Install the companion app on the phone.
2. Open the Mac client; it shows a QR code.
3. On the phone, open the companion app and scan the QR.
4. Grant screen capture and accessibility permissions.
5. The Mac shows the phone screen; mouse and keyboard input are forwarded.

## Roadmap

- **M0** — repository foundation, docs, CI, templates, ADRs.
- **M1** — Android companion app MVP: capture, encode, TCP server, QR pairing, foreground service.
- **M2** — macOS client MVP: AppKit window, VideoToolbox decode, QR pairing, input.
- **M3** — input and UX: accessibility gestures, keyboard, clipboard, orientation.
- **M4** — low-latency: 120 fps, zero buffer, hardware decode, latency metrics.
- **M5** — release: packaging, notarization, DMG, APK.
- **M6** — Phase 2: app-on-Mac experience (native Mac clients, Android VM, or app streaming).

## License

MIT — see [LICENSE](LICENSE).
