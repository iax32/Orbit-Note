# ADR-0001 — Flutter with Windows first

- Status: accepted
- Date: 2026-09-07
- Scope: application foundation
- Supersedes: none

## Context

Orbit Note needs desktop productivity UI plus mobile/tablet and browser viability,
including custom spatial drawing. The product owner selected Flutter.

## Decision

Use Flutter/Dart in one application package. Develop on Windows first and retain
Android/iOS/web runners and platform boundaries. Bootstrap baseline: Flutter 3.44.8
stable / Dart 3.12.2. Keep the Dart package `orbit_note`, display name `Orbit Note`,
and development mobile application ID `org.orbitnote.app`.

## Alternatives

Electron/Tauri with web UI, or separate native clients, are plausible. They were
not selected because a single Flutter codebase matches the owner's direction and
shared UI/ink needs. Do not claim Flutter removes platform-specific work.

## Consequences

Use adaptive input/layout and platform I/O adapters. iOS development requires a
Mac/Xcode; native desktop and mobile tooling remain necessary. Flutter's support
does not guarantee every dependency works on every target. Follow the
[official setup guidance](https://docs.flutter.dev/platform-integration/windows/setup).

## Validation / follow-up

M0 checks the shell, Windows build and web viability. Test real stylus hardware,
accessibility and large canvases when those features arrive. SDK upgrades require
re-running relevant checks, not automatic template regeneration over user changes.
