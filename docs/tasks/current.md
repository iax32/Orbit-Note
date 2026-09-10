# Current task — stabilize the editable Rich Markdown editor

Status: bounded stabilization batch delivered, 2026-09-10. Preserve
the local core, Vault/folder work and existing tests. The owner's direct Rich
editor continuation request supersedes the former proposed Notes list task.

## Scope and acceptance

Write directly in formatted paragraphs, headings and lists while Markdown remains
the durable source. Finish formatting boundaries, naturally editable paragraphs
after Enter, list continuation/exit/nesting, visual table cells/row/column commands,
highlighted editable code and content-only Copy Code. Render inline/block LaTeX
in Rich and Read, with local equation editing and safe invalid-source fallback.

Preserve Rich/Source/Read/Split, shared document undo/redo, practical per-pane
restoration, unknown constructs and all unrelated source bytes. Add behavioral
round-trip and keyboard regressions. Do not introduce cloud, plugins, AI, Calendar
or another unrelated subsystem in this editor stabilization pass.

## Targeted reading

- [Markdown editing requirements](../features/markdown-and-editing.md), EDT-01–15.
- [Rich projection decision](../adr/0011-source-preserving-rich-markdown.md).
- [Storage authority](../architecture/storage-formats.md).
- Relevant `lib/features/notes/` implementation and Rich/editor tests.

## Validation and handoff

Run `dart format lib test tool`, the zero-change format check, `flutter analyze`,
`flutter test`, and `flutter build windows --release`. Smoke-launch the release
when possible. Validate after meaningful batches; stop adding features before
capacity prevents completing the final gates.

The [CURRENT capability map](../planning/implementation-status.md) owns final
evidence and limitations. Preserve historical evidence in the
[audit/folder snapshot](../planning/audit-folder-snapshot-2026-09-09.md).
Final format/zero-change check and analyzer pass. All 112 tests pass. The Windows
release build passed (37.7 seconds); the rebuilt app created a responsive native
window and closed normally with exit code 0 and no stderr. Existing user processes
were preserved. See CURRENT status for the final compatibility check and exact limits.

Next bounded task: improve Rich selection/formatting across inline equation
segments and blocks, with representative large-note layout measurements. Do not
restart the projection or claim complete Word/Typora parity. Keep the source
round-trip, shared undo and local save/conflict invariants proven in this batch.
