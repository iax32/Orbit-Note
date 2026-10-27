# Delivered — everyday workflow polish, 2026-10-27

Owner approves the complete fourteen-area workflow-polish list: paste feedback,
PDF text choices, precise navigation, recoverable moves, reference previews,
save/sync clarity, connection tracing, remembered drawing tools, search return,
rename context, publishing checks, focus restoration, placement deletion and
large-workspace state retention. Extend existing boundaries; no new service.

Scope EDT-03/04/07, CAN, NAV, ORG, LNK, PORT and HIST interaction refinements.
Existing implemented behavior is retained and checked rather than duplicated.
Delivered behavior: [everyday workflows](../features/everyday-workflows.md).

## Behavior and recovery

- Rich/Source text and Canvas paste feedback with guarded Undo; single-block rich
  paste offers captured plain text. Existing Ctrl+Shift+V remains available.
- Native PDF keyboard/context copy remembers bounded explicit provenance; paste
  choices retain original lines, clean paragraphs or insert a page-linked quote.
  Cancel retains content and restores focus synchronously. Larger prose cleanup
  uses an isolate; external clipboard text is not assigned invented provenance.
- Bounded navigation snapshots retain distinct visits, including same-note
  references and the active tab restored at startup. Initial positions/cameras
  restore correctly; deleted targets are skipped. Restore is scoped to the
  primary target and ignores stale owner/source callbacks.
- Drop destination overlays do not shift the explorer. Object/batch/drop Undo
  rejects later changes and restores logical folders for metadata-backed objects,
  not the internal directory holding their JSON. Existing persistence commands,
  identity, relative-link rebasing and error/recovery paths remain authoritative.
- Hover/long-press reference previews show live passages, folder/status and
  scrollable large-text actions. Canonical missing references never choose a
  different same-title source; malformed targets fail visibly rather than throw.
- Save/retry and actual Drive/shared status remain separate. Local-only status
  never instantiates Google adapters or starts their polling timer. A saved opt-in
  refreshes status after the existing startup path activates sync.
- Connection tracing redraws cached geometry with emphasized markers/labels and
  endpoint outlines. It never modifies, bundles or reroutes connectors and does
  not alter exported drawings.
- Per-board tool/style/width/color/eraser settings round-trip through existing
  local session camera JSON. Default blueprint and snap settings restore on board
  switches. No authored scene mutation or new replication format.
- Search retains query/options/page/result/preview/scroll on return; incompatible
  Vault/project state is invalidated. Rename shows paths, incoming sources and
  duplicate-name warnings, with existing stale metadata guards.
- Publishing retains existing visibility/fidelity warnings and adds generated
  page/notice counts, optionally remembered successful-export settings and a
  persistent editor-design toggle. Cancel/failure does not remember settings.
  Compact/keyboard layouts scroll the action area. Origin focus returns.
- Canvas removal states that originals are retained and offers guarded Undo.
  Existing draft/failure recovery stays intact. Weak immutable-snapshot statistics
  caching avoids repeated full-note scans during view/presence updates.

## Validation

- Main integration: **98 passed**, 54 seconds, across 11 focused suites; includes
  real 30-page PDF text, a 500-paragraph Rich note, repeated cut/Undo/Redo, large
  connected Canvas transfers, read-only/pending clipboard races, split-pane focus,
  modal return, 390px/200% layouts, drawing tools and publication visibility.
  `.local/workflow-polish-final-tests.log`.
- Final sync/settings acceptance: **37 passed**, 50 seconds, including 25 Drive
  cases and overlapping workflow/native-PDF checks. Explicit opt-in, account
  changes, retry/pause/restart and transfer authority remain guarded.
  `.local/workflow-polish-final-acceptance.log`.
- Final navigation/pane acceptance after restored-tab/default-position and stale
  callback fixes: **37 passed**, 31 seconds. Counts overlap: **123 distinct checks**
  across these runs, not their sum. `.local/workflow-polish-navigation-final.log`.
- Native PDFium renders/extracts the fixture and exercises the registered keyboard
  copy handler, PDF paste choice, linked Source insertion and Undo. Clipboard
  transport in this check is mocked; no physical two-app clipboard claim.
- Measured Flutter-test CPU examples: 20,000-line PDF prose cleanup ~40–41ms;
  1,000 status reads on a 100,000-word immutable note ~34–35ms including the first
  scan; 30 tracing frames ~12–17ms without scene revision changes. These are test
  host observations, not physical-device frame-time/stylus latency guarantees.
- Actual-font captures inspected: `work/ui/workflow-connection-trace.png` and
  `work/ui/workflow-reference-preview.png`. Narrow preview includes the real
  overlay, enlarged text and visible source/actions, without overflow.
- Analyzer and strict format logs:
  `.local/workflow-polish-analyze.log`, `.local/workflow-polish-format-check.log`.
  Analyzer clean (8.3 seconds); strict format 834 files, zero changes (7.97 seconds).
- Windows release rebuilt successfully (82.9-second Flutter build) with the
  registered Google desktop configuration and compiled standalone collaboration
  server. Required EXE/AOT/Flutter/PDFium/SQLite/ICU/server artifacts verified;
  application AOT is newer than all Dart source files. Usual
  `build/windows/x64/runner/Release/orbit_note.exe` updated directly.
  `.local/workflow-polish-windows-build.log`. No server process started.

## Boundaries

No personal Vaults edited, cloud data uploaded, server started, credentials added,
dependencies installed, ZIP generated or GitHub push requested. Android SDK remains
unavailable from the previous task; no new APK or physical tablet/stylus/IME/
cross-app clipboard acceptance is claimed. Existing sync/device limitations remain.

Suggested next task: restore Android build tooling and validate these everyday
workflows on the Lenovo tablet with real touch/pen/clipboard input. Stop here.
