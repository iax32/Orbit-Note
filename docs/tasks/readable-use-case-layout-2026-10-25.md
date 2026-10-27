# Readable use-case diagrams — 2026-10-25

Owner reports hard-to-follow detours, shared-looking lines and unnecessary bends
behind use cases. Requests an explicit organize button, independent lines and
clear multiplicities. Scope CAN-05/07/14/15/16; existing spatial engine/history,
no new data format, service, dependency or personal-Vault mutation.

## Delivered behavior

- Score short straight/elbow/dogleg paths on all endpoint sides before bounded
  grid search; include length, bends and side preference. Do not accept the first
  reachable back-side attachment while a shorter clear front-side path exists.
- Remove the emergency route that ignored existing relationship traffic and
  could merge/cross lines after six failed ordering attempts. No-route warnings
  preserve/select the relationship; moving or organizing nodes can resolve it.
- While dragging, retain safe paths and repair only invalid continuations with
  simple separated candidates. A blocked relation does not trigger repeated full
  graph searches. Unresolved previews remain explicit until canonical worker
  completion on release. No provisional path is stored as authored knowledge.
- Toolbar **Organize use-case diagram** scopes to selected connected components,
  or all when selection is empty. Pair related cases, space them vertically,
  flank with actors, avoid unrelated placements and retain locks. Expand containing
  unlocked system boundaries. Preserve notation, source references, IDs, styles,
  unknown data, manual routing and fixed anchors. Translate endpoint fallbacks.
- Apply all edits through one history command and fit the camera to the result.
  Keyboard focus returns to Canvas so Ctrl+Z immediately restores positions.

## Evidence

Seven new targeted tests cover organization, separate paths/no touch or crossings,
front-side preference, blocked route recovery, boundary/lock behavior, canonical
reopen, idempotence, metadata, selection scope, actual button emission and keyboard
undo. Existing routing tests exercise numbers/label hit bounds and SVG parity.
Light/dark actual-font renderer previews were generated and visually inspected
in ignored `.local/uml-organized-preview/`; no screenshot is a durable embed.

Final combined run: **80 tests passed in 14 seconds**, including Canvas cache/large
board regression cases, connectors/classes/interaction notation, rich/read note
embeds, publication snapshots, form layout, clipboard and keyboard history.
Blocked-route tests verify warning selection/index bounds, recovery after moving
the obstacle, no phantom straight-line hit and SVG containing the warning rather
than a path. Canvas and SVG explicitly suppress the invalid straight fallback.
Strict formatting passed across 777 app/test/tool files. Root analysis passed
without issues (77.7 sec); final benchmark-only adjustment also analyzed cleanly.

Native pure-Dart AOT, same Windows host (not Flutter frame-time claims):

| Workload | Result |
|---|---:|
| Synthetic 11-link cold canonical routing | 13 ms |
| Synthetic 24 input continuations p50 / p95 | 1.016 / 1.325 ms |
| Anonymized existing 12-link cold canonical routing | 163 ms |
| Existing layout input continuations p50 / p95 | 0.678 / 1.094 ms |
| Organize existing layout, including route rebuild | 7 ms |
| Organized existing layout blocked relationships | 0 of 12 |
| Organized existing layout canonical moves | 7–8 ms |
| Organized existing layout input p50 / p95 | 0.626 / 0.945 ms |

Native Windows Flutter profile (32 real pointer samples, no personal Vault):

| UI measurement | Synthetic | Anonymized existing layout |
|---|---:|---:|
| Pointer event p95 / max | 2.474 / 3.082 ms | 1.001 / 1.205 ms |
| Release event | 0.591 ms | 0.301 ms |
| Frame build p95 | 5.133 ms | 3.114 ms |
| Frame raster p95 | 4.746 ms | 3.224 ms |
| Recorded errors | 0 | 0 |

The native harness verifies the actor actually moved, not a nearby connector.
Smart alignment guides remain active. Its first exact-offset guard expected
32/16 and rejected a valid snapped drag; corrected to record displacement and
require actual movement (27/15 and ~29.38/19.51). These final measurements use the
corrected harness. Earlier unguarded pointer numbers are not acceptance evidence.

The unorganized existing fixture has two unresolved routes under hard separation;
organization resolves both. Cold canonical work is still real computation and
may be slower when insisting on separation; native editor preparation/release
uses the previously introduced worker. Export/plain scene callers remain
synchronous. No claim of zero latency for arbitrary graphs or web execution.

Evidence files: `.local/uml-readable-*.log/json`,
`.local/uml-readable-organized-native.json`. The anonymized geometry fixture stays
ignored; no source personal Vault is changed or published.

## Limits

The organizer is a deterministic heuristic, not a global optimum or proof of
planarity. More than two actors, nonplanar topology, locks/overlaps and explicit
manual lines can require user adjustment. A transient unresolved marker during
drag is preferable to a misleading crossing/merged line. There is no new
collaboration merge policy; organization is an ordinary recoverable placement
command. No architecture change beyond the existing derived routing worker.

Normal configured Windows release and matching standalone server built
successfully (97.9-second Windows compile). Verified ordinary `lib/main.dart`,
required runtime/PDFium/SQLite/AOT/server files, both new feature strings and no
profiler marker in release AOT. Run the existing
`build/windows/x64/runner/Release/orbit_note.exe` with its sibling files present;
the native runner timestamp may remain unchanged because Dart code is in the
new `data/app.so`. No archive is required.

No full-suite run, personal-Vault launch, Google upload, server launch or GitHub
publication. Suggested next task: arrangement alternatives for many-actor
diagrams, without changing the independently routed relationship contract.
