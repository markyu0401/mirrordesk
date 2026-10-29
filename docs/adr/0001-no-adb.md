# ADR 0001: No adb in the user path

## Status
Accepted

## Context
The previous MirrorDesk wrapped scrcpy and adb; it required Developer options and Wireless debugging.

## Decision
Use a companion app on the phone with `MediaProjection` + `MediaCodec`, and a direct TCP transport. No adb.

## Consequences
- No Developer mode; the user grants screen capture and accessibility.
- No DeX desktop; the app mirrors the phone screen.
- The Mac client is a native app.
