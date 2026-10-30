# Drive sync throughput

Owner reports automatic Google Drive sync takes too long. Scope: SYNC personal
Drive publication/discovery throughput, preserved exact file bytes and existing
append-only revisions, checkpointed retries, forks, staged applies and account/
opening guards. No cloud schema migration or new credentials. Prior pen/live
sharing work is published and separate; do not conflate Drive with live hosting.

Inspect/measure then implement: redundant publication preflights, bounded parallel
cold revision reads, resumable upload chunk sizing, verified immutable revision
cache reuse and native staging checksum work. Use targeted two-client/failure
tests and representative request counts/latency. No full multi-thousand-test run.
Keep unrelated tmp PDFs private. Windows/Android deployment evidence and physical
device results must be reported separately from simulation.

Implemented: single-use same-key inspection tickets (2-second expiry), cached
revision bodies only after fresh metadata/checksum verification, create-only
fresh-ID uploads without a redundant existence probe, verified full create
acknowledgements with strict readback fallback, four bounded revision reads,
adaptive 256-KiB–8-MiB resumable ranges, documented gzip response headers,
manifest-only discovery before import, native combined staging hashes, immediate
durable publication receipt/feed membership and direct checks for indexed omissions.
No cloud schema migration, generated-ID overwrite or weakened fork/draft guard.

Measurements, production HTTP adapter against deterministic synthetic service:
- Ten notes: publish 135 -> 80 requests, history scans 23 -> 12; receive 44 -> 34
  requests / media reads 31 -> 21. Combined 179 -> 114 requests (36.3% fewer),
  not an end-to-end network speed guarantee.
- 14,680,101-byte file: 15 fixed-size ranges -> four adaptive requests; exact
  SHA-256 after receiving. Interrupted resume still uses the retained offset.
- Twelve catch-up revisions with synthetic 20-ms media latency: peak four reads,
  108–109-ms pass. Cancellation drains started reads and preserves checkpoint.
- Cloud opening with twelve notes: only two manifest media reads before import,
  instead of a complete history pass followed by another after opening.
- Native 14,365,022-byte fixture digests: old two-pass foreground 231.274 ms,
  combined worker 201.214 ms, equal SHA-256/MD5. Caller timer maxima 16.848 vs
  16.066 ms reflect Windows timer granularity; not proof of physical pen latency.

Focused checks: 71 Drive/engine/retention/staging/digest checks passed (60 s), 50
controller/batch/background/ink checks passed (43 s), plus final manifest/index-
lag/request-budget and acknowledgement-fallback checks (overlapping counts).
The full multi-thousand-test suite was not run.

Real Google Drive: first run uploaded/bootstrap verified exact bytes but exposed
new-record propagation lag. The next run failed before bootstrap (generic harness
failure had no diagnostic type); this led to inspecting own cache/feed membership
and fixing the missing receipt/checkpoint update rather than accepting a pass.
Final run passed all ten real acceptance phases in 2:04 (includes consent):
isolated two native replicas on this PC, new objects both directions, exact note/
Canvas/attachment bytes, offline conflict retention and reviewed resolution,
interrupted upload across repository restart, lost acknowledgement recovery by
stable ID, Trash/tombstones and clean persisted restart. No personal Vault used.
193 HTTP requests including auth/control/recovery. Observation timings including
reconciliation: new B->A object 5,144 ms / two checks; lost-reply content 4,317 ms /
one; Trash 5,745 ms / two; tombstone 6,299 ms / two. No pre-change real-network
baseline, cross-device acceptance or zero-delay claim. Synthetic cloud fixtures
were retained for inspection; credentials stayed in memory only.

Google API guidance used: [uploads](https://developers.google.com/workspace/drive/api/guides/manage-uploads)
and [performance](https://developers.google.com/workspace/drive/api/guides/performance).

Final selector refinement requests combined digests only for upload staging;
ordinary snapshots/download staging avoid unnecessary MD5 work. The same upload
proof used by the real test is retained. Final 51 Drive/native checksum checks
passed after this selection change (63 s). Additional 41 replica/recovery/state
checks passed (29 s). Counts overlap preceding batches.

Strict format: 912 lib/test files unchanged (12.02 s), analyzer clean (41.6 s).
Final Windows 1.0.11+12 built in 118.3 s and Android in 125.0 s. Windows AOT
freshness verified. APK org.orbitnote.app.preview, code 12/name 1.0.11, existing
signing certificate verified; 140,134,210 bytes / SHA-256
c97d6e064bef24e807978fa675faf19af66b82ad3df94c7ffd699d811a5650b4.
Owner closed PC app for replacement. Prepare complete locally built installers
for GitHub as in the preceding update, with source provenance/checksums and no
build workflow. Retain full-snapshot wire-size and Google propagation limits;
next possible task is a reviewed incremental payload design for very large Canvases.

1.0.11 app source ce99add and six verified release assets were published at
https://github.com/iax32/Orbit-Note/releases/tag/preview-1.0.11-2026-10-29;
tag/source and all uploaded sizes/SHA-256 matched, zero workflow runs.
Final boundary review then identified a cached retry receipt returning after a
pause, before reaching a network/staging check. The application state-store guard
already rejected stale checkpoint writes, but the provider now checks current
ownership/account at publication entry too. Six focused tests pass, including a
paused fresh-preflight retry that must fail without a network request, unchanged
request budgets and lost-ack recovery. No Google re-consent or schema change is
needed for this one-line guard. Shipping as 1.0.12+13 to preserve 1.0.11 tag and
artifact provenance.

Final release completion (verified 2026-10-30): Windows 1.0.12+13 built in
144.4 s; Android in 138.8 s. Normal Windows run folder reports 1.0.12+13 and
AOT freshness was verified. APK org.orbitnote.app.preview, versionCode 13 /
versionName 1.0.12 retains the original preview signing identity; 140,134,210
bytes / SHA-256
0efaa5d15b1a424cc856c2ebcf9b0f6204f29c011a6afa12512204f582a3b1a0.
Installer: 27,371,903 bytes / SHA-256
afe3d541f03e5c7d43428ff2b873b9ac1139607ea15ef5b1fba24837689209d3.
Final strict formatting: 912 files unchanged (10.76 s); analyzer clean (44.3 s).
Published app source/tag feacc9ab05203e434858b73d394b7b10233a5e6d:
https://github.com/iax32/Orbit-Note/releases/tag/preview-1.0.12-2026-10-29
All six uploaded asset sizes/SHA-256 hashes verified against local packages;
published tag matches app source, zero GitHub workflow runs for that commit.
The final checksum selection and pause-guard refinements were covered by the
focused local checks above; the real Drive run preceded those refinements.
No additional Google consent or personal Vault access was needed.

Batch complete. Remaining limits: physical tablet acceptance has not been
performed for this release, Drive indexing/network delays remain, and very
large Canvas changes still transfer full-file payloads. Suggested next task:
reviewed incremental large-Canvas payload transfer; no such migration is made here.
