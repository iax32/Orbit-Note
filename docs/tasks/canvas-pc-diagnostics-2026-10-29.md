# PC Canvas stalls and diagnostics

Owner confirms intermittent severe stalls after 1.0.7 and asks to diagnose the
actual tablet-imported UE2 board. Preserve visuals, samples and existing tools;
focus on Windows before further mobile work.

## Reproduction and fix

The similarly named original Desktop Vault has a different four-element board.
The tablet import contains the relevant 1539-stroke / 42890-sample board. The
owner confirmed the tablet import. Its data/camera were copied into ignored
local files for an isolated native profile. No account, live relay, repository
writer or original Vault is opened by the probe. The private geometry and its
rendered images must never be committed or included in release assets.

Previous cached layers grouped only visible strokes. As a pan brought a member
in/out of the query, group membership, key and bounds could change without any
edit. That regenerated cached ink. A scene-revision plan now groups complete
ordered strokes once. Spatial visibility selects those immutable groups. The
original column-first/insertion painting order, full vector geometry and clipped
viewport remain. An explicit regression moves strokes through viewport margins
and proves the saved layer does not repaint or lose group members.

## Local flight recorder

Normal Windows startup enables diagnostics unless locally disabled. Web has a
no-op storage adapter; shared/application code does not import dart:io. Files
live in application support/Performance, outside every Vault and sync manifest.
Settings → Tools → Canvas performance logging provides a persistent on/off
switch, Save diagnostic log and Copy log location. Viewing Settings alone never
initializes a native store; normal app startup owns the service.

Recorder fields are enum event names, UTC/monotonic timestamps, frame/surface
numbers and finite numeric counts/timings. No Vault/title/path, note text,
points/coordinates, images, references, account data or invitation tokens enter
events. Native storage retains current/previous JSONL files at 512 KiB each.
An in-memory queue holds at most 128 events; asynchronous writes are serialized,
coalesced and detached from the drawing path. Saturation retains a dropped-count
summary. Logging/file errors never break editing.

Counts include editor updates/builds, saved-layer paints, vector-cache entries,
samples and recordings, visible groups and projected layer pixels. One-second
summaries aggregate rather than writing each input sample. GPU/UI/vsync stalls
use the display refresh budget; a 250-ms heartbeat catches event-loop pauses.
Repaint reason flags: 1 scene/revision, 2 working-set membership, 4 camera/origin,
8 palette, 16 decoded images, 32 linked objects, 64 interaction, 128 other style.
Exports stay local and under the user's control; there is no upload endpoint.

## Full-app diagnosis and active drawing

The first Windows 1.0.8+9 owner replay was about 60% smooth / 40% laggy. Its
normal app recorder showed repeated palette invalidation even without a theme
edit and 20–30-ms editor updates on equivalent parent data. Root ThemeData is
now memoized by all real theme inputs, including mutable override snapshots;
equal OrbitColors interpolation does not introduce floating-point drift.
Explicitly colored saved ink ignores unrelated palette/chrome changes. Only
deeply immutable object snapshots opt into the drawing comparison memo; mutable
callers keep structural comparison. Adopting a genuine external revision clears
the old local echo/comparison so subsequent refreshes cannot repeatedly reset
history. Tests cover real theme changes, remote adoption and undo/conflicts.

The owner then confirmed viewing was alright, but drawing remained unusable.
The next native replay therefore includes 4800-sample mouse and variable-pressure
strokes over the actual board at 400% zoom. This exposed GPU replay of all
previous pressure segments despite incremental Dart picture recording. Active
pressure chunks now have separate retained, tightly bounded, device-aligned
layers. Only the unfinished tail changes; offscreen chunks are culled and layer
bounds cropped near the viewport. The original nib renderer, source pressure/time
samples, brush end taper and durable commit/undo path remain. Constant-pressure
mouse curves append quadratic segments and replace only their endpoint without
splitting the continuous smooth path. The live tail opts out of raster caching.

