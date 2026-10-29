# Pen responsiveness and simple cross-device sharing

Owner requests smooth PC/tablet drawing without removing features/visuals,
button-driven reliable hosting and fast, simple device sync. Scope: INK input
and CAN live rendering; SYNC initial import, connection setup and transport.
Preserve the preceding audit batch, portable bytes, object IDs, reviewed imports,
history/conflict safeguards and Advanced hosting. No new storage schema.

Implemented local batch:
- Local live-ink preview uses a read-only view of its gesture-owned samples,
  avoiding a whole growing-stroke list allocation each frame. Committed ink is
  still independently frozen through normal history/persistence.
- Stylus takes capture from an earlier provisional palm/touch gesture; later
  palm contacts cannot cancel it. Pressure changes survive distance filtering.
- Android shared join, Drive open/restore and batch downloads choose writable
  app-owned Vault storage rather than returning an unusable document-tree path.
- Large shared payload JSON and backup validation run away from native UI input.
- The managed HTTP/merge/journal server itself runs in a dedicated native worker.
  It drains on stop, retains durable identity on explicit restart, stops the relay
  on failure and cannot place its server data within a Vault.
- Lossless response gzip and a 32-MiB document cap replace the restrictive 2-MiB
  limit that rejects large ink boards. History retains up to 32 bases/64 MiB;
  128-MiB room metadata and existing decoded response/import limits remain.
  Native clients also compress non-presence requests after an optional response
  header advertises support. Old hosts receive plain requests. Server input limits
  count encoded and decoded bytes, so compression cannot bypass resource limits.
- Shared setup displays phases, validates complete invitations before networking,
  offers visible optional secure automatic reconnect and cancels address setup
  promptly. Manual hosting and relay disclosures remain available.

Native isolated 96k-sample/400%-zoom replay: long-stylus build P95 .431 ms,
raster P95 1.340 ms / worst 2.047 ms; long mouse raster P95 4.191 ms. No drawing
stage 10-ms misses, errors [], one committed synthetic stroke. Pan retains one
19.19-ms raster spike. This is a 100-Hz isolated replay, not full-app or physical
stylus/180-Hz acceptance. Compared with the preceding run (stylus raster P95
1.807 ms), these are individual runs, not a statistically proven percentage win.

Focused batches: 94 pen/fidelity/import/live recovery checks, 56 final Drive/
Android/sharing checks, 28 worker-transition/live checks, eight worker lifetime/
restart/UI checks; overlapping counts, not unique test totals. Real synthetic
HTTPS transfer with server worker and bounded awareness: 13 checks passed in
13 s. Earlier real relay check before worker change passed in 11 s. Strict
format/analyzer results above precede the final compression addition. Final
format: 910 lib/test files unchanged (8.07 s); analyzer clean (31.2 s).
Final 35 checks cover >2-MiB documents, compressed byte-exact responses,
restart, normal protocol and genuine 390px/200%-text controls. An old narrow
test lacked ProviderScope and applied its MediaQuery below the route; fixed its
test host and real view dimensions before obtaining the pass. No production
layout behavior was weakened to satisfy it.
Final 37 checks (15 s) include actual HTTPS with negotiated request/response
compression, full Canvas/asset delivery, awareness, worker lifetime, legacy
behavior, replay/recovery and rejecting a compressed body over its decoded limit.

Representative local gzip verification on the private board JSON fixture:
14,365,022 -> 1,148,838 bytes (92.0% smaller), identical SHA-256 after decoding.
This uses .NET gzip, 100.1422-ms encode wall time, to measure payload
compressibility, not an end-to-end app/network latency guarantee. Native encoding
and server compression run away from UI pen input. Full snapshots still bound
transfer/merge cost; no delta/CRDT replacement or arbitrary-size claim is made.

Final Windows 1.0.10+11 built in 105.8 s, Android in 116.6 s. Windows AOT is
newer than all lib sources and standalone server exists. Android package
org.orbitnote.app.preview, code 11/name 1.0.10, existing certificate verified;
APK 140,101,442 bytes, SHA-256
0895590f898b4d5584afee20316d2f0810619cb4a9c1d05cfccc8b5b51896aaa.
Owner explicitly requests GitHub publication for installation on Lenovo.
Release preparation: preview-1.0.10-2026-10-29; skip CI commit marker, no build
workflow dispatch. Publish complete installer/APK with provenance and checksums.

Lenovo available on 1.0.8; prepare matched current builds
before physical acceptance. No guarantee of zero latency, third-party uptime or
closed-app real-time sync. Do not mark physical stylus/network acceptance complete
from synthetic tests. Do not modify personal Vault data for benchmarks.
