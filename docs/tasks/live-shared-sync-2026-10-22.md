# Live shared sync — 2026-10-22

Owner requested the previously listed missing new/deleted-object, attachment,
coauthoring/caret and device/background work. Owner has **no second device now**;
use synthetic isolated local clients. No desktop-control testing or private
account/Vault transfer. No persistent host/service installation or shutdown.

## Delivered

- Negotiated live rooms: continuous owning objects, Trash/restore and permanent
  tombstones; verified resumable chunked assets before their referencing owners.
- Durable device outbox for common bases, creations and uncertain edits; role,
  epoch/opening/draft/CAS and local recovery/history boundaries remain.
- Authenticated long-poll wakeups, bounded local scheduling and timer fallback.
- Multiple independent character edits merge; conflicting overlaps require review.
- Source-hash/UTF-16 note selections and named carets in Rich/Source, with stale
  range fallbacks and Canvas pointer wakeups. No selection/layout mutation.
- Optional secure remembered reconnect on launch/resume, explicit disconnect
  suppression; accurate new/lifecycle pending counts and legacy-room guidance.
- Unchanged heartbeats avoid recovery-journal writes. A failed/oversized checkpoint
  blocks publication with a storage/recovery status, preserving local work for retry.
- Unknown data and old authored storage retained. Legacy rooms remain legacy;
  unaware clients cannot silently enter live rooms. Private journal checkpoint
  before new record kinds. See [ADR-0032](../adr/0032-live-shared-vault-replication.md).

## Validation

Focused tests cover synthetic two clients, identity/Unicode, Trash/restore/remove,
large attachment dependency ordering, interrupted upload/download staging, lost
creation/edit acknowledgements across restart, offline edits, rollback/restart,
authenticated event waits, viewer/revocation, legacy gating, private checkpoint,
secure opt-in reconnect, stale ranges and source/Rich overlays/large layouts.

24 added regressions; final focused matrix **76 passed** (4 sec), including the
existing Canvas placement-review, domain, recovery and native-staging cases.
The old unknown-base reconnect test now explicitly removes the device journal:
normal live reconnect retains a real base rather than inventing one.

- `dart format lib test`: **731 files**, clean after formatting.
- `dart format --output=none --set-exit-if-changed lib test`: **731 files, zero changes**.
- `flutter analyze --no-pub`: **no issues**, 6.7 sec.
- `flutter test --no-pub`: **2,915 passed, 2 existing skips**, 5:28.
- `tool/build_windows.ps1 -Flutter <configured SDK>`: Windows release **passed**,
  75.9 sec; matching standalone server compiled and packaged. Registered Google
  desktop client is present in the new AOT payload.
- `flutter build web --release --no-pub`: standard JS release **passed**, 74.2 sec.
  Existing SDK Wasm dry-run interop and missing Cupertino-font warnings remain;
  no Wasm support is claimed by this build.
- `flutter build apk --debug --no-pub`: **blocked before compilation** — no
  Android SDK found. No APK rebuilt; no mobile runtime validation claimed.

**877 frozen implementation/test/platform/asset inputs unchanged** through
packaging. Seven runtime/host files present and hashed; **13 authored fonts**
match their packaged bytes. Compiled host smoke check used a new private temporary
directory and ephemeral loopback port, verified health, denied unauthenticated
private-info access, and verified live capabilities. Only that owned process was
terminated and its synthetic directory removed; no persistent host was started.
The desktop app was not launched or controlled.

Runnable Windows app: `build/windows/x64/runner/Release/orbit_note.exe` with sibling
runtime files. Matching host: `collaboration/OrbitNote-Server.exe` and launcher in
that release folder. Existing shared rooms remain legacy; create a new room with
this updated app/host for live replication. Back up the complete private server
directory while stopped before upgrade; no real host data was modified here.

Detailed local logs: `.local/shared-live-focused-final.log`,
`.local/shared-live-full-final.log`, `.local/shared-live-analyze-final.log`,
`.local/shared-live-format-strict.log`, `.local/shared-live-windows-build.log`,
`.local/shared-live-web-build.log`, `.local/shared-live-android-build.log`,
`.local/shared-live-packaged-host-smoke.log`, and
`.local/live-shared-release-verification.json`. All test Vaults, endpoints, grants and
assets were synthetic; ephemeral localhost servers closed after each test.
No desktop control, private account transfers, publication or shutdown.

## Remaining

No closed-app Windows service or mobile OS workers. Arbitrary same-character
CRDT coauthoring is not implemented; bounded three-way merge refuses overlaps.
Physical Windows-to-Android, mobile runtime/background and deployed HTTPS checks
remain unperformed. Android SDK is absent. Existing personal Drive behavior is
unchanged in this task. Old live host journals require the updated server; stop
and preserve the complete private host directory for recovery. Owner-file moves,
oversized snapshots/checkpoints and storage compaction retain explicit limits.

Next suggested task: implement constrained mobile background jobs and validate
Windows-to-Android transfer on a physical device when SDK/device access exists.
