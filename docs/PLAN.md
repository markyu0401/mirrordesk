# MirrorDesk — Detailed Plan

## 1. Goals

- Mirror an Android phone screen to macOS **without adb, Developer mode, or Wireless debugging**.
- **Native macOS client**: AppKit + VideoToolbox + Metal, no SDL/FFmpeg window.
- **Low latency**: target 30–50 ms over Wi-Fi 6/5 GHz, 10–20 ms over USB AOA (optional).
- **QR pairing**: the Mac shows a QR; the phone scans; no IP/port/code typing.
- **Input**: touch, swipe, keyboard, text, back/home/recents via AccessibilityService.
- **Open source**: MIT; reproducible builds; CI; releases.

## 2. Non-goals (for Phase 1)

- Samsung DeX desktop: requires a system virtual display and shell privileges; the old adb path remains.
- Root, Shizuku, emulator, or hardware capture.
- USB debugging (USB AOA is an optional transport, no debugging).
- Single-app windows: Phase 1 mirrors the whole phone screen.

## 3. Architecture

### Android companion app

- Kotlin, minSdk 30, targetSdk 35.
- `MediaProjection` + `MediaCodec` H.264, `Surface` input.
- `AccessibilityService` for input injection.
- Foreground service with a persistent notification.
- QR scanner (CameraX + ML Kit or ZXing).
- TCP server; the Mac connects; the protocol is versioned.

### macOS client

- Swift, macOS 13+.
- AppKit window; `VideoToolbox` decoder; `AVSampleBufferDisplayLayer` or Metal.
- `Network.framework` TCP client.
- QR generation (`CoreImage`); pairing; the token.
- Input capture; the protocol.

### Protocol

- Length-prefixed binary messages.
- Handshake: magic, version, token, device info, display size.
- Video: H.264 Annex-B; SPS/PPS; frames; timestamps; keyframe flag.
- Input: touch down/move/up; key; text; scroll; global actions.
- Control: keep-alive; orientation; clipboard (optional).

See [PROTOCOL.md](PROTOCOL.md).

## 4. Milestones

### M0 — Foundation (1–2 days)

- Repository, README, LICENSE, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY, CHANGELOG.
- Docs: PLAN, ARCHITECTURE, PROTOCOL, ROADMAP, ADRs.
- Issue/PR templates; CI (Android + macOS); branch protection; labels; milestones.

### M1 — Android companion app MVP (1 week)

- Project skeleton; permissions; QR scanner; pairing.
- MediaProjection capture; MediaCodec H.264; TCP server.
- Foreground service; notification; keep-alive.
- Tests: unit tests for the protocol; instrumentation for the service.

### M2 — macOS client MVP (1 week)

- SwiftPM package; AppKit window; QR pairing.
- VideoToolbox decoder; display; input capture.
- Protocol client; reconnect; error handling.
- Tests: protocol; decoder.

### M3 — Input & UX (1 week)

- AccessibilityService gestures; keyboard; text; global actions.
- Orientation changes; clipboard; toolbar; shortcuts.
- Multi-device pairing; settings.

### M4 — Low latency (1 week)

- 120 fps; zero video buffer; hardware decode; Metal.
- Latency metrics; Wi-Fi/USB AOA comparison.
- Tuning: bitrate, resolution, keyframe interval.

### M5 — Release (1 week)

- Android APK signing; macOS app bundle; notarization; DMG.
- GitHub Releases; changelog; docs.
- End-to-end tests; user guide.

### M6 — Phase 2 (later)

- App-on-Mac: native Mac clients for apps that have them; Android VM for apps that don't.
- App streaming (single-app windows) only if the user accepts the adb/DeX path.

## 5. Risks

- **Android background restrictions**: foreground service + battery optimization exemption; the user must keep the app alive.
- **MediaProjection permission**: the user must grant screen capture every session (Android 14+ requires a fresh consent).
- **Accessibility input**: the user must enable the service; some apps block accessibility.
- **Latency**: Wi-Fi jitter; the native client helps but cannot beat a local VM.
- **App detection**: some apps block screen capture/accessibility; the mirror shows black for those.
- **Security**: the pairing token; LAN/Tailscale; no TLS in Phase 1 (add TLS in Phase 3).
- **macOS notarization**: requires an Apple Developer account; Phase 1 can be ad-hoc signed.

## 6. Alternatives considered

- **scrcpy + adb**: current; requires Developer mode; SDL/FFmpeg; rejected for the user path.
- **DeX**: requires adb/root; not Phase 1.
- **Hardware HDMI capture**: lowest latency; rejected by the user.
- **AirDroid/TeamViewer/AnyDesk**: no adb; phone mirror only; not open source; not native.
- **Android VM**: app-on-Mac; not the phone's local profile; Phase 2.
- **AOA USB**: no adb; optional transport; no DeX.
- **Shizuku**: adb once; not no-debug.
- **Root**: no adb; not viable on Samsung.

## 7. Timeline

M0: 1–2 days; M1: 1 week; M2: 1 week; M3: 1 week; M4: 1 week; M5: 1 week; M6: later. Total Phase 1: ~6 weeks.
