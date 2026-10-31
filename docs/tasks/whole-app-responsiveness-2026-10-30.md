# Whole-app frame responsiveness — 2026-10-30

Owner reports pervasive lag after 1.0.17 and authorizes measured implementation,
local Windows/Android builds and publication. Preserve every feature, authored
sample, theme/animation, editable vector, rendering quality, unknown field and
save/recovery guarantee. No personal Vault stress, networking feature work or
multiplayer acceptance. `tmp/` is unrelated personal content and stays untouched.

## Investigation and implementation

Native profile mode runs the actual `OrbitNoteApp`/workspace shell/controller and
repository, with offline account adapters and isolated synthetic ordinary files
in memory. The expanded `tool/workspace_frame_profile.dart` reuses existing native
pointer/frame helpers and the existing generated 300-page PDF. It exercises cold
10,000-file opening; a 2,000-paragraph note with external edits and visible-field
typing; 10,000 Canvas shapes plus 100,000 saved pressure samples; short and long
stylus/mouse strokes, saves and pans; PDF loading/scrolling/drawing; split panes;
Explorer scrolling/filtering; settings/tabs and 150 repeated navigation cycles.
Counts/timings/memory only; no personal text, coordinates, paths or credentials
are written to reports. Native injected input is not physical-device acceptance.

Initial actual-shell baseline (10,002 controller objects) showed UI p95 ~132 ms
for status notifications and ~162 ms for external note edits while raster was
~2 ms. Making Explorer controls lazy reduced status UI p95 to ~95 ms; this was
an intermediate result, not completion. CPU sampling then identified repeated
folder normalization, duplicate full-Vault sorting and per-item provider reads.
Later sampling identified remaining folder sorts and whole-note reparsing for
external replacement. The calendar was inspected but was collapsed during these
profiles; it was not falsely attributed as the measured primary bottleneck.

Implemented through existing boundaries:

- Build Explorer menus/tooltips/drag controls only for viewport rows; retain
  complete ordered keyboard/selection metadata and existing row content.
- Sort each folder once, use view-local exact incremental ordering for small
  object edits, and resolve the controller once outside per-object loops.
- Cache folder resolution against its exact owning path/folder metadata, prune
  permanently removed owners and clear it at repository initialization.
- Reuse known-folder derivations until object/folder-root snapshots change.
- Synchronize PDF sources only when the owned immutable object snapshot or
  indexer changes; set guards before reentrant progress callbacks and release
  old snapshots on replacement/closing.
- Yield the Vault scan after a 6 ms slice even when read/hash/decode futures finish
  immediately. Publish maps/indexes only at the original atomic boundary.
- Attach bounded existing frame/stall diagnostics for the application lifetime,
  including non-Canvas navigation/settings/notes; no new telemetry sink.

All sort modes retain deterministic ascending-ID ties. Mutable caller lists and
duplicate IDs have coverage; bulk changes/order changes rebuild the projection.
Object identity changes invalidate edits, remote updates, undo/redo and deletion.
View caches are dropped on owner changes or when their folder leaves traversal.
Theme, zoom, read-only and animation behavior are read live by viewport builders;
no rendering/ink cache policy or durable schema is changed.

## Validation — 2026-10-31

First broad focused run: 113 pass in 32 s, covering folder organization/safety,
Explorer touch/mouse/grouping/batch behavior, source/index guards, editable PDF
ink, actual pen pixels across zoom/undo, mixed long note/Canvas/PDF, durable large
saves, motion and diagnostic bounds. Initial checks exposed an offscreen menu tap
and a reopen wait that did not drain timer-based initialization; fixtures now
scroll the menu into view and drain fake/native work while retaining assertions.
The exact six-mode sort parity checks pass (2,000 objects, local/remote edits,
add/remove/bulk changes, caller mutation and duplicates).



Equivalent full-repository before/after profiles completed all 23 stages with
zero errors (10,003 stored objects, 10,100 initial Canvas elements, 100,000 saved
pressure samples, 2,000 paragraphs, generated 300-page PDF). Headline UI p95 ms:

| Interaction | Published source | Retained fixes |
| --- | ---: | ---: |
| 60 workspace notifications | 123.306 | 41.955 |
| 30 external long-note edits | 137.720 | 69.972 |
| 30 actual visible-field edits | 120.295 | 59.166 |
| 20 short stylus strokes including commits | 117.401 | 56.634 |
| Split note/PDF updates | 132.964 | 46.635 |
| Settings/navigation | 154.099 | 36.457 |
| Explorer filtering | 106.510 | 29.375 |

