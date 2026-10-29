# In progress — owner-requested performance audit implementation

Scope: evaluate the supplied Gemini report against checkout 5580717 and implement
supported performance improvements across Canvas, writing, history, sync and PDFs.
No feature/visual removal, identity/schema shortcuts or weaker recovery guarantees.

Plan: preserve a pre-change synthetic ink pixel baseline; remove per-segment
allocation; index drag snapping without clipping distant alignment candidates;
cache collaboration digests; move long source-editor grammar work out of span
painting with bounded latest-result ownership; reuse the native history worker.
Then inspect PDF layout/cancellation, Drive scheduling and shell notifications,
and implement only changes supported by actual code and regression evidence.

Rejected as stated: equal revision numbers do not establish equal JSON; replacing
pressure lines with ribbons changes appearance; a 40-ms concurrent GC span is not
a 40-ms stop-the-world pause; stroke bitmap defaults cannot be assumed pixel-
equivalent to vectors and retained engine layers already exist. Preserve strict
separate UML routes rather than introducing crossings/merged lines implicitly.
Do not approximate PDF page dimensions. Existing fixture/native tools must be
checked before claiming there are no large-board performance tests.

## Implemented

- A.2: reuse stroke/grain Paint instances outside pressure segment loops. A
  pre-change synthetic PNG baseline covers all seven nibs, pressure/no pressure,
  partial segments, pencil grain and overlaps; optimized pixels match exactly.
- A.3: owned immutable ink records reuse their filtered raw sample view. Mutable
  legacy lists retain fresh views, including malformed-sample filtering.
- A.4: a per-drag index searches global edge/center coordinates and row/column
  intervals. Preserve original tie order, distant targets, screen-pixel tolerance,
  Alt bypass and live attached-connector bounds; no 500-pixel clipping or delay.
- B.2/F.1: unchanged remote-head polls run before flushAll. Device-only view
  checkpoints avoid shell notifications; preferences, save errors and recovery
  still notify. No general <1.5-ms root-layout or controller-rewrite claim.
- C.1: each open native store reuses a serial history worker. Retention still
  runs per save, retaining count/byte/age and pending-journal protections. Close
  drains accepted jobs before releasing the Vault lease. Failed worker exits
  fail the request and restart on the next request; task errors do not poison it.
- D.1: exact PDF layout memo checks every page dimension, mode and margin, with
  same-count size changes invalidating. No approximate heights or altered zoom.
- E.1: per-field grammar caches serve source/rich editors. Complete native
  analysis beyond 2048 characters is debounced 300 ms on a reusable worker,
  retaining one active/one latest request. Only matching source/dictionary results
  publish; disposed fields ignore results. Source spans follow issue boundaries.
  Web uses asynchronous local execution; no off-main web guarantee is made.
- E.2: reuse LaTeX controllers and lexical tokens for unchanged text, recoloring
  from the current theme.
- F.2: one content-keyed collaboration digest eliminates UTF-8/SHA work on caret
  changes. Same-length edits rehash; disconnect clears it.
- Identical device settings skip journal writes; unknown top-level extensions
  survive real changes. Newer settings versions still block writes.

## Corrections and deliberately unchanged behavior