All seven nibs pass exact vector-cache pixel comparisons. Actual composited
layers are also checked at 100%, 125% and 400%, through append/shrink/clear;
isolated antialiasing differences are bounded (24/255 maximum channel delta,
under 0.1% of channels over 2, total error under 2% of visible alpha coverage).
The renderer does not simplify source samples or change export geometry.
Input callbacks, preview snapshots, preparation, live paints and retained active
section counts now have separate numeric-only diagnostics (renderer generation
5) to distinguish any remaining real-app bottleneck.

Matched long-stroke native probe, same 400% camera/input and private in-memory
fixture, 100-Hz display (milliseconds):

| Stage | Before retained pressure layers GPU P95 / worst | With retained layers GPU P95 / worst |
| --- | ---: | ---: |
| Long pressure stroke, 312 frames | 13.009 / 16.407 | 1.691 / 2.123 |
| Long mouse stroke, 312 frames | 5.366 / 9.252 | 4.397 / 5.794 |
| Short pen over existing drawing | 3.388 / 4.788 | 1.421 / 2.976 |

Long pressure UI P95 1.062 → .443 ms, GPU frames over 10 ms 96 → 0. This is
synthetic input, not measured physical stylus latency. The owner's full-app
display is 180 Hz, with a 5.56-ms budget. A pan outlier still reached 19.011 ms;
do not promise zero stalls. Scene cache results can vary with GPU/resource load.

## Validation and delivery

48 final focused checks pass: numeric-only logging, queue bounds, rotation,
serialized readback, persistent off/error isolation/controls, theme refresh and
revision adoption, viewport stability, all pen styles, live retained pixels,
input hot paths, ruler/palm controls, highlighters, live presence and a separate
1000-move release-endpoint/cancellation/single-undo regression. Analyzer clean
(15.5 s), strict format 873 files unchanged (7.33 s), git diff --check clean.
Windows 1.0.8+9 built successfully (75.0 s), including the existing Google desktop
configuration and standalone server; no server was started or keys packaged.
Usual Desktop shortcut points to the rebuilt release and its AOT is newer than
all lib sources. Earlier intermediate batches also exercised split-pane
transactions, conflicts and Canvas export layers. No Android build/publication
was requested for this PC-first continuation. Physical input acceptance remains.

First matched native comparison (100-Hz PC, same input/camera/event sequence):

| Stage | Before GPU P95 / worst | Stable groups GPU P95 / worst |
| --- | ---: | ---: |
| Pan and return, 182 frames | 19.202 / 26.741 ms | 7.871 / 12.053 ms |
| Idle | 2.134 / 2.134 ms | 2.327 / 2.327 ms |
| Parent refresh | 2.684 / 2.734 ms | 2.484 / 2.902 ms |
| Pen over saved drawing | 3.986 / 5.429 ms | 3.005 / 4.116 ms |

Pan UI P95 9.244 → 5.470 ms, GPU frames over the 10-ms budget 63 → 4.
Cold frames still reached 27.077 ms; do not claim zero stalls or perfect FPS.
The local event log confirms 1539 strokes/42890 samples, no membership or palette
invalidations during steady panning, and no dropped diagnostic events. Actual
full-app intermittent background-work stalls need the normal app recorder;
the isolated probe deliberately does not open personal sync credentials.

Next required acceptance: owner uses mouse/stylus on UE2 with renderer 5 and
leaves the app open if drawing stalls, so active input/paint timings can be read.
No claim about tablet performance follows from this PC-first work.

## Follow-up after renderer 5 owner acceptance

Owner again reported about 60% smooth / 40% laggy drawing. The reopened app
confirmed active preparation/paint/input were sub-millisecond, while a completed
stroke's synchronous draft publication reached 158.648 ms. The isolated render
probe had intentionally used a no-op save callback, so it did not measure the
full application's immutable snapshots and repository pipeline.

