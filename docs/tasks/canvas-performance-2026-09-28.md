# Canvas performance — 2026-09-28

Request: significantly improve performance without removing features, animation,
or visual detail. Scope: existing CAN-01/03/07/11/14 behavior; no new features.

## Changes

- Scene edits use a reverse connector-reference index instead of scanning the
  whole board for each moved item. Hidden connectors, missing endpoints,
  retargeting, deletion, cancellation and undo/redo share the same mutation path.
- Content bounds are computed once per scene revision, rather than once per
  minimap layout, camera move or fit request. Empty bounds are cached too.
- Canvas rich text parsing is reused by drawing and checkbox hit testing. Cache
  keys are the complete content; edits cannot reuse stale parsing. Retention is
  limited to 256 entries and 262,144 source characters; oversized content still
  renders normally without being retained. Disposal clears the cache.
- The minimap retains one vector display list per editor. Its viewport indicator
  continues to update on every camera frame. Scene revision, layout, colors and
  exact search membership invalidate the display list; replacement and editor
  disposal release it. No raster downsampling or animation changes.
- Minimap repaint decisions capture the scene revision at painter creation,
  fixing missed repaints when the shared scene mutates in place.

## Measurements

Local Windows development CPU microbenchmarks, synthetic rectangular boards with
one attached connector. Same workload before/after; JIT/debug results, not release
frame timings or whole-app speedup claims. See
`tool/canvas_performance_benchmark.dart` and the informational minimap test.

| Workload | Before | After |
|---|---:|---:|
| 10,000 elements, 300 connected-item moves | 272.328 ms | 2.879 ms |
| 100,000 elements, 300 connected-item moves | 3143.686 ms | 2.723 ms |
| 10,000 elements, 100 content-bounds reads | 690.374 ms | 6.319 ms |
| 100,000 elements, 100 content-bounds reads | 6825.930 ms | 60.308 ms |
| 10,000 elements, 60 minimap pan recordings | 2130.975 ms | 147.921 ms |

Bounds measurements include the first uncached read. Minimap measurement includes
the first display-list recording. Neither measures GPU raster work; a fully
visible dense board and edits that invalidate the minimap still have rendering
cost. The 100,000-element benchmark is a CPU stress fixture, not a supported
interactive-capacity claim.

## Validation

- Five targeted regression tests pass: fresh-load equivalence through connector
  mutations/undo/redo, bounds invalidation, exact rich-card pixel equality, exact
  cached/uncached minimap pixels through pan/edit/theme/search, and recording cost.
- Earlier combined canvas run: 28 tests passed.
- Follow-up full suite: 1,006 passed on 2026-09-30; analyzer and formatting clean.
  Normal Windows release built (59.1s) and launched. Native sample board inspected
  with reference card and sticky notes. See the coherence task for overall review.

Existing LaTeX metadata and workspace failures were investigated in the coherence
pass rather than silently treated as passing. Synthetic benchmarks do not replace
end-to-end profiling on a representative real board.

Next suggested task: profile end-to-end canvas frame timing and allocation on a
representative mixed notes/images/ink board to identify the next measured limit.
