# Creation and source/file workflow quality

Status: validated, 2026-10-19. Owner requests continued stress testing of subtle
hard-use failures. Scope: existing VIEW-03/04 creation, FILE-01/06/09 source/model
previews, DEV-01/03 source browser and delayed external-open ownership.

Plan: reproduce wrong-type creation, retry/missing-file behavior, stale preview
and source-operation completions, unusually large listings/files and narrow
layouts. Reuse current repository/platform adapters; preserve originals, unknown
data and independent identities. Test synthetic/temporary sources only. Run
format, strict format, analyze, full tests and configured release builds. No
desktop control, personal Vault changes, new dependencies, migration or shutdown.
Stop after this batch and one suggested next task.

## Changes

- Other-type inline creation no longer manufactures a task in another column;
  unsupported types point to existing New/Import flows. Tasks-only type groups
  cannot create invisible notes/boards. Retained Add/keyboard/Cancel handlers are
  bound to their original board/workspace and cannot consume a later draft.
- Code preview gets retry, known-size preflight and versioned refresh. Loading
  renders an explicit waiting state instead of retaining old FutureBuilder data
  under a new filename. Actual UTF-8/binary/size validation remains unchanged.
- Model decoding captures immutable filename/loader inputs before awaiting;
  retired byte requests skip expensive decoding. Preview version changes retire
  old geometry and reset the camera; stable versions retain camera/selection and
  avoid repeated reads on parent rebuild. Existing model Retry also returned a
  Future from setState, triggering a Flutter assertion; that is fixed.
- Shell preview versions include the current attachment-change revision, so byte
  invalidation refreshes visible source even without a metadata/checksum change.
- Source evidence/copy completion labels belong to the original read request.
  Source-line width is cached at read time, avoiding repeated whole-file splits
  during selection/theme updates. Exact source and existing scan limits remain.
- External opening captures repository, Vault generation/ID, location, attachment
  revision and source metadata. Retired confirmations/read completions neither
  read another Vault nor launch a replacement/deleted source. Missing references
  report a usable error. File pickers reject a retired scope before byte loading.

## Validation

18 new behavior regressions: 11 in `file_workflow_quality_test.dart`, 4 in
`file_open_context_test.dart` and 3 additional cases in `kanban_quality_test.dart`.
The final focused matrix passes **58 tests**. It includes 40 out-of-order reads,
30 unchanged-source parent rebuilds preserving selection, 20 unchanged-model
rebuilds preserving the camera, a 5,000-file lazy/filter listing, missing-file
retry, size preflight/correction, native source boundaries and retained inline
callbacks after switching/disposal. No elapsed-time/frame-rate guarantee is made.

Full-shell in-memory tests confirm a pending external-open prompt is retired after
a real repository Vault switch, source deletion or attachment invalidation, with
zero attachment reads/launcher calls afterward. Another shell test changes only
synthetic attachment bytes and the existing invalidation signal, verifying current
code replaces the old preview while stored metadata stays unchanged. URL launching
is mocked; no programs, Explorer windows or source code are executed.

Initial reproduction found three actual UI/context failures; test helpers also
needed bounded spinner pumping and list-scoped text finders. Full-shell fixture
attempts stalled when mixing real-async and fake-clock repository queues. Keeping
memory-store operations in the widget-test clock, cancelling session timers and
pausing synthetic indexing resolved that fixture issue. It is not reported as a
production Vault-switch defect. Initial attempts are not counted as passing runs.

Format/strict formatting check **671 files**, clean. `flutter analyze` reports no
issues (8.0 s). Full `flutter test --no-pub --concurrency=6 --reporter expanded`
passes **2,521 tests**, with **2 existing skips**, in **5 min 22 s**. Skips retain
the native Windows symlink-permission and manual real-account Drive acceptance
boundaries; they are not counted as passing acceptance checks. Logs are in ignored
`.local/file-workflow-quality-{format,format-check,analyze,tests}.log` and
`.local/file-workflow-quality-final-focused.log`.

Configured Windows release built successfully (123.2 s), retaining the registered
Google desktop client. Standalone server compiled without starting it or packaging
server keys. Standard JavaScript web release built successfully (117.0 s); existing
Google Identity Wasm dry-run and missing Cupertino font-family warnings remain.
No WebAssembly, Android, physical-device, external-application launch or real Google
account acceptance claim is made by this batch.

Ignored release logs are `.local/file-workflow-quality-{windows,web}-build.log`;
`.local/file-workflow-quality-release-verification.json` records checked runtime
files, payload freshness and all four packaged terminal font faces/hashes. Both
payloads are newer than inputs and differ from the previous Kanban build. No
app/test/server process remains running. Runnable Windows app:
`build/windows/x64/runner/Release/orbit_note.exe`; keep its runtime siblings.

| Payload | Bytes | SHA-256 |
| --- | ---: | --- |
| Windows `data/app.so` | 24,576,912 | `EB492B786261F9CEBD1B1174E453168ABD1AA835A89D468AE96BDE524832E77B` |
| Web `main.dart.js` | 10,515,923 | `80F263AF7F3E16E8C0D6DD17FA6927F8CBBFA86E5670C06B1A68B900F322420B` |

All fixture data is synthetic, in memory or in existing isolated native test
directories; personal Vaults are untouched. Unknown properties, authored source,
portable attachment bytes and unrelated changes are preserved. Automated tests
cover the listed cases; they do not establish that all hard-use bugs are gone.

## Suggested next task

Audit mixed-type bulk move/delete/restore and guarded Undo after partial failures
or later edits, using isolated Vaults. Stop here; that audit is not implemented
as part of this batch.
