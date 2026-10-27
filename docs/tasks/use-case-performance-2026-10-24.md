# Use-case routing performance — 2026-10-24

Owner reports useful paths with minimal crossings but severe lag. Authorized
performance testing and focused regressions, explicitly excluding the full
~3,000-test suite. Scope CAN-05/07/14/15/16; preserve the accepted diagram
presentation, authored objects and existing storage/identity boundaries.

## Measured causes and changes

- Scene revision previously invalidated every route even for color, locking,
  stacking and fallback-coordinate writes on fully attached connections. Exact
  routing-input comparison now reuses derived geometry for those changes. Keys
  compare values rather than relying on collision-prone hashes.
- A drag moved nodes and rewrote each attached connector separately. Related
  writes now batch spatial-index refreshes. Queries inside a batch flush pending
  bounds; exceptions and nested batches also finish index maintenance. History
  replay uses the same batching. No durable transaction semantics are changed.
- Collision broad phase uses spatial buckets for previously routed segments;
  large segments/queries use bounded membership and conservative fallback scans.
  Exact collision predicates remain authoritative. A search memoizes undirected
  grid-edge validity across heading states, with bounded dense memory and a
  sparse fallback. Node/line clearance, side choices, search ordering and existing
  route fallbacks are preserved.
- During node movement/resizing, validated path continuation follows endpoints
  without global search for every event. It checks obstacles, self-intersections
  and newly intersecting edge pairs; invalid continuation invokes normal search.
  A fixed gesture baseline prevents accumulating corners on every move. Releasing
  or cancelling the gesture recomputes canonical geometry and hit bounds. This
  transient state is not serialized. Reopening and publication use canonical routes.

The captured cold-layout routes **and endpoint-label rectangles are identical**
before and after optimization. This task does not claim to eliminate the small
number of crossings permitted by the previously accepted fallback presentation.

## Reproducible performance evidence

`tool/use_case_routing_benchmark.dart`: isolated two-actor, six-use-case,
eleven-relationship fixture; no private Vault, account or server. Reports contain
synthetic route/label snapshots and timings. Direct SDK execution avoids unrelated
native build hooks. The initial `dart run` attempt encountered the existing
space-containing native-hook command-path issue; direct SDK execution succeeded.

| Native Dart JIT operation | Before | After |
| --- | ---: | ---: |
| Cold layout | 1097 ms | 169 ms |
| Appearance change | 1012 ms | 2 ms |
| Stacking + following read | 1019 ms | <1 ms |
| Individual canonical movement | 921–1028 ms | 48–71 ms |
| 24 interactive moves, median / p95 | not captured | 1.913 / 5.895 ms |

Same-host synthetic comparison, not a universal speedup guarantee. Logs/reports:
`.local/uml-perf-before-jit.{log,json}` and
`.local/uml-perf-localrepair-jit.{log,json}` (filename retained from investigation;
the unsuccessful local-repair experiment was removed).

`tool/use_case_device_benchmark.dart`: actual Windows Flutter **profile** build,
isolated editor, 32 synthetic mouse moves at requested 20 ms cadence. The helper
closes itself. Build succeeded in 55.6 seconds; native run exited 0 with no errors.

| Native profile measurement | Median | p95 | Maximum |
| --- | ---: | ---: | ---: |
| Pointer event handling | 1.570 ms | 2.853 ms | 69.992 ms |
| Frame build, 92 timing samples | 1.284 ms | 3.549 ms | 7.220 ms |
| Frame raster, 92 timing samples | 2.812 ms | 3.821 ms | 9.552 ms |

Release/finalization took 49.535 ms. One movement needed a full layout and retained
a ~70 ms event spike. Physical mouse/stylus latency, larger arbitrary graphs,
screen scale and refresh-rate acceptance are not established by this workload.
Event and frame times are different measurements; frame timing alone does not
prove input responsiveness. Report `.local/uml-perf-native-device.json`, build
log `.local/uml-perf-profile-build.log`.

The real widget gesture regression separately exercises selection/drag/release;
its debug test timing includes test dispatch/pumping and is not a shipping FPS
measurement (`.local/uml-perf-widget-drag.json`).

## Focused verification and delivery

**88 focused tests passed in 17 seconds**, including five new cache/batch/gesture
regressions, existing route/label, UML, Canvas engine/performance, copy/cut,
multi-touch cancellation and external-revision tests. Full suite intentionally
not run. Final log `.local/uml-perf-final-tests.log`. Initial new-test harness
errors (mixed relative/package imports and camera argument type) were corrected.
Intermediate preview-splice errors were found by measurements and corrected
before this passing batch; temporary diagnostics were removed.

Final analyzer clean (82.4 seconds); format/strict clean across 764 lib/test files,
plus the two benchmark tools. Configured Windows app and matching standalone
server built successfully (90.8-second Windows compile). All 910 frozen inputs
in `.local/uml-perf-final-inputs.json` unchanged through validation/build. Seven
runtime/server files, the regular app PDF control and absence of the synthetic
profiler entrypoint in release AOT verified. Run
`build/windows/x64/runner/Release/orbit_note.exe` with its sibling files.
Build log: `.local/uml-perf-final-windows-20261024.log`. No Android/web rebuild,
GitHub publication, personal Vault/account access, main-app/server launch or ZIP.
The isolated profiler was the only app launched and closed itself.

Suggested next task: profile the remaining occasional full-layout event spikes
on a larger real-world diagram, using an anonymized reproduction.
