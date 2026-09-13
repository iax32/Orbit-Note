# Current cloud task — M6 local-first sync

Status: P0 foundation and native replica adapter implemented/tested; cloud connection is not
yet delivered. Full owner prompt received 2026-09-12. Its archive, conflict,
security and platform requirements supersede the earlier truncated brief.

## Completed in this pass

- Native Vault ownership lock, checked deletes, recoverable permanent-delete
  intent and portable tombstones. Missing files never imply remote deletion.
- Canonical inventory with stable identities, exact content hashes, streamed
  attachment hashing, collision/path validation and explicit exclusion policy.
- Provider-neutral reconciliation with durable device-local base, outbox,
  operation IDs, remote mapping, cursors and conflict descriptors.
- Separate installation identity; no tokens or index files enter portable data.
- Fake-provider tests covering offline replay, concurrent edits, deletion/edit,
  missing files, moves, interrupted acknowledgements and failed checkpoints.

## Validation — 2026-09-12

- `dart format lib test tool` and zero-change formatting check passed.
- `flutter analyze --no-pub`: clean.
- `flutter test --no-pub`: **297 passed**.
- `flutter build windows --release --no-pub`: passed, 31.7 seconds.
- Logs: `.local/sync-p0-final-tests.log`, `.local/sync-p0-final-windows.log`.
- EXE: `build/windows/x64/runner/Release/orbit_note.exe`; distribute its complete
  Release directory, not the EXE alone.

- Windows smoke launch passed: release process remained running after four
  seconds and was closed afterward. This checks startup, not visual/cloud flows.
- `flutter build apk --debug --no-pub`: passed, 201.5 seconds. Artifact:
  `build/app/outputs/flutter-apk/app-debug.apk`; log `.local/sync-p0-android.log`.
  Existing `desktop_drop` and `pasteboard` dependencies emit a future Flutter
  Kotlin Gradle Plugin compatibility warning. No Android device run was performed.
- Final analyzer evidence: `.local/sync-p0-final-analyze.log`, no issues (8.7s).
- Documentation relative links, tombstone schema JSON and `git diff --check` passed.

These are local/fake-provider checks, not real Google account or two-device
cloud acceptance.

## Repository adapter continuation — 2026-09-12

Completed native `WorkspaceSyncReplica`, streamed device-local staging, hash-checked
publication through the existing history/journal, exact object/manifest source
preservation, Notes move recovery, remote deletion recovery, durable local/remote
conflict copies, controller draft guards and Vault-bound checkpoint serialization.
Network downloads do not hold the local save queue. Index/controller objects refresh
after apply. No real provider or Settings connection has been added.

Added 20 tests in `workspace_sync_replica_test.dart` and
`native_sync_staging_test.dart`. Tests use actual native Vaults with a fake server,
including a stalled download while a local save succeeds, stale Vault sessions,
competing edits, exact before-images, corrupt downloads, rejected staging, Notes
moves/lost acknowledgements, deletion interruption/reopen and binary attachments.

Validation: format plus zero-change check passed; analyzer clean (7.3s); all **340
tests passed**; Windows release build passed (43.8s); startup smoke passed (four
seconds running, then own process closed). Logs: `.local/sync-replica-final-analyze.log`,
`.local/sync-replica-final-tests.log`, `.local/sync-replica-final-windows.log`.
Android debug APK also built successfully (28.3s), log
`.local/sync-replica-final-android.log`; no phone/cloud acceptance run. Existing
clipboard/drop plugin Kotlin compatibility warnings remain. Documentation links
pass. Whole-worktree `git diff --check` reports trailing spaces in concurrently
added Markdown template strings in `workspace_controller.dart`; their content was
preserved. Dart formatting/analyzer/tests above pass.

## Next bounded implementation task

Implement Google Drive's provider/auth integration against this tested local boundary.
Required reads: [architecture](../architecture/sync.md),
[delivery status](../features/cloud-sync.md),
[ADR-0017](../adr/0017-sync-foundation-safety.md),
[Google setup](../development/google-drive-sync-setup.md), provider/engine contracts
and native replica tests. First prove conditional publication/write-race behavior;
do not emulate atomic compare-and-set with an unguarded GET/PATCH pair.

Use the controller's `createSyncReplica()` and its `createStateStore()` together.
Keep OS-protected auth out of Vault data. Add initial upload/new-device download,
Drive-ID mapping/Changes feed, resumable blobs, scheduling and real Settings/status
flows incrementally. No dead Connect button. Live acceptance requires configured
OAuth clients and real Windows/Android account tests.

Folder Archive currently lives in device settings. Inventory blocks sync readiness
when present until portable organization metadata is migrated safely. Empty folder
transfer and application commit/foreground scheduling also remain unfinished.

Then finish Google Drive auth/provider, conditional publication, resumable blobs,
initial upload and new-device download, Settings/status/conflict UI and real
Windows/Android acceptance. WebDAV follows functioning Drive. Do not advertise a
working Connect action before these flows work.