| Finding | Disposition |
|---|---|
| A.1 default stroke raster flag | Complete world-group RepaintBoundaries and retained pictures already exist. The flag does not prove every vector replays every frame. Preserve vector fidelity and memory bounds; sampled bitmap equivalence is unproven. |
| A.2 triangle strips/ribbons | Different cap, grain, alpha-overlap and taper geometry. Allocation reduction preserves the original geometry. |
| B.1 full 96k-point JSON clone | snapshotJson shares immutable records; equality skips identical subtrees and added strokes fail the list-length check early. Never accept equal persisted revisions as equal content: concurrent branches can share a revision. Existing competing-draft tests remain. |
| B.2 root-layout attribution | A slow root-layout span does not attribute every stroke to it. Remove confirmed redundant settings notifications without hiding other views, sync, conflict or status changes. |
| C.2 canonical path cache | Root already resolves once. Caching security checks across external symlink changes is unsafe; repeated string joins alone do not justify it. |
| D.2 missing cancellation | Vendored _paintPagesCustom cancels off-buffer work and rejects stale document/page/epoch results. Retain those paths and native navigation checks. |
| F.1 stop sync during typing | Keep prompt, bounded synchronization and manual save guards. Optimize unchanged-head polling rather than delaying continuous edits indefinitely. |
| G.1 soft crossings/direct routes | Conflicts with owner's explicit separate, noncrossing UML lines. Impossible planar layouts need honest unresolved indicators/rearrangement. ADR-0034 explicitly documents bounded in-gesture synchronous fallback. |
| Missing large-board tests | Existing retained-scene, pen/PDF, document and commit probes cover dense boards and long strokes. None proves physical 180-Hz pen latency. |

ConcurrentMark 40.854 ms is not a measured stop-the-world pause; the observed
Scavenge span is ~2.433 ms. Older traces overlap release compilation and predate
renderer-12 history changes. Report coverage also excluded some native code;
its wording is not proof of exhaustive whole-repository QA.

## Validation

Passing focused batches: 12 worker/grammar/ink/history checks; 54 snapping/settings/
Drive/recovery/draft checks; 20 PDF/native-render/grammar checks; 60 drag/clipboard/
writing/settings integration checks. Counts overlap; no unique total is claimed.
An older test helper matched every retained Canvas painter; selecting the
interactive overlay fixes the helper and the 1000-item edge-pan/undo test passes.
Two initial snap expectations overlooked center coordinates/tie order; corrected
against prior behavior. No outstanding assertion failure. Full suite not run.

Native AOT synthetic measurements, no user Vault/account:

| Workload | Previous | Optimized |
|---|---:|---:|
| 400 two-axis alignments, 2500 items | 180.406 ms total | 0.482 ms (+4.697-ms one-time index build) |
| 100 caret digests, 264000 characters | 334.595 ms total | 3.803 ms including first hash |
| Complete 22500-character grammar analysis | 12.515 ms foreground | 12.373-ms cold / 11.558-ms repeated worker wall time |

These are isolated workloads, not FPS. Grammar remains complete; the benefit is
avoiding repeated synchronous analysis, not assuming worker wall time is faster.

Clean 100-Hz native in-memory latest-board replay at 400% zoom, no simultaneous
builds/tests: pen GPU P95 1.403 ms, long stylus 1.807 ms, long mouse 4.666 ms,
pan 2.146 ms with one 23.804-ms raster outlier. Long-stylus UI P95 .617 ms.
Drawing-stage UI/raster times stay below the probe's 10-ms budget; one pan raster
frame exceeds it. Total frame spans are separate and can exceed it. One synthetic
stroke committed, canceled strokes did not, no errors. No user Vault writer was
opened; this is not physical 180-Hz acceptance.

Analyzer clean (40.0 s), strict format 900 lib/test files unchanged (8.01 s).
Version 1.0.9+10 / renderer 13: normal Windows built in 149.0 s with registered
Google configuration and bundled server; signed Android built in 141.8 s.
Windows EXE version/AOT freshness verified. Android package
org.orbitnote.app.preview, versionCode 10/versionName 1.0.9 and original signing
certificate verified. These are local builds; no GitHub workflow was invoked.
Persistent-history AOT synthetic scan: old foreground 147.555 ms, cold/repeated
worker 118.917/118.604 ms wall; max loop gaps ~16 ms, matching coarse idle timers.
No 180-Hz claim follows from those timer results.

After owner closed Orbit, only the verified stale
diagnostic process with invalid unquoted arguments was stopped (before app
startup); the isolated probe then built and exited normally.

Next: clean owner UE2 replay through the normal shortcut, with no builds running.
The remaining pan spike and full-app acceptance remain unresolved.
