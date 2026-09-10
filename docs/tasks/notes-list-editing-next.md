# Proposed next task — Notes list editing comfort

Status: superseded by the owner's Rich editor stabilization request on 2026-09-10.
Its Source list behavior is implemented and tested as part of that pass. This is
historical task scope; [current task](current.md) owns active work and
[CURRENT status](../planning/implementation-status.md) owns completion evidence.

Read [current implementation status](../planning/implementation-status.md), the
relevant Notes requirements in the [spec map](../features/README.md), and
`lib/features/notes/markdown_editing.dart`, `note_editor.dart` and their tests.

Implement a small usable source-editor batch: Enter continues unordered, numbered
and checkbox lists; Enter on an empty marker exits the list; Tab/Shift+Tab indent
and outdent selected list lines. Preserve selections, IME composition, code fences,
existing undo behavior and per-pane state. Rich/Source/Split product modes still
need a separate reviewed editor implementation; do not rename the current source
field to Rich or add inert controls.

Acceptance: unit tests for edits and boundaries, widget tests for desktop keys and
undo, unchanged authored Markdown on autosave, no changes to UUIDs/open formats.
Run format, analyze, all tests and a Windows release build. Update CURRENT status
and the current task; add an ADR only if an actual architectural decision changes.
