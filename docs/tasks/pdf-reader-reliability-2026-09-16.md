# PDF reader reliability and connected notes — 2026-09-16

Owner request: fix PDF reading and strengthen its connection to note taking.

Implemented:
- Searchable connected notes from existing source metadata and backlinks, without
  duplicating objects. Open the actual note beside its PDF and return to a saved
  highlight region. Warn about changed source versions and reject stale geometry.
- Preserve page/zoom across page-layout changes; flush position before leaving;
  normalize invalid page input. Retry re-reads bytes and source replacement
  invalidates the rendered document.
- Remove broad highlight hit areas that blocked text selection. Handle passage
  taps against actual regions. Keep comments open after failed saves for retry.
- Guard concurrent selection saves, changed-source quote/filled-copy operations,
  clipboard failures and thrown form-save callbacks.

Validation:
- All **37 PDF tests passed**, including nine new lifecycle, save recovery,
  connected-note and navigation regressions.
- `dart format lib test` passed; analyzer reported no issues.
- Independent pypdf export checks passed: annotation types, Unicode, colors,
  geometry, rotation, original text/images and an editable round-trip.
- Connected-notes capture inspected at 390px: filtering and stale-source text fit
  without overflow. Existing native reader tests also exercise desktop/phone PDF
  rendering, search, bookmarks, corrupt files and missing-file fallback.
- Full suite: **605 passed, 10 failed**. Failures are in bootstrap layout,
  canvas export/context menus, Continue Writing, folder explorer, editor slash
  heading, and Home work sessions. They remain unresolved outside this PDF pass;
  newer concurrent feature changes were preserved. Log:
  `.local/pdf-reliability-all-tests.log`.
- `git diff --check` finds three trailing spaces inside another task's generated
  Markdown string in `workspace_views.dart`; that content was left unchanged.

Build validation:
- Windows release build passed (29.7s). The executable remained running and
  responsive during a five-second startup smoke test; only that test process was
  closed. Output: `build/windows/x64/runner/Release/orbit_note.exe`.
- Web build passed (92.3s), with the existing Google JS-interop WASM dry-run and
  Cupertino font advisories. This is not a WASM or browser-runtime acceptance claim.
- No-change formatting passed for all 232 Dart files.
- Initial Windows build attempts needed project-local plugin junctions restored
  and a sequential retry after native tests released `pdfium.dll`. No system
  Developer Mode change was needed.
- Logs: `.local/pdf-reliability-{analyze,pdf-tests,windows-build,web-build}.log`.

Limits: tests cover fixture PDFs and Windows native rendering, not every document
or every device. OCR and annotation import are not implemented by this pass.
Original PDF bytes and existing workspace storage remain unchanged.

Suggested next task: resolve the ten non-PDF regression failures before declaring
the combined workspace release-ready.
