# PDF compatibility patches

Vendored from the unmodified pub.dev archives pdfrx 2.4.8 and pdfrx_engine 0.4.7.
Each package retains its upstream LICENSE and source attribution. Versions carry
`+orbit.1`; root path dependency/override makes release and CI builds reproducible.
The native PDFium version and supported Flutter SDK remain unchanged.

Why: later upstream releases fix disappearing pages and startup races but require
Flutter 3.47/Dart 3.13. Orbit currently uses Flutter 3.44.8/Dart 3.12.2.

Backports and bounded changes:
- Windows file-access completion predicate and matching critical-section wakeup,
  from upstream master `packages/pdfrx_engine/lib/src/native/win32/file_access.dart`
  downloaded 2026-10-24 (issue https://github.com/espresso3389/pdfrx/issues/595).
- Translate native callback results to full-read success/failure, rejecting short
  reads and exceptions rather than accepting partially initialized buffers.
- Equal-key document-reference initialization guard (upstream PR 727):
  https://github.com/espresso3389/pdfrx/pull/727.
- Render the restored viewport before publishing viewer readiness; skip unloaded
  placeholders and retire render/text jobs when individual pages are replaced.
- Dispose a late-loaded document when all viewer/use leases were removed.
- Visible-first, deduplicated preview requests with cancellation-safe decode,
  bounded transient retries and explicit per-page failure/retry controls.
- Keep off-screen previews within the configured memory budget; perform eviction
  once per paint instead of removing an image even below budget.
- Bulk typed-data copying for memory-backed native reads instead of a Dart byte loop.
- Cancel delayed progressive-page loading on source changes/disposal; running
  callbacks remain bound to their captured document/generation. Covered by a
  long-delay close/switch regression and the mixed-workspace load test.

Upstream changelog: https://github.com/espresso3389/pdfrx/blob/master/packages/pdfrx/CHANGELOG.md

Keep changes narrow and covered by root regression tests. Remove these forks only
when an SDK-compatible upstream upgrade passes the same reliability/selection,
forms, export and platform checks. Do not patch ignored package-cache files.
