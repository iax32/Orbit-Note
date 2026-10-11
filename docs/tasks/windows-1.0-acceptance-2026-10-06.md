# Windows 1.0 acceptance matrix — 2026-10-06

This is the release checklist for the frozen Windows x64 1.0 artifact. A row is
complete only when the automated evidence and the clean-machine/manual evidence
are both present. The matrix deliberately keeps Android and Web out of the 1.0
artifact.

## Automated gates

| Area | Evidence | Status |
|---|---|---|
| Formatting | `dart format --output=none --set-exit-if-changed lib test` | Passed |
| Static analysis | `flutter analyze --no-pub` | Passed, 0 issues |
| Full regression suite | `flutter test --no-pub` | Passed, 1,265 tests |
| Recovery isolation | `test/workspace_recovery_test.dart` | Passed |
| Backup round-trip | `test/backup_import_test.dart` | Covered by full suite |
| Markdown/editor behavior | rich editor, native editing, tables, math, search, history tests | Covered by full suite |
| PDF behavior | reader reliability, bookmarks, notes, export, forms, split-view tests | Covered by full suite |
| Canvas behavior | pen, blueprint, groups, search, import/export, performance tests | Covered by full suite |
| Workflow syntax | YAML parse for `.github/workflows/ci.yml` and `release.yml` | Passed |

## Clean Windows machine

- [ ] Extract the exact `OrbitNote-Windows-x64.zip` beside an empty test Vault.
- [ ] Launch without developer tools, a Dart/Flutter installation, or network.
- [ ] Create, edit, close, and reopen Markdown notes; confirm the source files
      remain readable outside Orbit Note.
- [ ] Create a folder, move a note, rename a note, and reopen the Vault.
- [ ] Import and export a backup; compare object count, attachments, unknown
      fields, and retained recovery files.
- [ ] Open a PDF, use thumbnails/outline/search/zoom, quote text into a note,
      add a bookmark/comment, close, reopen, and verify the state.
- [ ] Create a Canvas with cards, ink, blueprint paper, images, and links;
      pan/zoom, save, reopen, and export it.
- [ ] Test 100%, 125%, 150%, and 200% Windows display scaling plus a narrow
      window. Confirm no clipped actions or unreachable dialogs.
- [ ] Test offline startup and editing, then verify the checksum manifest.
- [ ] Record the Windows version, GPU, display scale, artifact hash, and result
      in the release issue before publishing.

## Release decision

Publish only when every automated gate is green and the clean-machine checklist
has evidence. Android signing, Android device testing, browser persistence, and
Web folder import are follow-up release tracks, not implicit 1.0 requirements.
