# Device sharing, existing Vault uploads and imports

Owner reports server failures, slow existing-Vault uploads, confusing import
names and remaining drawing stalls. Clarification: both devices connect and show
pointers, but pen previews flash/disappear and committed drawings do not arrive.
Scope: existing SYNC/PORT/INK reliability, preserved original bytes and visuals;
no unrelated feature expansion or broad multi-thousand-test run.

Confirmed mismatch: the host permits 32-MiB documents, while the client recovery
journal was capped at 16 MiB and stores common bases plus outgoing snapshots.
A roughly 9-MiB Canvas can connect, then exceed that cap on its next edit. The
outbox blocks durable publication while transient presence continues. Do not
equate successful pointer delivery with successful saved-content replication.

Implemented changes:
- Large native shared checkpoints use bounded lossless compression on a worker;
  legacy JSON remains readable, small checkpoints stay plain JSON. Original
  snapshots and uncertain operation IDs remain recoverable. Decoded limit is
  256 MiB; stored limit remains 16 MiB. All compare-before-write and current
  session guards remain, including a fresh guard after asynchronous encoding.
- Unchanged-checkpoint detection uses immutable operation identities and document
  versions instead of repeatedly encoding/hashing every point in the Vault.
  Local performance logging records numeric shared-cycle/checkpoint durations.
- Small Drive files (up to 256 KiB) use create-only multipart transfer with exact
  size/checksum/identity proof and validated readback fallback. Large files keep
  resumable uploads. Durable generated-ID reservations amortize allocation over
  16 publications. No cloud schema or authored byte change.
- Active and bulk sync show file counts/current file; bulk progress no longer
  jumps from zero to complete for every individual file.
- Imports use the source Vault's name with numbered collisions on Android and
  desktop. Existing folders/source identity/recovery protections remain. The
  review distinguishes managed Android storage from desktop location choice.
- Optional private Tailscale and owned HTTPS routes start the existing managed
  host without scripts; temporary relay remains available. Tailscale requires an
  installed, connected network on both devices and HTTPS approval. Orbit does
  not install it or change router/firewall settings. Own-address mode binds only
  loopback port 47831 for the user's existing HTTPS proxy. Readiness verifies the
  fresh non-secret host incarnation against loopback, refuses redirects and
  checks ready=true. Owner keys remain on the PC.

Validation: 126 focused Drive/controller/batch/recovery/import/live checks passed
(65 s), including the large-board two-author case crossing the previous recovery
cap. A further 13 host-worker/pen-fidelity/logging checks passed (2 s); the real
temporary relay check was skipped, not counted as acceptance. Nine Android import
unit checks pass (0.238 s execution, 57 s Gradle build). The first attempted
release-unit-test task does not exist in this project; the enabled debug test
variant was then used. Analyzer clean (21.2 s); strict format 917 lib/test files
unchanged (8.94 s). No full multi-thousand-test suite.

Ten-note publication request count is 48 versus 80 in 1.0.12 (40% fewer); receive
remains 34 requests with exact transferred bytes. A 28,800,165-byte recovery state
round-tripped exactly in 70,076 stored bytes, including unknown fields, restart
and stale-writer refusal. Small legacy JSON still reads as before. Disconnect
during encoding cannot write a stale checkpoint.

Native AOT synthetic 96k-sample checkpoint probe: foreground duplicate JSON/hash
work 697,346 us wall/caller gap; worker 510,812 us wall, caller gap 84,700 us.
This one run demonstrates less foreground blocking, not zero stalls or physical
stylus latency. Large graph handoff/full-snapshot transfer costs remain; pen
pixels for all nibs are unchanged. The new diagnostics distinguish shared pump
and checkpoint costs without storing note text, paths or session credentials.

Published Windows/Android 1.0.13+14:
https://github.com/iax32/Orbit-Note/releases/tag/preview-1.0.13-2026-10-30
App source/tag ff30c4cea4585e8a55ec57ed363741581b2257d5. Windows built in
103.6 s, installer packaged in 16.531 s; normal run folder version/AOT freshness
verified. Android built in 145.6 s; org.orbitnote.app.preview, code 14/name 1.0.13,
original signing certificate verified. APK 140,347,202 bytes / SHA-256
765ebb1f3790769abd4a738a8a20bc963952f844d9a0bc8ffbf4b1d053f58a03;
installer 27,381,892 bytes / SHA-256
618c0908d9c15f52327e1642d404bc8c324ab305bc1419115f9ae7b4777c7cbc.
All six uploaded asset sizes/SHA-256 hashes matched local packages; published
tag/source matched, zero GitHub workflow runs for app source. Only private tmp/
PDFs remain untracked; no fixtures/logs/credentials were packaged or committed.

Implementation/release batch complete. Physical owner PC/tablet acceptance
remains pending: update both clients, stop the old session, start again and join
with a fresh invitation. Real relay/Google network acceptance was not rerun for
this batch. The new private Tailscale route is covered by controlled lifecycle
checks, not enrollment or physical-device acceptance. Google delays, full-file
transfer costs, stored/decoded journal bounds and the measured 84.7-ms native
handoff gap remain material limits. Suggested next task: incremental large-Canvas
payloads and checkpoint worker handoff to reduce the remaining snapshot spikes.

Owner follow-up: the 1.0.13 physical replay is still unsatisfactory. The owner
explicitly sets further sync/server work aside for now and requests a Canvas
focus toolbar swap instead. Do not record physical acceptance as passed or
continue networking work under that new layout task.
