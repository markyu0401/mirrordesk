# Protocol

## Transport

TCP; the phone is the server; the Mac is the client. Length-prefixed messages:

```
uint32 length (big-endian)
uint8  type
bytes  payload
```

## Handshake

- `HELLO` (Mac → phone): magic `MRDK`, version, token, client info.
- `WELCOME` (phone → Mac): version, device info, display width/height, rotation.
- `START` (Mac → phone): start capture.
- `READY` (phone → Mac): capture started.

## Video

- `VIDEO_CONFIG`: SPS/PPS (Annex-B).
- `VIDEO_FRAME`: flags (keyframe), pts, data (Annex-B NAL units).

## Input

- `TOUCH`: action (down/move/up), x, y, pointer id.
- `KEY`: keycode, action.
- `TEXT`: UTF-8.
- `SCROLL`: dx, dy.
- `GLOBAL`: back/home/recents.

## Control

- `PING`/`PONG`: keep-alive.
- `ORIENTATION`: rotation.
- `CLIPBOARD`: text (optional).

## Errors

- `ERROR`: code, message.