`WorkspaceController.edit` now compares structured data with `jsonValuesEqual`
instead of serializing two entire boards on every stroke. UniversalObject's
owned frozen lists preserve already-immutable sample arrays across snapshots;
mutable caller lists/maps are still recursively copied and cannot mutate a
previous revision. Canvas root/element snapshots and source JSON remain ordinary
maps/lists. Unknown fields and the full original sample set are preserved.

ObjectCodec estimates large work using file/array lengths and moves large native
JSON encoding, UTF-8 conversion and the resulting hash to a worker. The native
file journal also hashes large outgoing byte arrays off the UI isolate. Shared
code uses a conditional browser fallback; no unconditional native API was added.
Small saves keep their direct path. Repository serialization, current-revision
checks, expected hashes, atomic staging/replacement, journals and saved-state
reporting remain. JSON validation occurs in the encoder before staging files;
other lifecycle callers retain their existing validation preflight.

Follow-up evidence: 26 checks pass including 60000-sample immutable ownership,
yielding/exact-byte encoding, native save/reopen, invalid JSON leaving the source
unchanged, external edits still rejecting writes, 20 guarded full-app commits,
same-frame competing Canvas drafts and recovery. The preceding 33-check native
save/recovery batch also passed. Debug app publication benchmark: 70–116 ms
total for 20 guarded commits (3.5–5.8 ms each), not a physical input latency
claim. Renderer generation 6 Windows build succeeded in 77.0 s, with AOT newer
than all lib sources and the usual Desktop shortcut still targeting it. Analyzer
clean (17.1 s), strict format 877 files unchanged (7.72 s). A further 25 drawing,
pen, theme-refresh and diagnostic regressions passed after the snapshot/encoder
changes. Owner was asked to reopen UE2 and test consecutive short and long strokes;
that real-app acceptance remains pending.

## Follow-up after renderer 6 owner acceptance

Owner reported 80% smooth / 20% intermittent pauses: better, but not accepted as
finished. Normal-app active pen work is sub-millisecond; synchronous publication
is down to about 12–26 ms, with echo comparisons growing to about 8 ms over new
strokes. Freeze a completed gesture's points once at the UI command boundary,
using the same owned immutable JSON snapshots as UniversalObject. Subsequent
commits/echoes reuse their nested sample arrays. Live previews continue using
their separate append-only cache; no per-pointer deep freeze was introduced.

External-change preflight still hashed large owning files synchronously, even
for a byte-identical self-write. Both targeted and full checks now use the native
worker. Refresh also hashes/decodes large changed objects off the UI isolate;
unchanged byte hashes still return the exact retained UniversalObject, preserving
saved layers and editor identity. No timestamp shortcut or skipped conflict check
was added. Release, scene snapshot, draft comparison, immutable snapshot and
notification durations are separate numeric-only events in renderer generation
7 for the next real-app replay.

53 focused tests passed, followed by 31 tests for the final preflight paths, plus
the 1000-move release/palm/cancellation/undo regression. The large native fixture
exercises targeted/full preflight, refresh identity, yielding input, invalid JSON
without writes and external changes still refusing overwrite. The guarded app
benchmark now includes 20 new 200-sample strokes and proves their sample arrays
remain shared with accepted immutable revisions: 67–68 ms total in debug. This
is not a claim of physical latency. Renderer-7 Windows rebuild succeeded in
75.0 s and AOT freshness was verified. Analyzer clean (15.7 s), strict format
877 files unchanged (7.55 s). Owner replay requested; acceptance pending.

## Follow-up after renderer 7 owner acceptance

Owner still reports intermittent pauses. Normal-app phases now isolate scene
serialization (2–6 ms) and recursive draft freezing (up to 11.966 ms) after each
release. Active ink remains sub-millisecond. The latest session contains 1664
strokes / 95732 samples. Reusing only nested sample arrays left all complete
element records being copied/frozen on every command.

