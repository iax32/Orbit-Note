# High-degree UML actor routing — 2026-10-25

Owner cancelled PDF insertion because it was completed manually. New request:
the pictured coffee-machine diagram produces many route-warning boxes; support
many independent connections reliably and legibly. Scope CAN-05/07/14/15/16.
No mouse/desktop takeover and no edits to the personal Canvas or original PDF.

## Root causes and changes

- A fixed terminal clearance consumed the small actor's attachment region after
  a handful of incident lines. Left/right groups also reused body positions.
  High-degree actors now have globally unique body tips and side-specific,
  ordered escape stems. Future stems are reserved before greedy path selection,
  preventing early routes from trapping later ones. Stems remain separate.
- Fixed escape boxes overlapped nearby cases despite a visibly free association.
  Dense actor associations can use direct paths with outward perimeter-normal
  checks; other node interiors and line crossings remain hard exclusions.
  Narrow separation applies to one shared actor fan; unrelated traffic retains
  its corridor clearance. Low-degree actors retain their previous strategy.
- Uniform 12-unit node margins closed narrow gutters. Adaptive margins use the
  actual neighboring gap. Above 256 obstacles, the shared spatial index queries
  local neighbors with a bounded candidate budget, prioritizing UML nodes. This
  keeps narrow gutters usable when unrelated objects are added without an
  unbounded all-pairs pass; unexamined crowded neighborhoods stay conservative.
- Grid coordinates skipped narrow wedges between diagonal fan stems. Dense
  routes add finer coordinates while ordinary routes retain their coarser grid
  and bounded search. Segment indexing now uses supercover grid traversal with
  corner-neighbor coverage, plus the existing bounded large-segment fallback.
- Direct two-point previews were not updating their endpoints during movement.
  They now track allocated ports; ellipse-normal validation prevents an old
  attachment from cutting back through its own case. Undo/reopen and worker
  results remain canonical and source-bound.
- Port/actor-tip/peer allocations are cached per immutable layout input. Label
  collision checks use a shared spatial segment index. Preview labels project
  onto the new path and are reused only after collision checks. Search stops at
  the first valid position and can follow a long branch when necessary. Compact
  numeric badges preserve text without the old unnecessary 36-unit minimum.
- Genuine no-route markers are still available; their height increased from
  36 to 44 so the second instruction line is not clipped.

All changes are derived geometry/presentation. No schema migration, universal
identity change, manual-path rewrite, personal-Vault mutation, external service
or new dependency. Existing background workers remain the computation boundary.

## Coverage

Read only one current personal board (32 elements, 16 relationships). Copied only
its geometry/notation into ignored `.local/coffee-routing-fixture.json`, replacing
IDs/text and removing object references. Original file and PDF were not edited.
The baseline resolved only 7 of 16 connections; **9 warnings**. Final AOT checks
resolve **all 16**, both initially and after repeated actor moves, without changing
the authored layout. No organizing action or source-file migration is required.

Portable fixtures also cover a synthetic 16-link coffee topology, four small
actor nudges, 12/24/48/64 associations on one or both sides, independent segment
geometry, no crossing/touch/shared trunk, raw node-interior avoidance, numeric
badge non-overlap, source retention, canonical reopen, real isolates, undo,
missing targets, and a manual diagonal crossing grid-cell corners. Actual-font
light/dark previews are in ignored `.local/coffee-routing-preview/`.

Combined regression run: **106 tests passed in 28 seconds**. Final routing group
after the unrelated-traffic clearance refinement: **42 tests passed in 14 seconds**
(overlapping coverage, not additive). The manual-diagonal test was also rerun
after correcting its fixture so that it really crosses the actor's path.
An additional coffee-topology + 600-unrelated-placement test covers the bounded
large-board neighbor search without disabling narrow-gutter routing.
The final **15 capacity tests passed in 15 seconds**, including all prior fan
sizes, real-font previews, small nudges, missing endpoints and the coffee layout
with 600 unrelated objects. Final root analysis passed without issues (10.3 sec);
strict formatting passed across 779 app/test/tool files.

## Native Windows measurements

Hidden isolated Flutter profile process, 32 pointer moves per fixture, verified
actual actor displacement and canonical completion. No personal Vault/account,
physical cursor movement or server. Smart guides remain active.

| Workload | Input p95 / maximum | Release | Build p95 | Raster p95 | Errors |
|---|---:|---:|---:|---:|---:|
| Anonymized current coffee layout | 2.185 / 2.272 ms | 0.382 ms | 4.002 ms | 4.794 ms | 0 |
| Portable coffee fixture with counts | 2.829 / 3.907 ms | 0.894 ms | 5.566 ms | 5.478 ms | 0 |
| 64 numbered associations | 29.976 / 33.163 ms | 1.330 ms | 4.900 ms | 4.926 ms | 0 |

Native evidence predates only the large-board neighbor-search guard, which does
not change the margin results for these <=65-node workloads. Pure AOT checks cover both initial/final
routes. CPU-heavy canonical work remains off the native UI thread in the editor;
plain scene constructors/exports are synchronous. Do not call debug-test timings
or raw canonical work frame-rate guarantees.

## Limits and delivery

This is not a global-optimum or arbitrary-planarity solver. Nonplanar graphs,
overlapping/locked nodes, manual barriers, enormous labels and extreme scales
can still need arrangement or a genuine warning. Very dense fans have tightly
spaced stems near the actor and can move numbers farther along the branch.
The measured 64-numbered-link input cost is still above a 16.7-ms frame budget;
zero latency or perfect physical separation at every zoom is not claimed.

Normal configured Windows release and matching standalone server built
successfully (92.0-second Windows compile). Verified `lib/main.dart`, required
runtime/PDFium/SQLite/AOT/server files, prior feature controls, no profiler marker,
and release AOT newer than both modified routing sources. Run the usual
`build/windows/x64/runner/Release/orbit_note.exe` with its sibling files present;
the Dart update is in `data/app.so`, so the native runner timestamp may stay old.
Local evidence:
`.local/high-degree-*.log/json`, `.local/coffee-routing-*.json` and
`.local/*-fixture-native-ui.json`. No full test-suite run, personal-app launch,
archive, Google transfer, server launch or GitHub publication.

Suggested next task: move the remaining extreme-fan label work out of the pointer
path while preserving source-bound selection and label fidelity. Stop before it.