Raster p95 for ordinary note/status work stays about 1.7–2.1 ms. Warm PDF scroll
UI p95 is 1.39 -> 1.68 ms; this is not claimed as an improvement. Cold opening
10,000 memory-backed files: ~589 -> 613 ms total open time; longest event-loop
gap 578 -> 231 ms. The yielding fix improves interactivity, not total loading
speed. Cold startup p95 is not compared because yielding changes the number of
intermediate frames; worst UI frame remains ~210 ms. Large Canvas cold raster
frames still reach ~209 ms, and some retained-layer warm-pan raster spikes remain
~140 ms at p95 in this deliberately dense fixture. Long strokes have mostly small
frames, but committing them still has ~75 ms worst UI frames. These are remaining
bottlenecks, not a claim that the entire app now meets every display budget.

After 150 repeated note/large-Canvas navigation cycles, RSS samples fluctuate
~512–583 MiB (before ~562–584 MiB), ending ~559 MiB (before ~566 MiB); no monotonic
increase in these five batches. Idle produced zero frames in five seconds in
both versions. This bounded session is not an hours-long leak or device test.
Additional speculative projection caches were tried, compared natively and
removed because they did not establish a stable additional gain.

Final broad retained-source run: 115 tests passed in 29 s. After removing the
unproven cache candidate, 33 affected checks passed in 15 s, including actual-font
captures, mutable caller-list changes, all 1,000 hidden-item selection and final
row navigation, six exact sort orders, source/organization invalidation and atomic
scan yielding with unchanged CRLF/Unicode/unknown-field bytes. Analyzer lib/test/
tool clean (8.8 s); strict format 932 lib/test files unchanged (10.45 s). Full
~2,900-test suite intentionally not run. Native builds and release verification
are recorded below when complete.

The baseline is the published application source at d5c3e47 (docs-only HEAD
5d28a8d). Private numeric captures are `.local/workspace-expanded-before.json`
and `.local/workspace-expanded-after.json`. Both use the same expanded harness;
fixture setup and optional cloud adapters are isolated. The earlier controller-
only fixture and CPU-sampled candidate runs are not substituted for these paired
headline measurements. Native disk latency, real Drive transfer load, physical
pen event delivery and Android device frame latency remain unmeasured here.

A separate retained-source 10-second CPU/timeline capture recorded main-isolate
heap ~53 -> 175 MiB during fixture/editor activity, and 3,951 VM-wide nested/
parallel GC spans with a maximum span ~90 ms. The ~7.49 s sum overlaps across
phases/threads and is explicitly NOT UI pause time. Neither endpoint is a forced
post-GC live-set measurement. These data identify remaining allocation/collection
work; no leak-free or GC-free claim is made. The existing sampler now records only
aggregate heap/external-memory/GC counters and strips host paths from source/
native module metadata. Its final targeted Dart analysis passes. Actual-font
Explorer/tablet captures were inspected without visual changes.

## Native build and publication state — 2026-10-31

Source/tag: `a920ee9f67f84344a4fca7c7f4c90a2485e5bb8c`, version `1.0.18+19`,
`preview-1.0.18-2026-10-31`. Source is pushed with `[skip ci]`; zero GitHub
workflow runs are verified. Windows built in an isolated source checkout because
the owner's running app maps the usual build/Release files. Fresh compilation
passed in 283.1 s (290.3 s including the unchanged bundled helper). Runtime numeric
version, lib/main.dart entry point, AOT freshness and all 13 authored font hashes
are verified. No user app was terminated or usual Release file overwritten.

The first Android build (625.1 s) used the default development package/signature;
this was caught before staging/upload. Existing ignored signing configuration
uses a DPAPI-protected password and original preview keystore. The corrected
build explicitly requires production signing and the preview package, passed in
37.4 s (42.2 s wrapper), and matches the original 1.0.17 certificate. Package
org.orbitnote.app.preview, versionName 1.0.18/versionCode 19 and three changed AOT
libraries are verified. No new key was generated or key/password printed/copied
into artifacts. The corrected APK is uploaded to draft release 429690689 and its
remote size/SHA-256 match the local artifact. The draft-by-tag API returned 404;
reading the existing draft by release ID verifies it without creating duplicates.

Windows packaging was rejected twice by automatic approval review: first for
reading/checking an embedded Google registration value while packaging, then
because the previous approval was available only in delegated context/project
records rather than fresh direct user confirmation for this exact package.
Historical approval records and Google's official desktop public-client guidance
were checked, but the reviewer still requires direct confirmation. Windows
packaging/upload therefore remain unexecuted. Older frozen-input hashes predate
the current registration and are not claimed as proof of its identity. No
configuration JSON, account token, keystore, private Vault or tmp file is uploaded.

The final required step is fresh user approval of this Windows package. The local
runtime can be copied into the usual run folder only after the owner saves and
closes the active app. The public release remains a draft until these publication
requirements are resolved. Next performance task after this release: reduce
cold dense-Canvas raster/reopening spikes while preserving exact vector quality.