CanvasElement now preserves maps proven owned by the immutable object boundary.
Scene loading retains those records. A separate `snapshotJson()` API creates an
immutable command snapshot sharing unchanged complete element records, so the
controller's next UniversalObject snapshot does not rewalk the board. Unowned
legacy maps still get detached for each snapshot and later alias changes remain
observable in later snapshots. The ordinary mutable `toJson()` API/export is
unchanged. Ordered elements sort once per revision; callers still receive an
independent mutable list, and undo restores order with explicit invalidation.

48 focused tests pass: snapshot alias isolation, record identity, opaque/unknown
data, reorder/undo/redo, retained pen/layer pixels, guarded full-app publication,
native save/reopen and competing pane recovery. Guarded debug 20-stroke commits
now take 25–29 ms total (was 67–68 ms); each new stroke includes 200 samples.
Standalone native AOT probe over the original isolated UE2 copy: 20 commits,
including new sample creation, 27.320 ms; large encode/hash/decode yield to the
calling event loop. Maximum loop gap 17.337 ms, matching the ~16-ms Windows timer
quantum in this non-UI probe rather than the app's 180-Hz display budget. No Vault
writer/account is used. This rules out a consistent 100-ms encoder handoff pause
in that probe, not all sources of real-app stalls.

Analyzer clean (14.2 s), strict format 877 files unchanged. Renderer generation
8 Windows built in 74.3 s, then was superseded before owner replay by the worker
handoff fix below. The latest offered build is renderer generation 9.

## Latest-fixture worker handoff cliff

Before offering renderer 8 for replay, the latest saved board was copied into
ignored local storage. It is ~14.8 MB / ~96k samples, twice the original fixture.
The native AOT probe exposed caller gaps of 90.915 / 86.614 / 30.892 ms over three
full-graph Isolate.run saves, versus an idle baseline 15.263 ms. The original
~7-MB fixture had not crossed that handoff/heap-copy cliff. Do not infer whole-app
smoothness from the small-fixture GPU or save replay.

The codec now owns one incremental native save worker, seeded from the previously
saved source string and its element slots. Source strings can be shared without
copying a large Dart object graph. Subsequent jobs pass unchanged slot references,
changed immutable element records, current ordering and current metadata. The
worker still reconstructs the complete portable object and invokes the ordinary
JSON encoder; this is not a durable delta format or a change to file authority.
Output bytes use transferable storage. Repository expected hashes, atomic write,
journals, conflict checks and saved-state reporting remain unchanged.

The derived cache holds one board, uses a (workspace ID, object ID) key, prunes
removed records and resets on failure/reopen/close. Jobs serialize; board switches
reseed from authoritative text. Invalid supplied seed text safely falls back to
a full snapshot. Unexpected worker exit fails the request promptly and the next
job can restart. Owned JSON records are shared; legacy mutable runtime toJson
objects are classified nonportable and sent fresh, preserving their behavior.
Non-Canvas shapes retain the previous worker path; browser uses its conditional
direct fallback. No native API entered shared domain/Canvas code.

Matched final native replay: first incremental start caller gap 18.665 ms,
repeat saves 16.870 / 17.808 ms, idle 16.282 ms; complete encode jobs take
324–485 ms in the worker while the caller keeps yielding. 20 in-memory commits
including 4000 new samples take 22.996 ms total. This is background
save duration, not input latency, and first-start/device acceptance remains.
39 drawing/draft/logging regressions pass plus 31 final worker/native safety
checks: same-ID edits, reorders/deletions/opaque fields, exact bytes/digests,
cross-Vault queueing, close/restart, invalid data, worker death/restart, unrelated
seed fallback, large Markdown compatibility, mutable toJson values and native
source conflict/reopen. Analyzer clean (15.4 s), strict format 879 files unchanged
(7.16 s). Renderer-9 Windows built in 74.2 s; AOT is newer than all lib sources,
and the usual Desktop shortcut points to it. Owner asked to reopen and draw on
UE2 for about a minute. Physical replay is required before declaring completion.

