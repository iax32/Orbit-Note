# Performance and failure-boundary audit — 2026-10-27

Owner requests performance checks, reproduced failure fixes, and continued
improvement without removing features or changing visuals. This batch covers
existing Finance, note Find/Replace, split-pane drafts/clipboard, PDF markup and
render-cache reliability, native Vault loading and Canvas routing. Synthetic
isolated data only; no personal Vaults, account tokens or desktop control used.

## Reproduced and changed

- Multi-account Finance reports repeatedly scanned every transaction per account,
  copied metadata, and revalidated unchanged account records. The index now groups
  records by account/month/currency/kind, validates immutable objects once using
  weak identity keys, and reuses unchanged controller snapshots. Replacement,
  Trash/restore and in-place list edits invalidate correctly; switching/closing
  Vaults releases the controller cache. Exact arithmetic and overflow checks stay.
- An overflowing monthly total prevented the Accounts/Transactions list from
  rendering even when that list did not need a monthly summary. Only budgets now
  request that summary. Individual account/schedule calculation failures display
  an actionable card with existing Edit/Open controls; healthy cards stay usable.
- Note Find scanned reference definitions twice and rebuilt Unicode offset maps
  for every query refinement. Rich search now reuses its single parse's reference
  table; Source search loads definitions only if requested. Case folding of the
  query runs once. Offset projections use an LRU bounded by 262,144 source UTF-16
  units and 8,192 segments. Huge single blocks are not retained in that cache.
  No cached parser document or changed authored source is introduced.

## Measurements and limits

Flutter test runner on this Windows PC, diagnostic wall times, not production
frame/input latency or cross-device guarantees. Fixtures and exact-result
assertions live in `test/performance_audit_test.dart`.

| Workload | Before | After, isolated run |
| --- | ---: | ---: |
| 80 accounts / 8,000 expenses, three passes of ledger + cleared balances and monthly summary | 4,809 ms | 45 ms |
| Initial Finance index over that fixture | 595 ms | 482 ms |
| Reindex identical immutable Finance objects | not previously reused | 25 ms |
| 12 Unicode queries over 2,000 formatted paragraphs | 207 ms | 82 ms |

Final concurrent acceptance run additionally measured Finance dashboard 48 ms,
warm index 26 ms and note queries 67 ms. Small timing differences are expected;
these are not hard pass/fail performance promises. Cold Finance validation and
long-note parsing remain meaningful first-load costs, not declared solved.

Initial broad stress run: native 3,000-object index rebuild 392 ms; 1,000 native
notes reopen 1.84 s with 40 ms maximum heartbeat gap; unchanged refresh 1.14 s;
6,603-block Markdown parse 182 ms LF / 72 ms CRLF; background canonical UML
routing 65 ms wall time with 10 event-loop ticks. JIT warmup, concurrent workers,
filesystem and host load affect these numbers. No physical stylus/mobile test.

## Validation

- Initial focused stress batch: 38 passed, including long note + 10,000-element
  Canvas + annotated 300-page native PDF coexistence, render cache eviction/retry,
  large native search/reopen and asynchronous use-case routing.
- Recovery/split-pane batch: 50 passed, including the new overflowing-account UI
  regression, financial cache invalidation, independent pane edits/undo, delayed
  table/code paste retirement and failed draft persistence.
- Final combined acceptance, analyzer and Windows build evidence is recorded in
  `docs/tasks/current.md`; suites overlap and counts must not be summed.
- Exact Unicode replacement/UTF-16 endpoints are checked after LRU eviction over
  9,000 rich paragraphs. Repeated native PDF extraction → Rich paste/cut/undo/redo,
  large connected Canvas transfer, PDF highlight deletion/retry and rapid PDF
  navigation are exercised by existing focused suites.

Logs: `.local/performance-audit-{baseline,before,after,measured,recovery,verified,
analyze-final}.log`, `.local/performance-format-check.log`.

Suggested next task: profile release-mode cold Finance/long-note opening and
incremental note edits on a realistic large synthetic Vault, with UI frame timing.
Do not infer real pen latency or universal smoothness from automated test timings.
