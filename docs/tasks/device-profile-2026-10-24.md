# Native device frame profiling — 2026-10-24

Owner authorized the follow-up to the pen/PDF stress audit. The owner confirmed
that no stylus device is available to use now. Windows reports pen-capable
interfaces (three pointer devices; digitizer flags 140), which is **not evidence
of an available physical pen or a completed hardware test**.

Scope: profile-mode native Windows frame timings on isolated, synthetic Canvas
and PDF workloads using the actual editors/renderers. Do not operate a personal
Vault/account. A reproducible saved-ink raster bottleneck was found and fixed
within INK-03/10/11 and the shared renderer's existing cache direction.
Physical pen/palm/input-to-photon acceptance and
large real-document device testing remain pending until hardware/documents can
be supplied. Never substitute synthetic input timing for physical latency.

## Native profiling and the reproduced bottleneck

The standalone tool uses 100,000 saved pressure samples, scripted local Flutter
pan/stylus input, a 300-page vector/text PDF and 24,000 annotation regions. It
records native build/raster/total-span percentiles, separate pipeline budget
misses, process RSS, viewport/display information and explicit errors. Synthetic
dispatch-to-post-frame timings exclude hardware, GPU completion and scanout.
No global OS cursor input or app account initialization is used. Timings are
assigned by engine frame number so delayed timing batches do not get attributed
to the next scenario. Percentile/budget helpers are covered by three regressions;
build and raster are evaluated separately because the pipeline overlaps them.

The vector display-list improvement in the prior task reduced CPU recording but
still replayed roughly 100,000 pressure segments on the raster thread each frame.
The native baseline measured **247.550 ms raster p95** while panning and
**244.232 ms raster p95** during scripted stylus input over the dense board.
These numbers supersede any inference that the earlier debug recording speedup
proved smooth native rendering.

The paired first post-fix run measured **1.946 ms raster p95** for warmed pan and
**3.285 ms raster p95** for scripted drawing; the final source is being rechecked
after adding saturation protection. These are workload-specific engine timings,
not physical input latency or a general supported-capacity guarantee.

Hardware: Windows x64; Ryzen 5 5600X (6 cores / 12 threads), RTX 3060 (reported
driver 32.0.16.1742), approximately 31.9 GiB total physical RAM. Engine-reported
display refresh 100 Hz; viewport 1264 × 681 physical pixels; pixel ratio 1.0.
The graphics adapter is identified from OS metadata; GPU utilization/VRAM and
actual display scanout were not measured. Other desktop load is uncontrolled.

## Delivered renderer changes

- Committed complex strokes can use disposable native-density raster previews
  of their exact vector display list. Original samples, pressure, style and
  unknown fields remain unchanged and editable. Existing exports and authored
  replay retain the original renderer; a transient active stroke is not cached
  as an image on every sample.
- Preview resolution includes camera zoom and OS/device pixel ratio. Half-octave
  resolution levels round upward. When the old preview lacks sufficient pixels,
  the current frame uses vectors until the sharper preview is ready. App zoom
  changes layout/text scaling rather than scaling a low-resolution screenshot.
- Per-editor budgets remain 256 vector snapshots / 200,000 retained samples,
  plus at most 16,777,216 preview pixels including in-flight reservations. This
  corresponds to 64 MiB of uncompressed RGBA pixels; driver copies, vector/source
  data and allocation overhead are additional. At most two raster jobs run;
  individual previews exceeding 4096 pixels per edge use vectors.
- Preview completion repaints the Canvas rather than rebuilding the editor.
  Replaced/evicted/closed snapshots discard late images safely. Switching boards
  clears the cache; editor disposal closes it. Backend failure retains vectors
  and does not retry allocation on every identical repaint.
- Admission protects previews that are still visible. Over-budget visible
  strokes use vectors rather than endlessly evicting and regenerating each
  other's previews. Offscreen previews can be evicted for a changed viewport.

## Final native profile run

Final profile executable compiled successfully in 64.7 sec. All six scenarios
completed without recorded errors, retained exactly one committed scripted stroke,
and ended on PDF page 300. Peak process RSS was approximately 324 MiB. This is
process memory, not measured GPU memory or an isolated cache allocation total.

| Scenario | Frames | Build p95 (ms) | Raster p95 (ms) | Worst raster (ms) | Build/raster > 10 ms |
|---|---:|---:|---:|---:|---:|
| Derived-preview warmup, after initial 30 frames | 38 | 9.753 | 150.745 | 156.755 | 0 / 25 |
| Warm pan, 100,000 saved samples | 182 | 4.449 | 3.102 | 4.886 | 0 / 0 |
| Scripted stylus over saved ink | 185 | 6.503 | 5.185 | 9.139 | 1 / 0 |
| Cold 300-page PDF / 24,000 regions | 39 | 25.129 | 9.931 | 12.867 | 3 / 1 |
| Warm PDF navigation | 182 | 2.528 | 0.959 | 1.259 | 0 / 0 |
| 24 distant PDF page destinations | 156 | 18.460 | 3.199 | 15.083 | 23 / 1 |