## Confirmed automatic Drive inventory pauses

Renderer 9 owner replay still shows occasional pauses. Its normal app log now
records draft snapshots at 2–3 microseconds, scene snapshots around 1.3–2.0 ms,
pen release 1.5–3.8 ms and active ink mostly <.3 ms. Periodic main-thread delays
around 118 ms remain. The owner supplied Sync-settings screenshots confirming
automatic Google Drive sync is actively running on this ~15.3-MB Vault. Personal
sync and active shared authority are mutually exclusive in the controller.

`captureSyncInventory` still synchronously hashed and fully decoded owning JSON
files, including all ink samples, on each full reconciliation. A native AOT probe
on the current ~14.8-MB fixture reproduces 307.823-ms caller blockage for the old
hash/decode work. Idle timer baseline is 16.460 ms; new cold sync inventory
max gap 18.087 ms and warm inventory 16.095 ms. Cold/warm total background scan
durations are 304.685 / 115.970 ms, while the caller keeps yielding.

Large hash/inspection work now runs through the native execution adapter. The
normal codec still validates the complete payload but returns only a compact
sync header (identity/type/read-only/attachment metadata), avoiding another full
scene graph allocation on the UI heap. Repository-owned metadata can be reused
only when the freshly computed file hash matches its durable object's hash and
workspace. No timestamp shortcut, skipped byte check or weaker parsing was added.
Changed/malformed/future payloads and missing/changed attachments remain blocked.
Drive cadence, upload/download bytes, guarded staging and conflict behavior stay
unchanged; automatic sync was not paused or disabled. Numeric Drive poll/full-
inventory/end markers (wall time explicitly labelled) join renderer-10 logging.

49 Drive-controller/inventory/replica checks passed, including real two-store
transfer, interrupted downloads, external edits and replay-safe moves. Another
30 final inventory/logging/replica checks pass, including large cold/warm scans,
stale-cache identity changes, malformed trailing data, newer formats and missing
attachments. Analyzer clean (18.8 s), strict format 880 files unchanged (7.79 s).
Renderer-10 Windows build is running with Orbit closed. The owner's physical
UE2 replay with automatic Drive still active is the next acceptance step.

## Renderer 11, real-app profiling and Android folder opening

The renderer-10 build completed in 89.3 s, but owner still reports pauses. Saved
UE2 device settings and new numeric driveState events show automatic sync OFF
in the later run. Earlier screenshots showed it ON; no setting was changed by
this investigation. The Drive inventory improvement remains, but cannot explain
the latest residual. Do not equate that disabled run with active-sync acceptance.

Completed active pressure chunks now reuse their widget subtrees, invalidated
by actual cache generation/camera/viewport/stroke shrink changes. Ink-only hover
short-circuits segment scanning unless a card/connector candidate needs exact
occlusion. All pressure/nib/taper/sample/opacity behavior stays. 36 focused checks
passed. Latest isolated native board/camera-4 replay: pressure GPU P95 1.968 ms,
mouse 4.741 ms, pan one 19.338-ms outlier on the 100-Hz probe display. Owner's
180-Hz full app still feels around 70/30; the drawing goal is not complete.

Added optional native full-app profiling entrypoint and a VM-service timing-only
collector. Normal release still uses lib/main.dart. VM service is loopback-only;
private authenticated endpoint and traces remain .local, never release assets.
Reports contain code/function timing and GC/frame span names, no object/widget
inspection or timeline arguments. First 45-second capture was idle. A subsequent
recent 60-second capture includes 1107 CPU samples, 13.658-ms root layout and
11.181-ms raster spans. Concurrent GC spans are not themselves stop-the-world
pause measurements. Need further attribution before choosing the next fix.

