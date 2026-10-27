# PDF rendering reliability validation — 2026-10-24

Scope: FILE-04/05/11/12/13. Fix disappearing/blank pages when reopening and
scrolling while retaining raster quality, selection, forms, annotations and export.

## Diagnosis and changes

- Windows PDFium callback reads could wake before data completion. A completion
  predicate under the same critical-section lock now tolerates lost/spurious
  notifications. Short/invalid/throwing reads report failure, never partial success.
- Equal-key viewer rebuilds during initialization no longer abandon document load.
- Restored viewport positioning precedes rendering; visible pages precede neighbors.
  Duplicate preview/high-resolution requests coalesce and share a serial render queue.
- Cached previews remain while under budget. Canceled or retired page/text/image
  results cannot replace current data; unloaded placeholders cannot become finished
  white previews. Late unreferenced document loads are disposed safely.
- Transient page-render failures receive three bounded attempts, followed by
  **Retry page**, preserving document, page, zoom, selection and annotation state.
- Memory-backed reads copy typed data in bulk. Original PDF bytes, PDFium version,
  final render scales and flags remain unchanged.

The packages are tracked compatibility patches of pdfrx 2.4.8 and pdfrx_engine
0.4.7, retaining licenses and upstream assets. See [provenance](../../third_party/README.md).
This is dependency repair, with no durable schema/storage-authority migration.

## Automated checks

- 201 focused tests passed in 37 seconds: all PDF/pen-PDF tests plus Canvas ink
  raster/markup/widget and read-attachment-preview regressions. Covers forms,
  highlights, export, native selection, split views and recovery.
- Native synchronization regression deliberately triggers spurious notifications
  before data completion. Callback result tests cover short, negative, oversized
  and throwing reads.
- A callback-backed PDF larger than 1 MiB with 180 pages survives three reopen
  cycles and 21 distant-page text/raster checks.
- Callback/file loading produce byte-identical full-resolution BGRA results for
  pages 1/90/180 at scales 1 and 3, including 1836×2376 output. No visual downgrade.
- Viewer regressions exercise rebuilt/retired loads, low-budget eviction and reuse,
  progressive-page replacement, pending decode retirement, restored-page priority,
  DPR-3 request coalescing, bounded failures and retry retaining native selection.
- Root analyzer and independent analyzers for both patched packages: no issues.
- Format and strict format: 761 application/test files, no changes remaining.
- Full repository suite was not rerun for this focused task.

Local logs: `.local/pdf-reliability-broad-tests.log`,
`.local/pdf-reliability-analyze.log`,
`.local/pdf-reliability-strict-format.log`, and
`.local/pdf-reliability-vendor-{viewer,engine}-analysis.log`.

## Native profile and limitations

Existing isolated `tool/pen_pdf_device_benchmark.dart`, Windows profile mode:
1264×681 physical pixels, DPR 1, reported 100 Hz, 12 logical processors.
Synthetic input, 100,000 saved ink samples, 300 PDF pages and 24,000 annotation
regions. No personal Vault or account is opened. The helper exits itself.

| PDF stage | Wall time | Build p95 | Raster p95 | Worst build |
| --- | ---: | ---: | ---: | ---: |
| Cold opening | 481 ms | 20.046 ms | 7.877 ms | 156.633 ms |
| Warm navigation | 2831 ms | 2.021 ms | 1.130 ms | 4.775 ms |
| 24 distant jumps | 2073 ms | 17.746 ms | 4.118 ms | 25.879 ms |

Final report `.local/pdf-reliability-profile-final.json` reports no errors and
reaches page 300. Cold/distant spikes remain; these numbers do not establish
universal frame-rate or hardware latency guarantees. No physical stylus was
available. Synthetic regression/profile success is not physical-device acceptance.

## Delivered build

- Final Windows build: 76.4-second application compile, matching standalone server;
  `.local/pdf-reader-final-windows-20261024.log`.
- Final web release: 103.8 seconds, `.local/pdf-reliability-web-final-20261024.log`.
  Existing SDK Wasm dry-run/font warnings remain; JavaScript compilation succeeds.
  Browser acceptance and Android builds were not performed.
- All 905 inputs in `.local/pdf-reliability-final-inputs.json` remain unchanged
  after profiling/builds. Runtime EXE, DLLs, PDFium, SQLite, AOT, ICU data and server
  verified present; new recovery strings verified in UTF-8/UTF-16 AOT data.
- Runnable Windows output: `build/windows/x64/runner/Release/orbit_note.exe` with
  sibling runtime files. No ZIP, main-app/server launch or GitHub publication.
- Owner closed the app for replacement. A previously closed, windowless old
  process was stopped after exact-path verification; this does not establish that
  every normal application shutdown path has been audited.

Suggested next task: exportable PDF diagnostics excluding document text and
private file paths, to investigate any remaining document-specific failures.
