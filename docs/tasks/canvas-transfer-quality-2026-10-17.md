# Canvas selection, drop and clipboard quality

Status: completed and validated 2026-10-18. Owner approved the proposed quality batch. Scope:
CAN-05/06/08/14, DES-01/03/05/06 and existing cross-editor media behavior.
Preserve the completed editor/PDF/publishing work and unrelated changes.

Plan: reproduce failures in board ownership, cut/paste, ink geometry/metadata,
cancelled/read-only gestures and drop coordinates. Inspect cross-editor image
and unsupported-shape conversion. Use the existing scene, commands, adapters,
universal object identities and undo boundaries; no schema or package changes.
Fix observed failures, cover pointer/keyboard/failure/narrow layouts and native
storage round-trips, then format/analyze/full tests and configured Windows/web
builds. Report actual evidence and any unavailable hardware clipboard checks.

No desktop-control testing, personal Vault changes, remote account actions or
shutdown. Suggest one next task and stop after this scoped batch.

Resumed 2026-10-18 after the interrupted session; continue the same changes.

## Implemented

- Interaction epochs and scene identity prevent stale cuts, pastes, reference
  pickers, menus and prepared drops from reviving after board/read-only changes.
  Newer clipboard requests supersede older work; ordinary missing drag sources
  refuse broken placements. Imported attachment ownership stays with the existing
  repository boundary, with no automatic source deletion.
- Gesture rollback restores provisional geometry and prior selection. Two-finger
  handoff cancels an element drag before navigation; cancellation restores the
  handoff camera. Read-only/external scene revisions cannot leave provisional
  transforms to leak into a later save. Placement commands settle a live pointer
  gesture before starting their own undo operation; active-gesture undo/redo
  cancels that gesture first. Inline text also respects read-only/locked items.
- Ink paste/duplicate changes its placement origin once, preserving local points
  and pressure/time/unknown metadata. Existing connector world endpoints still
  translate/remap normally; no format migration occurs. Align/distribute uses the
  same local-sample rule. Alignment menu labels wrap within the popup, including
  at 390px and 200% text. Selection status also wraps within the viewport instead
  of extending beyond its right edge.
- Text/image paste captures its world position before asynchronous reads.
  Context Paste uses the chosen empty-space position. Image results also validate
  source/dimensions and preserve selection on stale/invalid completion.
- Rich/Source Markdown conversion refuses partial/lossy drawing conversions,
  including labelled shapes. Unsupported drawing selections retain their entire
  literal payload for a lossless return to Canvas. Supported images/object/text
  transfers and explicit live-diagram embedding keep their existing behavior.

## Evidence

Original regressions are recorded in `.local/canvas-transfer-repro.log`.
The focused existing Canvas/clipboard/import batch passed **115 tests** before
the final touch/bridge additions. The new file `test/canvas_transfer_quality_test.dart`
now has **31 behavior tests**, including actual Canvas cut → Rich/Source
→ Canvas and native saved/reopened JSON with unknown ink/scene fields preserved.
Pointer fixtures pump pending gesture-recognition timers explicitly; notices are
checked after an earlier snackbar expires rather than hiding that UI behavior.

The first full run caught a conflict-recovery regression: cancelling every
external revision discarded a guarded editor's competing gesture. Guarded
editors now retain the gesture for the existing draft-conflict command; shared
data remains authoritative and the local draft can be recovered or discarded.
The existing `course_hub_and_drafts_test.dart` regression passes again. The final
focused run passed **48 tests** before the extra narrow-menu test, which also
passed separately. `.local/canvas-align-repro.log` records the ink alignment
metadata loss and overflowing distribution menu labels before their fixes.

Headless captures at `work/ui/canvas-transfer-large-text.png` and
`work/ui/canvas-align-large-text.png` verify 390px/200% layouts. Their first visual
review exposed clipped selection-status text despite no RenderFlex exception.
The status now has a bounded, naturally sized layout and an explicit on-screen
geometry assertion. A clean partial suite was intentionally interrupted for
that fix (`.local/canvas-transfer-tests-interrupted-for-layout.log`); the complete
suite is rerun after the final source change. Both large-text capture tests pass.

Final checks on 2026-10-18:

- `dart format lib test` and strict format check: **666 files, clean**.
- `flutter analyze --no-pub`: **no issues**.
- `flutter test --no-pub --concurrency=6 --reporter expanded`: **2,451 passed**,
  **2 existing skips**, in 4m19s. The skips remain native symlink creation without
  OS permission and manual Google account consent/synthetic-upload acceptance.
  Logs: `.local/canvas-transfer-format.log`, `canvas-transfer-format-check.log`,
  `canvas-transfer-analyze.log`, `canvas-transfer-tests.log`.
- Both 390px/200% headless visual checks pass, with on-screen status geometry.
  `.local/canvas-transfer-visual.log` and the two captures above record the result.

- `tool/build_windows.ps1` with the existing ignored Google registration:
  **passed**, Windows compilation 127.1s. Standalone server rebuilt successfully;
  no server was started and no keys were packaged.
- `flutter build web --release --no-pub`: **passed**, standard JavaScript release
  in 118.6s. Existing Google Identity interop Wasm dry-run incompatibility and
  missing Cupertino font-family warnings remain; no Wasm acceptance is claimed.
- Required Windows EXE/DLLs, assets, Dart payload and collaboration launcher/server
  are present and nonempty. Both compiled payloads are newer than the latest Dart
  source. `.local/canvas-transfer-release-verification.log` records file sizes,
  timestamps and SHA-256 hashes. Windows `data/app.so`: **24,560,528 bytes**,
  `7FD6C9993567D0C2E7556F656605D0B5857800B193A501C9396A6EA4DD897D8D`.
  Web `main.dart.js`: **10,502,546 bytes**,
  `2BA566C062D9480D2215149C933995EC49AB3F044394A925918F9414ECC6B8B1`.
  The app/server/test processes were not left running. Scoped `git diff --check`
  passed (only existing CRLF-to-LF normalization notices).

Runnable Windows app: `build/windows/x64/runner/Release/orbit_note.exe`, with its
adjacent runtime files. No archive is needed. No personal Vault was opened or
modified. No physical/external-app clipboard, stylus, live Google-account or
two-device acceptance is claimed, and no desktop-control testing was used.

Suggested next task: Canvas connector routing and UML editing quality audit.
Stop here; do not begin that next task without approval.