Android owner report: no error; selecting a folder from another Orbit version
returns to the welcome screen. Installed file_selector_android resolves SAF
selection to a raw filesystem path; no SAF-backed store grants exist. Added an
explicit Import Vault folder action with disclosure, progress, cancellation and
provider failure text. Streams a selected tree on Android's worker into a unique
staged app-owned Vault; source remains unchanged. Preserves ordinary files,
unknown fields, stable workspace/object IDs and history. Excludes other-device
state/cache/indexes and relocates recovery journals under imported-recovery so
foreign commands never execute. Rejects missing/oversized manifests, unsafe or
case-colliding paths, cycles, excessive size/depth and changed/failed files;
partial copies are not published. No all-files permission or app-version gate.
Repository future storage versions retain normal read-only behavior. Android
New Vault creates app-local folders without the broken raw-path picker.

Android adapter/error/retry UI: 3 checks pass. The first UI test needed to reset
its platform override before Flutter's invariant check; corrected and rerun.
29 rendering/pen/theme checks passed in the preceding batch. Analyzer clean
20.1 s; strict formatting pending. Signed preview APK 1.0.8+9 built in 184.6 s,
package/launcher/version/original signing certificate verified. Normal Windows
release 125.7 s, AOT newer than all lib sources. Owner now requests immediate
source + both release uploads, then continued diagnosis. Native copy tests and
publication verification are in progress. Physical Android acceptance pending.

## Published checkpoint and continued history work

Published 1.0.8+9 source 82dfb98390f7954d39f3308c5999258c2c5c494c:
https://github.com/iax32/Orbit-Note/releases/tag/preview-1.0.8-2026-10-29
Windows setup 14.547 s. All six uploaded assets match local sizes and GitHub
SHA256 digests. GitHub API confirms zero workflow runs for the source commit.
Android native importer tests: 8 passed / no skips, 0.299 s execution, Gradle
preparation 76 s. Strict 882 files unchanged in 8.86 s. Only unrelated tmp/ was
left untracked at the published checkpoint. Release artifacts remain pinned to
that source and renderer 11; subsequent local work is a separate checkpoint.

Continued per owner request: real capture self/inclusive samples identify native
history scanning/path validation as UI-isolate work. Move history enumeration,
record decode, safety checks and retention maintenance to a native worker with
small argument transfer; serialize requests and retain the Vault lease through
maintenance on close. Preserve last before-image per target, pending journal
protection and original count/byte/age policy. Unknown/oversized metadata and
mismatched before-image names are preserved, not eligible for pruning. No owning
file format or save-commit/recovery authority changes.

25 focused checks pass, including large save/reopen, retention, unresolved
journals, malformed/cross-entry/traversal records and native staging. Analyzer
clean 29.1 s, strict 884 files unchanged 9.08 s. Synthetic 200-revision native
AOT scan: previous foreground 138.986 ms wall, worker cold 108.513 ms, repeat
143.882 ms. Idle max timer gap 16.065 ms, foreground 16.062 ms, worker 16.280 /
15.836 ms. These coarse Windows timers cannot establish 180-Hz frame behavior;
no claim of an across-the-board wall-time or smoothness win. The benefit is
moving history parsing/allocation and metadata callbacks off the drawing heap.
Owner's drawing overlapped release builds, so the frame outliers from that
period require a replay without compilation/test load before causal attribution.

Renderer-12 normal Windows build succeeded in 92.2 s at lower process priority;
AOT freshness verified. The running Profile copy remains renderer 11 and was
not closed or replaced. Owner can save/close it and use the normal shortcut when
convenient. Renderer 12 needs physical replay. Android APK at published 1.0.8
includes folder import; physical Lenovo acceptance is still pending. Do not
claim the remaining pauses fixed or confuse the local follow-up with uploaded
renderer-11 assets.
