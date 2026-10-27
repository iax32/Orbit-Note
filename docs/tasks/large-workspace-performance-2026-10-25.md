# Large-workspace stability/performance — 2026-10-25

Owner requests closing load/recalculation spikes across notes, Canvas, PDF and
large Vaults, including the previous ~70-ms diagram input spike. Scope existing
CAN-05/07/14/15/16, EDT-03/04, FILE-04/05/11/12/13, LNK-01 and storage invariants.
Preserve visuals, features, canonical knowledge, unknown fields and unrelated
sync changes. No full ~3,000-test suite or personal-Vault mutations.

## Changes

- Routing uses bounded dense score/parent storage with sparse fallback, packed
  heap costs, axis-band obstacle candidates, nested integer traffic buckets and
  sound rejection of blocked endpoint candidates. Existing collision rules,
  ordering, search limits and canonical geometry remain. Interactive checks reuse
  extracted path arrays instead of repeatedly allocating the same point lists.
- Larger use-case diagrams prepare canonical geometry in a worker before exposing
  the Canvas. On release a validated preview remains until the worker result can
  atomically replace its derived bounds. Stale jobs cannot replace newer geometry,
  styles or another Canvas; removal/hiding retires pending work. No authored save
  or undo entry is emitted for derived geometry. See [ADR-0034](../adr/0034-derived-routing-workers.md).
- Refresh reuses immutable objects/sources when the owning file hash/path match.
  Updating one note therefore no longer re-creates every unchanged PDF/Canvas/note
  object and invalidates their downstream caches. Search updates only changed/new
  objects; removal still rebuilds the index to eliminate stale results.
- Native search rebuild sends bounded 64-row batches through the existing single
  transaction instead of one background-database round-trip per row. Memory
  indexing stages complete maps, yields cooperatively and serializes writes;
  rebuild failure preserves old results and cannot lose queued updates.
- Markdown reuses stripped LF/CRLF line text while parsing and one retained-block
  set during rich-editor reload. Authored endings/source and selection survive.
- Mixed-workspace testing found an uncancellable delayed PDF page-load job.
  Document changes/disposal now cancel its timer; running callbacks retain their
  captured document/generation. Native render flags, DPI and source bytes stay.

## Data/workloads and privacy

Read-only structural inventory found 14 immediate Desktop Vaults. The largest
canonical subtree contained about 540 MiB of assets, but none was a large-note
stress corpus. Inventory did not open repositories, run recovery/sync, or change
their files. Only anonymous counts/sizes were reported. One existing diagram's
geometry (21 elements, 12 relationships) was copied with names, text, identifiers,
references and paths removed; it stays in ignored `.local/` only.

Do not call this a full private-Vault acceptance pass. Stress tests deliberately
exceed the available note counts: 1,000 native note files, 3,000 indexed objects,
6,603 Markdown blocks, a 10,000-item Canvas, 100,000 ink samples and a real native
300-page PDF. One test mounts a 2,000-paragraph editable note, 10,000 Canvas items
and a 300-page PDF with 3,000 highlights together; edits, pan, distant navigation,
annotation changes and close retain content and load the PDF bytes only once.

## Measurements

Same Windows host, informative timings rather than hardware-independent gates.
Debug fixture timings must not be presented as release FPS.

| Workload | Before | After |
|---|---:|---:|
| 3,000-object native index rebuild | 867 ms | 298–303 ms |
| Synthetic native AOT cold routing | 61 ms | about 35–40 ms |
| Synthetic native AOT canonical moves | 49–82 ms | about 29–51 ms |
| 1,000 native notes cold reopen | 1,192 ms | 1,243–1,270 ms |

Cold file reopening itself is not claimed faster; avoiding downstream re-decoding,
identity churn and index rewrites is the warm-refresh improvement. The fixture
checks every original file, unknown fields, Unicode and newline preservation;
unchanged refresh keeps all object identities and performs no index writes.
One changed source triggers one upsert; a removed file triggers full replacement.

Reference AOT route **and endpoint-label snapshots match exactly** at the captured
initial/final positions. Computation is still real work, not eliminated by a worker.
The anonymized diagram needs around 100–114 ms for full native canonical routing;
ordinary interactive continuation is sub-millisecond in its pure engine fixture.

Native Windows Flutter profile, 32 pointer moves per fixture:

| Interactive workload | Synthetic diagram | Anonymized existing diagram |
|---|---:|---:|
| Pointer event p95 | 2.417 ms | 1.524 ms |
| Worst pointer event | 44.813 ms | 2.687 ms |
| Pointer release/finalization | 0.799 ms | 0.352 ms |
| Frame build p95 | 3.962 ms | 4.299 ms |
| Frame raster p95 | 4.350 ms | 3.969 ms |

Both native runs reported zero errors. The earlier same-task synthetic release
handler took 43.508 ms before worker finalization. The previous task's comparable
full-layout event was 69.992 ms. Typical interaction is faster, but the synthetic
fallback still causes one 44.813-ms input spike. Initial raster reached 163.428 ms
synthetic / 74.549 ms anonymized; these cold GPU/shader costs are not solved or
hidden by the steady-state figures. Worker preparation preserves exact geometry
but does not remove computational cost. This is a delivered improvement, not
closure of every possible load/recalculation spike.

## Validation and delivery

The focused combined run passed **160 tests in 83 seconds** before the last
ignored-future-routing-metadata regression. Includes actual PDFium, SQLite
transaction rollback/reopen, duplicate identities/recovery, long notes, source
selection, seeded Canvas histories, progressive page/render/cache failures,
PDF review deletion, shared reconnect and scheduled-sync boundaries.

Additional worker regressions exercise real isolates, stale geometry/active
drag, later appearance preservation, link removal and cold Canvas replacement.
The worker test's event loop continued ticking while canonical computation ran.
The new PDF regression closes/switches viewers with an hour-long deferred load
without leaving a timer or starting obsolete native work.

The final routing/compatibility group passed **21 tests in 3 seconds**, including
ignored future JSON values across isolate boundaries. Combined runs overlap and
must not be summed into a unique-test count.

Strict formatting passed across 776 app/test/tool/vendor files. Root Flutter
analysis passed without issues (45.8 sec); the modified vendored PDF viewer also
passed independent Dart analysis. Local evidence uses `.local/large-*.log/json`;
the anonymized private-layout fixture is not committed or published.

The normal Windows release built successfully (93.1-second Windows compile),
including the matching standalone collaboration server and existing registered
Google preview configuration. Verified `lib/main.dart` as the target, required
runtime/PDFium/SQLite/AOT/server files and absence of the profiler marker in
release AOT. Updated `build/windows/x64/runner/Release/data/app.so`; the unchanged
native runner EXE can retain its prior timestamp. Open the usual
`build/windows/x64/runner/Release/orbit_note.exe` with its sibling files present.
No personal-Vault main-app launch, server launch, archive or publication.

Suggested next task: reduce the remaining invalid-preview synchronous routing
fallback and cold first-raster spikes. Stop before implementing it.

No physical stylus/mobile acceptance, 100,000-item visible Canvas capacity, arbitrary
giant graph latency, real personal-account sync or universal zero-bug guarantee
is established by these tests. Existing fallback crossings are not redesigned.
