# Editor and document-tool quality pass

Status: completed and validated. Owner requested a substantial reliability/layout refinement
with no loss of existing features or animations. Scope: EDT-09/12 writing tools,
HIST-01 recoverable editing, FILE-12 review forms, PORT-05/09 publishing failure
boundaries and existing accessibility/layout quality requirements. Preserve the
completed article/PDF work and all unrelated working-tree changes.

Inspection found missing protection for unsaved modal fields, writing callbacks
whose source text can match after an editor/Vault change, a publishing route
that can dismiss during export, and export failures replacing the page preview.
HTML export also drops code-language/table-alignment attributes, emits closing
tags for void elements and duplicates a note's leading title.

Plan:

1. Reproduce the concrete failures with public widget/domain behavior tests.
2. Guard writing commands with captured editor/workspace generation and current
   writability/deletion checks. Keep drafts when an action becomes stale.
3. Reuse one accessible discard/keep-editing close guard for relevant authoring
   forms; unchanged forms still close immediately and in-flight writes cannot
   dismiss. Validate footnote edits before discarding their form.
4. Preserve publication preview on export failure, expose retryable feedback,
   and fix semantic/responsive HTML fidelity without changing authored sources.
5. Verify narrow/large-text, keyboard, failed saves/exports, stale ownership and
   native reopen, then required formatting/analyze/full tests and release builds.

No desktop-control testing, personal Vault access, remote account actions,
shutdown, dependency upgrades, new persistence schema or speculative feature
work is included. Validation and final release evidence follow.

## Implemented

- `OrbitDraftGuard` unifies dirty-form Close/Cancel, Escape, back and barrier
  behavior for article metadata, print settings, PDF review and writing drafts.
  Keep editing is the default; unchanged/applied forms close directly, and
  in-flight writes/exports cannot dismiss or double-submit review saves.
- Heading/footnote forms validate domain rules and identifier collisions before
  closing. Changed/read-only/closed editor contexts keep rejected text in the
  form. Temporary form edits remain in memory until normal Apply/Save.
- Writing command callbacks capture editor/repository identity, Vault opening
  generation, note/format and source. Tests cover replacement controllers with
  matching IDs, reopening the same Vault, Trash, read-only/format/note changes,
  external edits in the same frame and a removed editor with a surviving route.
- The writing sheet coalesces build-frame text updates instead of synchronously
  rebuilding a separate route during `didUpdateWidget`. It safely retains a
  snapshot when its editor closes, and stops navigation/repair on stale owners.
- Export failures leave publication pages/settings intact and show retryable
  feedback. HTML keeps safe code-language/table alignment, wraps long cells,
  emits valid void elements and relocates a repeated leading title's anchor
  rather than breaking contents/CMS links or dropping unrelated chapters.
- 21 new behavioral regressions in `test/editor_quality_test.dart`; the previous
  CMS assertion now accepts an article element carrying the preserved anchor.

## Validation so far

Three baseline regressions reproduced against the original code (discarded
article edits, closed invalid footnote form, lossy/duplicate HTML output):
`.local/editor-quality-repro.log`.

The original focused editor/PDF/publication batch passed 70 tests, followed by
all 21 final new regressions. `dart format lib test` and strict formatting cover
665 Dart files; final `flutter analyze --no-pub` reports no issues. A headless
320×640, 200% text-scale capture passed and was inspected for the validation
and discard states: `work/ui/editor-quality-{footnote,discard}-large.png`.
No desktop-control or live personal Vault testing was used.

One preliminary full-suite attempt was deliberately stopped to add the closed-
editor lifecycle regression; that partial log is retained separately as
`.local/editor-quality-tests-interrupted.log` and is not counted as a pass.
Final full-suite/build evidence will be appended after completion.

The first completed full run passed 2,419 tests with two existing skips and
one old heading-dialog assertion failure. That assertion expected a stale form
to disappear; the new behavior intentionally retains it. It now asserts the
retained draft, explanatory error and unchanged target note. All seven writing-
workflow tests pass after that update. The original result is retained as
`.local/editor-quality-tests-old-expectation.log`; a fresh full run is required.

### Final automated verification

- Final formatting/strict formatting: 665 files, no outstanding changes.
- Final static analysis: no issues (`.local/editor-quality-analyze.log`).
- Complete `flutter test --no-pub --concurrency=6`: **2,420 passed**, **2 existing
  skips**, no failures in 3m42s (`.local/editor-quality-tests.log`). This includes
  native restart/history, PDF selection/review, Canvas, code tools, recovery,
  concurrent drafts and synchronization regression coverage.
- Skips remain explicit: native symlink creation needs Windows OS permission;
  live Google-account acceptance needs manual consent and synthetic uploads.
  No permissions/account policy was changed to bypass them.
- 21 new regressions and seven writing-workflow checks pass. The large-text
  headless visual check was recaptured after the final form/error-copy change.

### Release verification

- Windows configured release passed in 97.6s through `tool/build_windows.ps1`;
  existing registered Google configuration was preserved. Standalone self-hosted
  server compilation passed; no server was launched or keys packaged.
- Standard JavaScript web release passed in 88.6s. Existing warnings remain for
  Google Identity Services' Wasm interop compatibility and the absent Cupertino
  font family. No Wasm success or live-account acceptance is claimed here.
- Runnable Windows folder verified: EXE, Flutter/PDFium/SQLite runtimes, ICU,
  Flutter assets, compiled app payload and collaboration server/launcher exist.
  No ZIP was created. The runner EXE is unchanged; current Dart code is in
  `data/app.so`, **24,560,528 bytes**, **2026-10-17 21:25:56 Europe/Vienna**, newer
  than all Dart sources. SHA-256:
  `88C4B4F73F0339AB55BA6BA545AD1F792F6A5DEA8FFAF1E55B6B490B7AD7A66B`.
  This differs from the previous payload's recorded checksum.
- Build logs: `.local/editor-quality-{windows,web}-build.log`. Bundle, freshness
  and Windows/web checksums: `.local/editor-quality-release-verification.log`.
  Final process probe found no app, test runner or collaboration server running.
- Runnable app: `build/windows/x64/runner/Release/orbit_note.exe` alongside its
  existing runtime/assets. No shutdown or desktop-control testing occurred.

This scoped pass is complete; it is not a claim that every documented feature
or every possible device/account/layout has been exhaustively validated.
Suggested next task: a Canvas selection/drag-and-drop/cross-editor clipboard
quality batch. Stop before implementing it.
