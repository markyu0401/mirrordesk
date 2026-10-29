# ADR 0003: Native macOS client

## Status
Accepted

## Context
The scrcpy SDL window feels like a layer.

## Decision
Build a native macOS client with AppKit + VideoToolbox + Metal.

## Consequences
- Native window, hardware decode, lower latency.
- More code than wrapping scrcpy.
