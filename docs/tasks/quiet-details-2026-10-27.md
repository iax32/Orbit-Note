# Quiet details — delivered, 2026-10-27

Owner approves all twelve proposed details: stable reading anchors, retained
selection, equal-spacing guides, activation-only pane clicks, touch hit targets,
document preferences, stable refreshed search selection, table clipboard formats,
full titles/paths, PDF markup hit selection, closed tab groups and local errors.
Scope EDT-04/07, NAV-10/11, CAN-04/05, PORT and existing PDF/local boundaries.
Preserve existing features, visuals, unknown data, object/placement identities and
unrelated workspace changes. Extend existing implementations rather than duplicate.
Use focused interaction/failure/large-content tests, analyzer and format checks;
build Windows after validation. Physical pen/tablet/OS clipboard not simulated away.

## Implemented

All twelve approved areas extend existing boundaries. Details and limits:
docs/features/everyday-workflows.md, Quiet details. Persistent additive formats:
docs/architecture/implemented-formats.md, Closed tab groups and reader options.

- Rich reading anchor correction for height changes above the viewport; explicit
  scroll/resize/navigation/owner changes take precedence.
- Explorer batch moves keep selection IDs; full title/folder hover and long-press
  descriptions include archived folders.
- Measured equal-spacing Canvas guides, larger invisible touch/pen targets and
  activation-only first Canvas presses. Wheel navigation keeps its first event.
- Per-document PDF options merge changed fields into existing local view records,
  preserving future option values. No new cloud preference allowlist.
- Index refresh retains the canonical selected search location through renames,
  offset changes and ranking changes, while user selection/query changes win.
- Default table rectangle copy supplies TSV plus HTML where supported; line breaks
  remain inside cells. Explicit Markdown copy includes corresponding headers.
- PDF thin-mark hit allowance and an explicit chooser for overlapping marks;
  fast exact single-hit path, selection/forms/read-only/source guards preserved.
- Ten bounded local closed-tab groups restore order and pane references using
  retained document view state. Missing/trashed objects skipped, future schema
  preserved, single-tab reopening unchanged.
- Failed images are labeled at their Canvas placement with an available retry
  action. Retry does not mutate the document. Native buffers/descriptors/codecs
  now release on error; an old failed decode cannot poison replacement bytes.

## Validation

- Main nine-suite regression batch: 141 pass; one quick-switcher focus regression
  exposed an over-broad pointer shield. Replaced the shield with a Canvas input
  activation boundary, preserving normal text, modal focus and wheel delivery.
- Final five-suite run: **53 pass**, including ten new acceptance cases, the
  corrected focus path, split table/code transactions, composition/selection,
  pen/palm/cancellation/Undo, dense PDF indexing and native long-document tests.
- Additional actual-font Canvas integration/layout test: **1 pass**. Checks equal
  gap labels while dragging and failed-image retry without a document write.
  Inspected work/ui/quiet-spacing-and-image-retry.png; labels explicitly use Orbit's
  font family, matching the existing rendered objects.
- Persistence: closed group restart/order and retained selection/position, deleted
  objects, unsupported future group format; PDF option callback/remount and future
  values; no canonical content or original user Vaults altered.
- Search test reorders results while renaming the selected note and changing its
  source offset. Enter still opens the original canonical target.
- Reading-anchor test grows an existing block above the viewport and verifies
  unchanged visible paragraph position; explicit scroll cancels queued correction.
- Clipboard transport test checks TSV cell line breaks plus HTML and explicit
  Markdown. Existing rich table/split clipboard suites passed in the main batch.
- Performance: 600 overlapping annotations / 100 multi-hit queries: 128 ms test
  CPU; 10,000-marker index 71.5 ms and 1,000 checked exact hits 1,110 ms **including
  a brute-force correctness oracle**. Native PDFium: 300 pages, six distant text /
  raster samples 258 ms. These are headless CPU measurements, not device FPS or
  physical pen latency.
- Strict format: 847 files, zero changes (8.91 s). Final analyzer clean (12.0 s).
- Windows release built successfully (99.7 s) with the existing registered Google
  desktop configuration and standalone server. Seven required runtime artifacts
  verified; data/app.so is 27,181,968 bytes, built 22:27:48, newer than every Dart
  source (latest 22:24:50). Normal Release/orbit_note.exe launches the updated app;
  its native wrapper's older timestamp is expected for Dart-only updates.

No new package, credentials, server startup, ZIP, GitHub upload or Android build.
Physical Lenovo touch/pen and cross-app Excel/Word clipboard acceptance remain
unverified here.

Suggested next task: native tablet acceptance of dense PDF selection, equal-gap
dragging and first-press activation; stop before implementing another feature.
