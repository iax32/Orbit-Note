# Background Drive and reviewed retention — 2026-10-25

Owner requests closing the device-sync gaps. No Android device is available.
Scope SYNC-02/03/04/05/06/07/08/16; preserve unrelated PDF/UML changes.

## Implemented

- Explicit selected-Vault background enrollment in existing Drive settings.
- Hidden Windows worker with user-scoped 15-minute Task Scheduler registration;
  no password/admin request, task installs only on the user's Enable action.
- Android persisted network JobScheduler service, separate process, silent
  previously approved account authorization, foreground priority and OS retry.
- Same native locks, account binding, durable outbox/staging and conflict review
  as foreground sync. Workers never create new bindings or enable paused ones.
- Device-only background outcome report; no credentials/content in reports.
- Reviewed obsolete-payload cleanup: 90-day/20-version protection, current-head
  preservation, no cleanup with forks, immutable receipt before deletion,
  protocol negotiation and interrupted-delete recovery. Graph metadata stays.

## Validation

- `flutter test --no-pub` on background runner, Drive retention, Vault batch,
  Drive provider and device continuity: **78 passed**, 88 seconds. This includes
  two native repositories, 1,000-revision inventory/change-feed behavior,
  interrupted ranged attachment transfers, account switches, shared reconnect,
  lost acknowledgements and conflict preservation. It is not the whole suite.
- New worker tests cover explicit opt-in, missing/paused bindings, native lock
  ownership, duplicate-free restart, offline retry, account removal and malformed
  future/duplicate enrollment. An initial fixture save omitted its required
  state-load; corrected, then reran the complete focused set successfully.
- Retention tests cover current-version download after cleanup, 20-version
  retention, receipt-before-delete/protocol upgrade, lost delete acknowledgement
  resumed with one receipt, stale review, forks, recent/unknown dates, incomplete
  lists, foreign metadata and unknown protocol-3 variants.
- Windows release compiled with registered desktop OAuth client. Hidden worker
  with background opt-in absent exited **0**, without opening a window or syncing.
- Native Task Scheduler accepted a temporary **disabled** task definition; query
  confirmed it disabled and it was removed immediately. No job executed. This
  caught/fixed the UTF-8 XML registration failure: use BOM-marked UTF-16 and handle
  UTF-16 task-query output independently of console encoding.
- Static analysis clean; final strict formatting/build checks recorded in local
  `.local/sync-*.log` evidence (ignored, no account tokens in reported output).
- Android build attempted: **blocked, No Android SDK found**. No APK from this
  change has been produced or claimed tested.

No production background task was installed; no personal Vault was uploaded or
pruned. Only synthetic HTTP-service payloads were deleted by maintenance tests.
Task registration is validated, not a real Google-account background transfer.

## Remaining acceptance / scope boundaries

- Physical Windows-to-Android test cannot run: owner confirms no device.
- Android SDK/JDK is absent at the remembered and standard local locations;
  native Android compilation/runtime must be reported separately from Dart tests.
- Real Google silent Android grants and deployed network/power restrictions need
  device testing. Android OAuth registration still needs a suitable app client.
- OS scheduling is best effort, not closed-app real-time delivery. Shared editing
  is foreground-only; this worker is personal Drive sync.
- Graph metadata compaction and the 10,000-record bound remain. Payload retention
  reclaims old bytes without pretending it safely deletes graph history.

See [ADR-0033](../adr/0033-background-drive-and-payload-retention.md).
