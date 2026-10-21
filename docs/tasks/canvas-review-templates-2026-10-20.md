# Shared Canvas review and everyday templates

Status: validated, 2026-10-20. Scope: SYNC-05/12 placement-level conflict review;
EDT-09, CAP-07 and CAN-15/17 reusable writing and spatial starters.

## Plan

1. Review overlapping placements against the known common base, keeping automatic
   independent merges. Explicitly choose local/shared placement versions, deletions
   and stacking order. Preserve unknown fields, canonical object references and
   normal file history; refuse stale reviews and failed saves.
2. Expand the note library across ideas, journals, outdoors, nature, AI, learning,
   work and daily life. Add categories and usable narrow-screen previews. Add
   editable mind-map, idea exploration, reflection, outdoor and AI Canvas starters
   using the existing scene engine and undo boundary.
3. Test domain merges, isolated shared clients, history/failure boundaries,
   template creation/search and compact/enlarged layouts. Run formatting, analysis
   and the full test suite; rebuild configured local Windows/server and web outputs.

Preserve previous uncommitted work. No desktop control, personal Vaults, real
cloud operations, publication, shutdown or new dependencies. This does not add
CRDT editing, automatic AI execution or new-object/attachment streaming.

## Validation

Implemented placement-by-placement local/shared choices, explicit placement
removal and stacking-order review, immutable comparisons and live canonical
object labels. The existing merge still combines independent edits. A resolution
uses ordinary local save/history before normal known-base publication. Stale
local/server/session state refuses application; a remote edit during the save
creates a new review conflict. Failed saves and lost acknowledgements retain
recoverable local work and use the existing retry boundary. Unknown common bases
after reconnect and unsupported document-level conflicts are not guessed away.

Added 26 Markdown starters with title/date materialization, nine searchable
categories and compact browse/details layouts; existing specialized setup remains.
Added eight Canvas starters with previews from the shared vector renderer, fresh
placement IDs, endpoint-bound connectors, append-beside placement, selection/fit
and one insertion undo. Read-only/stale dialog callbacks refuse insertion;
consumed presets do not repopulate deliberately emptied boards.

- Final focused matrix: **90 passed**, including the previous collaboration,
  Canvas, template, model asset, technical article and enlarged-panel workflows.
- New regressions: **29** across domain review, two isolated local clients, native
  save/reopen/history, write failure, lost acknowledgement and a gated save race;
  template materialization/catalog/search, ordinary Markdown persistence, fresh
  Canvas IDs/connectors/undo, consumed presets, stale permission callbacks and
  compact/enlarged note/Canvas/review dialogs.
- `dart format lib test` and strict formatting: **701 files**, clean.
- `flutter analyze --no-pub`: **no issues**, 8.5 seconds.
- Final full suite: **2,684 passed**, **2 existing skips**, 4m52s. Existing skips
  cover Windows symlink privilege and explicit manual Google consent/upload.
  The configured Python IDE runtime was supplied; no additional IDE skips.
- Configured Windows app: release build passed, 82.2 seconds. The registered
  desktop Google client configuration was preserved. Standalone server compiled
  and packaged with its launcher; no server was started or key packaged.
- Standard JavaScript web release: passed, 91.2 seconds. Existing Google SDK Wasm
  dry-run incompatibilities and missing Cupertino font-family warning remain;
  no Wasm acceptance or new platform certification is claimed.

The first layout pass exposed a compact/enlarged note library consuming its list
space in the fixed header. A shared scroll surface keeps the header, list and
details reachable while footer actions remain available. Test scrolling now
waits for the new layout before tapping; no desktop-control acceptance is claimed.

The first full run reported 2,682 passes, two existing skips and two failures:
the additional toolbar button pushed Layers beyond the initial 1,000-pixel
viewport in existing 2.5× text tests. Moving the new action after Layers keeps
the established control reachable. Both existing cases pass unchanged in the
final focused matrix and the clean full rerun. The initial log is kept in
`.local/canvas-review-full-initial.log`; final results are in
`.local/canvas-review-full.log`. No test was weakened or skipped for the regression.

## Release verification

Verified at **2026-10-20T22:43:10+02:00**. Runtime EXE/DLLs, PDFium, SQLite,
ICU, server and launcher are present. Windows/web payloads are newer than source
inputs and differ from the previous build. All four OrbitTerminal font faces
match their source hashes in both outputs. No app/test/server process remains.

| Payload | Bytes | SHA-256 |
| --- | ---: | --- |
| Windows `data/app.so` | 24,740,752 | `D7AD4DC1F5211C922E64E8AE2DF9A20B5C9B99D8674F98E6D4B71872BB40491B` |
| Web `main.dart.js` | 10,590,137 | `04815F6A056C03003D178D4BB9712926C0075DE42493A6BCBE69D4AE58612901` |
| `OrbitNote-Server.exe` | 7,595,520 | `EE24265F4902F154CE117C70878C49B165A08D33864C30AC324C896069367728` |

Runnable Windows output: `build/windows/x64/runner/Release/orbit_note.exe`, with
its runtime siblings. Reports: `.local/canvas-review-release-verification.json`
and `.local/canvas-review-server-verification.json`. Strict formatting and
`git diff --check` are clean. Earlier uncommitted work remains intact.

## Limits and next task

Placement review requires a known common base from the active shared session;
reconnect-only divergence and document metadata conflicts keep the existing
recovery/adopt flow. This is not persistent CRDT collaboration or live streaming
of new objects/attachments. Templates are editable local starters, not automatic
AI execution or new journal/course/scheduling engines. Native/headless fixtures
do not replace physical-device, TLS deployment or real-account acceptance.
GitHub packages/APK were not republished by this local task.

Suggested next task: save personal notes and Canvas layouts as reusable templates.
Stop before implementing it.
