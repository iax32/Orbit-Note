# M0-01 — Adaptive Home/Inbox shell

Status: **superseded** by the owner-authorized implementation recovery task on 2026-09-09. Original Foundation/M0 scope retained below for history.

## Outcome

Opening Orbit Note gives a small navigable Home/Inbox shell that adapts to window
width. This establishes app composition and Riverpod with no content-storage work.

## Required context only

- [Architecture overview](../architecture/overview.md).
- [UI/layout: especially the M0 subset](../architecture/ui-layout.md).
- [ADR-0002: Riverpod](../adr/0002-riverpod.md).

Inspect `lib/main.dart`, `pubspec.yaml`, `test/`, and the existing lint configuration.
Consult [setup](../development/setup.md) only for environment/checks. Do not read
every architecture document, fetch the original chat, or implement roadmap items.

## Scope

1. Keep `main.dart` as the entry point. Add an `OrbitNoteApp` root in `lib/app/`
   and a small shell in `lib/features/workspace/` (adjust exact filenames as needed).
2. Add `flutter_riverpod` using a stable version compatible with the pinned Flutter
   baseline. Commit the resolved lockfile. Use `ProviderScope` and a small Notifier
   or equivalent current non-generated Riverpod API for selected destination state.
   No code generator, hooks, router, persistence or extra packages are needed.
3. Home is selected initially. Show labelled **Home**/**Inbox** navigation:
   `NavigationRail` at widths >= 800 logical pixels and `NavigationBar` below 800.
   Preserve selection when resizing between them.
4. Home has a short welcome. Inbox has an honest empty state (for example “Your
   inbox is empty”). Do not add a nonfunctional note-creation button or fake notes.
5. Use system light/dark theme, built-in semantic controls and SafeArea as needed.

## Acceptance criteria

- [ ] Initial Home appears; selecting Inbox shows its empty state; returning works.
- [ ] Wide (1280×800) and narrow (390×844) widget tests exercise navigation.
- [ ] A resize across 800 retains the selected destination; no overflow/exceptions.
- [ ] At 390×844 with text scale 2.0, navigation and content remain usable without overflow.
- [ ] Home/Inbox controls have visible labels and are keyboard/focus accessible.
- [ ] Existing bootstrap test is adapted, and behavioral shell tests pass.
- [ ] Format/analyze/tests pass; Windows debug build and web build are attempted,
      with actual results/environmental blocks recorded.

## Explicitly out of scope

Object models, repositories, Drift/SQLite, workspace picker, file I/O, editor,
canvas/ink, tabs/splits, docking, command registry, AI, auth/sync, plugins, custom
theme/keybinding systems, and changes to platform identifiers.

## Validation

```text
flutter pub get
dart format lib test
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build windows --debug
flutter build web
```

Report failures honestly and resolve task-caused failures before stopping. Do not
install unrelated toolchains or change architecture simply to mask a host problem.

## Completion record — fill after implementation

- Status / date: pending.
- Behavior and relevant files changed: pending.
- Checks and outcomes / blocked checks: pending.
- Architecture changed: no change expected; ADR only if a decision actually changes.
- Follow-up: suggest one M1 task; do not start it.

Update this record and milestone status when done. Edit design docs only if
documented behavior changes. Preserve this task as a completed record before a
future task replaces `current.md`; do not silently redefine acceptance criteria.
