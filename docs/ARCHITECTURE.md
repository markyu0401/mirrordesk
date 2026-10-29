# Architecture

## Components

### Android companion app

- `MainActivity`: QR scanner; permission flow; connect.
- `ScreenCaptureService`: foreground service; MediaProjection; MediaCodec; TCP server.
- `Encoder`: MediaCodec H.264; Surface; output format; keyframes.
- `Pairing`: QR payload; token; handshake.
- `InputService`: AccessibilityService; gestures; keys; text.

### macOS client

- `AppDelegate`: menu; window; QR; pairing.
- `VideoDecoder`: VideoToolbox; H.264; display layer.
- `Connection`: Network.framework; TCP; protocol.
- `Input`: mouse/keyboard; messages.
- `QRCode`: CoreImage QR.

## Data flow

1. The Mac shows a QR: `mirrordesk://pair?v=1&host=<ip>&port=<port>&token=<token>`.
2. The phone scans; opens a TCP connection; sends the handshake.
3. The Mac verifies the token; sends `start`.
4. The phone requests MediaProjection consent; starts the foreground service; captures the screen; encodes H.264; sends video frames.
5. The Mac decodes; displays; sends input events.
6. Keep-alive; reconnect on drop.

## Permissions

- Android: `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PROJECTION`, `POST_NOTIFICATIONS`, `INTERNET`, `ACCESS_NETWORK_STATE`, `CAMERA` (QR).
- Android: MediaProjection consent (runtime); Accessibility service (Settings).
- macOS: Local Network (for TCP); no special permissions for input.

## Security

- Pairing token: random 128-bit; one-time; the QR contains it.
- LAN/Tailscale only; no cloud.
- Phase 1: no TLS; Phase 3: TLS with a self-signed cert; certificate pinning.

## Latency budget

- Capture + encode: 10–20 ms.
- Network (Wi-Fi 6): 5–20 ms; (USB AOA): 1–5 ms.
- Decode + display: 5–10 ms.
- Total: 20–50 ms.
