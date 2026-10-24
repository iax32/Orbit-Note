# Native PDF and pen performance audit — 2026-10-24

Owner authorized the next large-document audit. Scope: INK-03/10/11 and
FILE-04/05/11/12/13 reliability/performance in existing engines. No new storage
schema, service, dependency or document conversion. Preserve existing work.

Plan: stress saved/active ink, pointer ownership and malformed imported samples;
exercise real PDFium with long synthetic documents, dense annotation lookups and
rapid navigation. Fix reproduced failures, run targeted and required checks,
build the direct Windows app. Hardware pen latency and physical-device acceptance
remain separate from headless evidence. No personal Vault or cloud data is used.

## Delivered behavior

- Saved strokes reuse native vector display lists at every zoom. The per-editor
  LRU retains at most 256 snapshots / 200,000 samples; oversized strokes render
  directly. Eviction, switching boards and editor disposal release native
  pictures. Edits create new keys; undo can reuse original snapshots. There is
  no raster flattening, source simplification or new persistent format.
- Active stroke snapshots are built once when a frame needs them, rather than
  copying every prior sample on every pointer event. Full samples still save;
  final release coordinates retain the last measured pressure. Bounds use one
  pass on completion. An individual very long active stroke still costs O(n)
  to paint at each display frame; constant-time active rendering is not claimed.
- First stylus contact from Select no longer cancels its own capture. Palm
  contacts cannot promote an active pen transaction to pinch. Unrelated pointer
  cancellation cannot discard it. Temporary inverted/barrel erasing restores
  the previous tool; cancel rolls back the captured gesture.
- Automatic recognition now commits the recognized element and releases
  capture, permitting the next stroke and one undo per finished action.
- Every nib bounds finite pressure for painting; invalid/NaN/infinite or
  misaligned imported samples cannot crash pressure rendering. Authored/unknown
  sample fields are preserved, not rewritten as normalized data.
- Dense PDF pages lazily index highlight hit tests by vertical band, preserving
  topmost paint order and inclusive boundaries. Only 16 clicked dense pages are
  retained; sparse pages use direct lookup. Immutable page-comment bounds are
  decoded once. Spotlight settings resolve once per painted page, not region.
- Comfort fitting has one active native measurement and one latest pending
  destination, cancellation tokens, document-scoped completed LRU (32 pages),
  same-page deduplication and retryable failures. Reset/replacement/disposal
  retire jobs; obsolete results never reposition the new page or viewer.

## Focused evidence

`test/pen_pdf_performance_test.dart` adds 12 regressions. The broader Canvas,
PDF reliability/markup/content-fit and motion batch passed **77 tests** in 20 sec.
No new regression was skipped on this Windows run; native PDFium was available.

Reproducible fixtures use no personal documents:

| Workload | Observation in focused headless debug run |
|---|---|
| 100 strokes × 1,000 pressure samples, 1,000 × 700 viewport, 60 camera changes | Display-list recording: uncached 5,383,342 µs; retained 1,050,693 µs including initial recordings. Exactly 100 strokes recorded; source JSON unchanged. |
| Seven nib styles through recolor, undo, redo and zoom | Cached/cold raster pixels identical; edited stroke has a distinct cache entry. |
| 1,000 pointer moves between frames, palm/cancel/release/undo | One durable stroke and one undo; old preview snapshot remains unchanged; release position/pressure retained. |
| 10,000 highlights on dense pages, 1,000 seeded random hits | All match brute-force topmost oracle; index build 53,253 µs. Combined oracle/check run 927 ms, not pure hit-test latency. |
| 200 rapidly superseded fit requests | Only first and latest native jobs start; obsolete results discarded, failures retry, disposal retires late errors. |
| Native 300-page PDF, 40 text lines + 100 vector boxes per page | Six distant text/raster content measurements in 211 ms; completed cache stays within four configured pages. |
| Actual reader with 3,000 notes / 24,000 regions across 300 pages | Rapid page destinations end on page 300; closing preserves reading position without exceptions. |

Timings are informational CPU/display-list measurements, not GPU frame timing,
input-to-photon latency, a 60/120 Hz guarantee, or a maximum supported capacity.
First native render cost, visible complexity and hardware still matter. Active
stroke painting and huge fully visible scenes remain proportional to complexity.
Environment: Windows x64, AMD64 Family 25 / Model 33 / Stepping 2, 12 logical
processors; Flutter stable 3.44.8 / Dart 3.12.2; Flutter headless test engine in
debug mode, concurrency two. No physical display refresh or stylus latency was
measured. This deliberately does not substitute debug totals for profile/release
p50/p95/worst build/raster timings on an identified reference device.

## Final checks

- Final full regression run: **3,016 passed, two existing skips**, 11:27. All
  12 new regressions, including both native PDF checks, ran successfully.
- Final `flutter analyze`: **no issues**, 9.1 sec.
- `dart format lib test` and strict verification: **752 files, no changes**.
- The tested source/configuration was frozen across **898 inputs** before the
  full run. All **898 remain unchanged** after the Windows build.
- Direct Windows release compiled successfully in **76.6 sec**, with matching
  standalone server. Verified seven required runtime files, 13 matching font
  assets and the registered Google desktop client in AOT. The new app snapshot
  differs from the prior release and contains both new performance cache types.
  Run `build/windows/x64/runner/Release/orbit_note.exe` with its sibling files.
  No archive was generated.
- Standard JavaScript web release compiled successfully in **73.8 sec**.
  Existing warnings remain: `google_identity_services_web` fails the SDK's Wasm
  dry run and a Cupertino icon font is not bundled. The JS build succeeds;
  Wasm support is not claimed and these warnings were not introduced by this
  task. No Android build or physical-device acceptance was performed.

No manual desktop-control or physical pen testing, private Vault operation,
cloud test, app/server launch, publishing or shutdown is part of this audit.
Suggested next task after validation: physical stylus/profile-mode frame and
input-latency acceptance with representative large real documents.
