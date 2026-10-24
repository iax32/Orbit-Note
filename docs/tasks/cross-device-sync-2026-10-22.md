# Cross-device sync audit and improvement — 2026-10-22

## Verdict

Orbit does **not** have verified OneNote-level cross-device/coauthoring parity.
This audit covers the actual controllers, native replica, immutable Drive adapter,
Google auth scopes, server transport and failure tests. A five-second polling
interval is not a guarantee of five-second delivery or real-time text merging.

| Area | Implemented source behavior | Remaining boundary |
|---|---|---|
| Personal Drive | Opt-in account/folder/Vault binding; exact note/Canvas/object/attachment transfers, Archive/Trash owning files, permanent-deletion tombstones, offline retry, restart checkpoints | Runs while app is available; Android physical-device acceptance and public OAuth rollout incomplete |
| Divergent edits | Immutable parent graphs, retained alternatives, explicit compare/resolution, draft/opening guards | No character-level CRDT; simultaneous edits may require review |
| Attachments | Streamed verified stages, SHA-256/MD5, ~1 MiB upload chunks, durable resumable session/status probes, final integrity verification | Interrupted downloads restart; no lazy/pinned policy or automatic revision/blob GC |
| Active Vault | Five-second remote feed checks, earliest two-second saved-edit scheduling, ~30-second normal local reconciliation, foreground checks | Scheduling only; unavailable network, drafts/conflicts, backoff and OS suspension delay delivery |
| Other Vaults | Explicit bulk upload/download and account-bound selected inactive schedule | Inactive checks remain 1/5/15 minutes; not every Vault every five seconds |
| Shared host | Existing-document/Canvas editing, known-base merge, capability roles, pointers/placement selections, host-epoch restart guards | 500-ms HTTP polling; continuous new objects/deletions/attachments and text carets/CRDT incomplete; Drive pauses during shared authority |
| Platforms | Windows and Android auth adapters; shared core compiles for JS web | iOS/other auth fallback is not a working Drive sign-in; web compilation is not native-folder sync acceptance |
| Scale | Validated paginated complete graph and bounded journals, 1,000-revision stress regression | 10,000 retained revisions, 16 MiB state/journals, 64 resolution parents, 32 MiB structured source/2 GiB blob limits; no revision compaction |

No private Vault, account token, cloud upload or desktop UI automation was used in
this run. Prior live Google acceptance on two isolated local clients is historical
and does not validate this new feed implementation against a live account. Real
physical devices, Android suspension/resume and deployed TLS still need acceptance.

## What changed

- New `google_drive_changes.dart` uses `changes/startPageToken` and paginated
  `changes.list` with `drive.file`, My Drive and removal/corpus-removal metadata.
  No expanded permissions, credentials, provider, package or backend was added.
- The existing v1 device upload journal adds optional `changeFeed` metadata:
  complete revision IDs, token and last full-audit time. Old journals bootstrap;
  unknown extensions and operation identities survive. No authored format changed.
- Capture the start token **before** a full listing; a concurrent publication not
  in the list replays through the feed. Fetch all pages, validate checksum/routing,
  ownership, removals, parents and forks, then checkpoint. Failures do not advance.
- The engine still receives a complete reset snapshot even though Drive discovery
  is incremental. A feed checkpoint before an interrupted local apply cannot hide
  that unapplied source on retry. Known missing revisions are never tombstones.
- Full cloud audits occur every 15 minutes, on missing/rejected checkpoints and
  clock rollback. Normal Drive tokens do not expire; HTTP 410 fallback is defensive.
  Unchanged feed checks do not re-list history, read record media or rewrite the
  journal. A new record in the 1,000-revision test reads only that record's payload.
- Active-Vault polls run every five seconds; unchanged checks between normal local
  inventories avoid attachment rehashing. Manual/foreground, pending local work,
  changed cloud state and ~30-second integrity checks run the normal engine.
- Frequent edits retain the earliest scheduled two-second pass. Account/access
  blocks, retry deadlines, per-Vault pause and shared/Drive exclusion remain.
  Progress and separate last-cloud-check/full-sync times are visible in Settings.

## Google API findings

Google documents incremental discovery in [Retrieve changes](https://developers.google.com/workspace/drive/api/guides/manage-changes)
and the [changes.list reference](https://developers.google.com/workspace/drive/api/reference/rest/v3/changes/list).
`drive.file` supports these endpoints; broader access to unrelated user files is
unnecessary. Pagination tokens are opaque and must not be interpreted as file
versions or mutable-write compare-and-swap preconditions.

[Push notifications](https://developers.google.com/workspace/drive/api/guides/push)
require a reachable HTTPS webhook, expiring watch channels/renewal and subsequent
Drive API reads; they do not deliver document edits to a desktop socket or provide
Google Docs coauthoring semantics. No pretend direct-desktop push was added.
Existing [resumable uploads](https://developers.google.com/workspace/drive/api/guides/manage-uploads)
already use session probes and persistent generated IDs; the new middle-range test
confirms actual offset reuse after a lost chunk acknowledgement.

## Validation

20 new regressions; focused suite **104 passed** (46 sec), including existing
bulk transfers, device scheduling and host restart/recovery tests. Cases include:

- Empty/omitted change arrays, complete multi-page discovery and 1,000 revisions.
- A failed later page, repeated pagination token and missing final checkpoint.
- Restart, rejected token fallback, old journal compatibility and unknown fields.
- Publication during baseline listing; independent local-apply failure/replay.
- Moved/trashed/tampered retained revisions, malformed parent graph and account
  change while awaiting a page; unchanged checkpoint and source bytes on failure.
- Two-client divergence/branch resolution, exact source/attachments, moves and
  tombstones, dirty drafts, pause and shared authority guards.
- Mid-file upload interruption resumes at 1 MiB without a second upload session.
- Continuous typing uploads before typing stops; idle checks do not rewrite a
  large journal; lightweight checks preserve full-sync timestamps/access blocks.

Final checks: `dart format lib test` and strict format check clean across **725
Dart files**; `flutter analyze --no-pub` clean (**6.2 sec**). Full
`flutter test --no-pub --reporter expanded`: **2,891 passed, 2 existing skips**
(**5:08**), including opt-in Google live acceptance remaining skipped.

Configured Windows app and standalone host builds passed (**77.3 sec** app build);
Google desktop client identity was verified inside the built AOT payload without
printing its value. Standard JS web release passed (**76.9 sec**), with existing
Google SDK Wasm dry-run and Cupertino-font warnings. Wasm was not validated.
Android debug compilation was attempted and blocked before compilation: **No
Android SDK found**, exit 1. Configured SDK path is missing, and no SDK/JDK was
installed or APK published. Android device behavior remains unvalidated.

**772** frozen source/test/tool/asset inputs unchanged after all checks/builds;
seven runtime/AOT/host files and **13 authored font hashes** verified. Full scoped
whitespace checks passed. Prior uncommitted sync/publishing work was retained.
No app/host launch, desktop-control testing, private Vault/account access, cloud
upload, OAuth registration change, GitHub publication or shutdown occurred.
Raw logs and frozen input hashes are in `.local/sync-upgrade-*` (ignored).

Run `build/windows/x64/runner/Release/orbit_note.exe` with its sibling runtime
files. Existing enabled Vaults retain their account-bound opt-in; other Vaults
still require explicit setup.

## Next suggested task

Complete shared-Vault replication for new/deleted objects and attachments, with a
push event transport, before presenting shared sessions as a complete live Vault.
Then require real Windows/Android two-device acceptance for public sync claims.
This task stops before that protocol expansion.
