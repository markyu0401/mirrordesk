# ADR 0004: Length-prefixed binary protocol over TCP

## Status
Accepted

## Context
Need a simple, versioned protocol for video and input.

## Decision
TCP; length-prefixed messages; H.264 Annex-B; typed input messages.

## Consequences
- Simple to implement; easy to debug.
- No TLS in Phase 1; add later.
