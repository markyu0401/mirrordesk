# Roadmap

| Milestone | Scope | Status |
|---|---|---|
| M0 | Foundation: repo, docs, CI, templates, ADRs | Done |
| M1 | Android companion app MVP | In progress |
| M2 | macOS client MVP | Planned |
| M3 | Input & UX | Planned |
| M4 | Low latency | Planned |
| M5 | Release | Planned |
| M6 | Phase 2: app-on-Mac | Later |

## M0 — Foundation (done)

- **PR #1** — foundation: README, PLAN, ARCHITECTURE, PROTOCOL, ROADMAP, ADRs, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY, CHANGELOG; issue/PR templates; Android and macOS CI; compilable Android (Kotlin) and macOS (Swift) skeletons. Merged as `2a99e6b`; Android CI and macOS CI green. Closes #2.
- **PR #9** — removed the old scrcpy/adb app and its bundled binaries. Merged as `6011357`; Android CI and macOS CI green.
- **PR #10** — removed the old scrcpy-era icon generator script. Merged as `b9ed00f`; Android CI and macOS CI green.

Main is at `b9ed00f` with both CI workflows passing.

## M1 — Android companion app MVP (in progress)

MediaProjection capture, MediaCodec H.264, TCP transport, QR pairing, foreground service, permission flow. Acceptance: the phone screen streams to a test client.