Final warm-pan raster p95 was about 80× lower than the recorded vector-only
baseline; scripted-drawing raster p95 was about 47× lower. These comparisons
describe these scenarios, not general app FPS. The first post-fix run was faster
than this later verification run; desktop/background load was not controlled.
The remaining preview warmup wait was 3.082 sec after the initial warm frames.
Do not treat it as complete cold-window-open latency.

For 902 injected pointer events, application dispatch to framework post-frame
measured p50 15.651 ms / p95 18.235 ms / worst 30.942 ms. This explicitly
**excludes hardware delivery, GPU completion and display scanout** and is not
physical stylus latency.

Raw local evidence (ignored, synthetic data):
`.local/device-performance-profile-before.json`,
`.local/device-performance-profile-first-after.json`,
`.local/device-performance-profile-report.json`, and
`.local/device-profile-hardware.json`. No account tokens are included in reports.

Reproduce with the configured Flutter SDK, from the repository root:

```powershell
$reportPath = Join-Path (Get-Location) '.local/device-performance-profile-report.json'
flutter run --profile -d windows --no-pub -t tool/pen_pdf_device_benchmark.dart "--dart-define=ORBIT_BENCH_REPORT=$reportPath"
```

The isolated test window closes itself after flushing its report. A hidden or
sleeping display can prevent native frames; per-frame waits have a timeout and
empty timing sets are reported as unavailable, not zero-cost success.

## Validation

The focused rendering/pen/motion batch passed **65 tests** (19 sec), including
11 new preview regressions across seven pen styles, zoom/DPI coverage, original
JSON, memory limits, edit/undo, late disposal, allocation fallback, and saturation
settling. Three statistics regressions cover unavailable samples, percentiles and
separate pipeline budgets. Formatting/strict checks passed across 756 files
(lib/test plus the two profiler tools). **902 source/config inputs are frozen**
across final profiling, full checks and release compilation.

- Final full suite: **3,030 passed, two existing skips**, 13:42.
- Final analyzer: **no issues**, 8.2 sec.
- Final format/strict checks: **756 files, no changes** in the strict pass.
- Complete Drive controller batch after the timing repair: **24 passed**, 39 sec.
- Additional isolated native-DPI RGBA/spatial check: **one passed**, through
  recolor and undo; 3× density vector/preview images were visually inspected at
  `build/previews/ink-vector-density3.png` and
  `build/previews/ink-preview-density3.png`.
- Direct Windows app and matching standalone server built successfully
  (123.4 sec Windows compile). All 902 final frozen inputs remain unchanged.
  Seven required runtime files, 13 matching fonts and the registered Google
  desktop client were verified. The app snapshot differs from the previous
  release and contains the new renderer's entry/error markers. No ZIP was made.
- Standard JavaScript web release compiled successfully in **113.1 sec**.
  Existing warnings remain: the Google identity SDK is incompatible with the
  SDK's Wasm dry run, and a Cupertino icon font is not bundled. JS compilation
  succeeds; Wasm compatibility is not claimed. No Android build/device test.
- Final runtime/source verification after both builds found no changed frozen
  inputs, missing runtime files or font mismatches. The main release/server was
  not launched, no archive was created, and no publication or cloud/Vault
  operation was performed. The earlier user-requested shutdown interrupted this
  task; it was resumed and completed after the owner returned.

The initial broad run finished with **3,029 passed, two existing skips and one
failure** in 14:13. The existing Drive-sync case `continuous edits do not postpone
the earliest automatic upload` checked completed native publication after only
18 × 200 ms of typing. It passed unchanged in isolation (6 sec). The production
scheduler already retains the earliest two-second deadline and was not changed.
The assertion now continues typing for up to 60 iterations until publication is
observed, with at least the original 18 edits. A debounce that resets for every
keystroke still fails: publication must happen before typing ends. This removes
the arbitrary native-I/O completion assumption without accepting starvation.
The first run and original isolated result are retained in local evidence.

Only that test changed after the final native profile; source hashes confirm the
profiled application and harness are unchanged. All 902 inputs were re-frozen
for the final full-suite/release pass. The initial failure is not counted as a
pass or hidden by the later run.

The first high-DPI test incorrectly compared high-resolution previews against a
logical-resolution output. It was corrected to render both paths at the matching
physical pixel density; the coverage tolerance was not relaxed.
The extra RGBA check initially treated almost-opaque edge pixels as opaque;
premultiplied alpha made that an invalid color comparison. Fully opaque pixels
now test source colors, while separate alpha coverage and spatial-centroid
assertions cover edges/alignment. The initial diagnostic log is retained.
Raster-preview antialiasing is not claimed to be pixel-identical to vector edges.

Remaining boundaries: cache warmup and cold/distant PDF page loads can still
produce spikes. The warmup scenario starts after 30 initial frames and does not
measure total application cold-start latency. Physical stylus delivery, palm
rejection, hardware-to-photon latency and private large real-document acceptance
have not been tested. The owner confirmed no available physical pen.

Suggested next task after validation: reduce the measured cold-preview warmup
and first/distant PDF page transition spikes. Physical pen acceptance remains a
separate pending check until a real pen is available.
