# ADR 0002: MediaProjection + AccessibilityService

## Status
Accepted

## Context
A normal app cannot create a system virtual display or launch other apps on it.

## Decision
Use `MediaProjection` for screen capture and `AccessibilityService` for input injection.

## Consequences
- No adb/root; the user grants runtime permissions.
- Only the phone screen; no single-app windows or DeX.
- Some apps block capture/accessibility.
