# PDF ink and measured responsiveness — 2026-10-30

Requested: editable PDF drawing and major performance improvements without
removing features or reducing visual quality. No server work or user-Vault edits.

Delivered shared-engine pen/highlighter/stroke eraser, pressure/endpoints,
gesture-sized Undo/Redo, source-bound ordinary file sidecars and native vector
annotated copies. Original attachments, text selection/read mode, forms,
navigation, page layouts, reading rooms and existing highlight/review workflows
remain. Tools are visible through Draw; the extra toolbar appears only in that
mode. Authored ink colors remain independent of PDF paper filters, while page
effects/lens include both source and drawings.

Live samples do not notify the workspace or rebuild/repaint the static source
layer. Saved strokes use retained vector pictures, visible page rows and shared
per-page spatial queries, with a 16-page LRU. Validation reuses immutable sample
snapshots; commands touch stroke IDs and protect stale source/removal state.
No new renderer, package, background service, credential or storage authority.

Broader gains: workspace ID lookup is indexed instead of rescanning every object;
the assigned list is owned so caller mutations cannot invalidate the index.
First-match duplicate IDs and preference-record fallback are retained. Reading
session ticks rebuild only the countdown label, not the entire PDF reader.
PDF input/paint/commit counters join existing local count/timing-only performance
logging; no page text, coordinates, filenames, paths or credentials are logged.

Synthetic Windows/debug observations (not device FPS claims):

- 20,000 objects / 5,000 indexed lookups: about 0.5–5 ms vs 4.9 s scanning.
- 20,000-page row index / 10,000 camera queries: about 5–7 ms total.
- 10,000 strokes on one page / 2,000 spatial queries: about 13–21 ms total warm.
- 1,500 pressure samples and 15 live frames: about 292–416 ms test CPU; zero source
  widget rebuilds. Includes test/event overhead; does not establish frame latency.
- Existing 300-page native PDF six distant text/raster probes: baseline 200 ms,
  concurrent runs 195–236 ms. Existing final page quality unchanged.
- Existing 100,000-sample retained ink/camera benchmark is still checked; this
  task does not claim to eliminate its cold recording cost or all device stalls.

Final focused regression run: 94 pass in 20 s; analyzer lib/test/tool clean
(12.6 s), strict format 929 files unchanged (7.91 s). Actual-font tablet-sized
reader and native PDF raster captures inspected. Checks/build/publication
evidence is recorded in current.md after completion.
Initial checks found pressure defaults with equal min/max and an Undo paint-order
issue; both fixed. Baseline live-preview test expected a frozen preview despite
the existing borrowed hot-path sample view; it now checks capture-time count and
the eventual owned committed stroke. Mixed-workspace test's single-painter finder
predated virtual Canvas tiles; targets one drawable tile. Reading-library memory
fixture moved queue operations across fake/real async zones; kept in one zone.

Native export implementation was checked against primary
[PDFium annotation implementation](https://pdfium.googlesource.com/pdfium/+/refs/heads/main/fpdfsdk/fpdf_annot.cpp)
for InkList, SetAP bounding boxes and opacity resources. One appearance stream
per stroke avoids repeatedly regenerating all earlier pressure segments.

Physical Windows/Lenovo pen latency and real cross-device ink acceptance remain
separate from headless checks. No assertion of zero bugs or universally smooth
hardware performance. Next suggested task: a timed physical Lenovo/Windows PDF
pen trace on the same large course document; not started.
