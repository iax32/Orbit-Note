# Cloud sync — delivery status

## Loose documents and media — 2026-10-24

PDFs and common document/media formats can sync from the Vault root or nested
folders, including outside `Attachments/`. Extensions are case-insensitive.
The explicit policy covers PDF, text/Markdown, RTF, CSV/TSV, Office/OpenDocument,
EPUB, common images/audio/video, and GLB/GLTF/OBJ/MTL/STL/FBX/Blend assets.
Files retain their exact paths and bytes as streamed, checksum-verified blobs;
this does not import them as Orbit objects or invent new object IDs. Personal
Drive uses the existing conflict/recovery engine for subsequent changes.

Shared snapshot creation and live attachment enumeration use the same policy.
Shared attachments retain immutable-path behavior: differing bytes at an existing
shared path require review rather than overwriting another device. Upgrade both
clients and the host for loose-file support; older clients reject unfamiliar paths.
Ordinary external file absence still does not imply a deletion.

Internal/device/cache/recovery exclusions, portable-path/collision checks,
transfer limits and draft guards remain. Unknown formats and loose hidden/config
files still block complete-sync claims; they are not silently omitted or uploaded.
Arbitrary JSON, credentials and executable/script projects are not automatically
added by this document/media policy. Existing explicit `Attachments/` imports retain
their original rules. No account permission expansion or storage migration.

## Incremental personal sync — 2026-10-22

Active native Vaults check the Drive changes feed every **5 seconds** while Orbit
runs. Saved edits retain the earliest **2-second** scheduled pass even during
continuous typing. Cheap unchanged-cloud checks avoid a full local inventory;
normal local reconciliation still runs about every **30 seconds**, including
external file edits. Full cloud history audits run every **15 minutes**, on
missing/rejected checkpoints and after a backwards clock. These are scheduling
intervals, not end-to-end delivery guarantees; network, drafts, conflicts and
backoff can delay transfer. Inactive selected Vaults retain their 1/5/15-minute
schedule. Manual Sync now and foreground return perform normal reconciliation.

The account/Vault-bound upload journal stores a complete revision membership and
Drive cursor together. Every page and graph parent must validate before advancing.
A baseline token is taken before listing so racing publications replay. Failed
pages, lost access, modified/missing retained records and uncertain local applies
never skip content or silently choose a branch. Unchanged checks do not rewrite
the journal. Existing narrow `drive.file` access and resumable attachment uploads
remain; Settings exposes upload bytes and separate cloud-check/full-sync times.

**This is not OneNote-level acceptance or character-level Drive coauthoring.**
Separate negotiated [live shared rooms](sync-and-collaboration.md) now add new/
deleted objects, verified assets and source-checked carets. Closed-app/mobile
workers, arbitrary-overlap CRDT, public OAuth rollout and physical two-device
acceptance remain unfinished. Personal Drive limits include 10,000 retained revisions, 16 MiB checkpoints and no
revision garbage collection. Frequent edits consume retained cloud storage.
[Source audit and actual checks](../tasks/cross-device-sync-2026-10-22.md).

The dated sections below record earlier deliveries; the foundation table is
historical and does not describe today's personal-sync controls.

## Foreground synchronization recovery — 2026-10-21

Drive retains changes made while a transfer or exclusive sync action is busy,
then coalesces a follow-up pass. A completed older pass does not label newer local
edits up to date. Transient failures schedule their actual retry deadline rather
than waiting for the general 30-second poll. Pause cancels those requests.
Returning to the app checks the active opted-in Vault; checks requested during
an active pass are retained. Account/access blocks and shared-session suspension
remain authoritative; a foreground event never enables sync or changes accounts.
Settings show newer queued edits and the next retry time. Background execution
and physical-device acceptance are still outside this validation.
[Evidence](../tasks/device-sync-recovery-2026-10-21.md).


2026-10-15 continuity extension: successful bulk transfers can explicitly add
selected inactive Vaults to a secure device-local schedule, checked every 1/5/15
minutes while Orbit is open. Manage scheduled Vault checks exposes status,
selection, pause/resume, check now and forget. The selected Google account,
existing native locks and per-Vault pauses remain authoritative. Shared connection
setup/connected sessions suspend Drive. This uses the existing batch/engine and
does not install an OS service. See [usage](../development/google-drive-sync-setup.md)
and current task for validation; physical-device acceptance remains separate.

2026-10-15 bulk transfers: Settings → Sync offers **Upload multiple Vaults** and
**Download multiple Vaults**. Native selection includes recent/current Vaults,
an explicit Vault folder, or shallow discovery inside a chosen parent. No default
selection or automatic personal-data upload. Sequential transfers reuse existing
binding, provider, outbox, verified staging and conflict recovery. Per-Vault
results, cancel/retry, same-UUID copy guards and account/opening invalidation
preserve partial progress. Downloads create separate folders, register recents
without changing the active selection, and retain sync bindings. Automatic sync
runs for the active Vault; opt-in scheduled checks can update selected inactive
Vaults. Without that opt-in, explicit batches update inactive Vaults.
Newer bindings/locked folders need attention rather than replacement. Actual
validation evidence is in the current task; prior single-Vault real-account
acceptance does not itself validate this new batch UI against a live account.

2026-10-15 automatic native preview: Settings → Sync now offers explicit automatic
personal Drive sync, separate from independent backups. It synchronizes authored
notes, boards, other owning objects, attachments and explicit deletion records
through SyncEngine/WorkspaceSyncReplica. Opt-in is bound to the Google account and
exact Vault/folder identity, survives restart, debounces local work and polls while
Orbit is open. A local-only startup reads the saved opt-in before creating account
services. Pause retains local files and remote revisions. Shared Vault temporarily
pauses personal sync to avoid two remote authorities applying simultaneously.

Concurrent publications use immutable Drive blobs/revision graphs, not unchecked
PATCH. Multiple heads and local/remote divergence stop for compare/review; previous
versions remain available in local recovery and Drive. Choosing this device or a
cloud version appends a reviewed resolution. Newer local edits invalidate stale
reviews. Browse synced Vaults can open an identity-checked cloud manifest into a
new local folder and start verified downloads. Missing cloud revisions, altered
checksums, unsupported formats and unsafe paths stop without deleting local work.
See [ADR-0030](../adr/0030-immutable-drive-revisions.md) and
[usage/limits](../development/google-drive-sync-setup.md).

Limits: native folders, foreground app lifetime, 2 GiB per attachment/32 MiB per
structured source, 10,000 retained revisions, 64 parents per resolution and existing
16 MiB operational checkpoints. Empty folders and device settings/history/caches
stay local. Device-only folder Archive metadata blocks setup explicitly. Some
non-Notes physical moves and restore-over-permanent-delete transitions still need
manual recovery. Retained cloud versions are not garbage-collected. Public OAuth
rollout, Android activation and physical two-device acceptance remain release
gates. Real-account acceptance passed on 2026-10-15 using two isolated native
clients on one PC, including verified transfers, conflicts/resolution, resumable
restart, lost acknowledgements and tombstones. This does not validate installed-app
UI scheduling or secure credential storage. This preview does not turn personal
Drive into multiplayer.

2026-10-15 reliability update: manual backups now browse the connected account's
backups by current Vault/all Vaults and name. Confirmation binds both Vault opening
and Google account; cancelled preparation never starts an upload and late cancelled
downloads cannot become restore candidates. A verified completed upload stays
visible even if a subsequent listing fails. Transient resumable-upload failures use
bounded 1/2/4-second recovery probes of the same session; expired access refreshes
once, and storage quota/API setup errors do not masquerade as sign-in failures.
The provider behavior follows Google's [error handling](https://developers.google.com/workspace/drive/api/guides/handle-errors)
and [resumable upload](https://developers.google.com/workspace/drive/api/guides/manage-uploads)
guidance. Cancellation is cooperative between bounded network operations, not an
instant abort of an already accepted Drive request. No new OAuth scope, automatic
Vault synchronization or account acceptance claim. Current task records tests.

2026-10-13: Windows Google registration is active for the owner Testing audience.
Real OAuth/token exchange/identity, quota and Vault/backup listing passed; a
configured release was built. Explicit sign-in prepares/reuses an empty Orbit
folder without uploading a Vault. Startup restore remains read-only. Preview
activation has secure device-only client storage and actionable configuration
errors. Manual backup/restore exists; automatic personal Vault sync, Android
registration and public Google rollout remain unfinished. Historical entries below
are superseded by [activation status](../development/google-drive-activation.md).

2026-10-11: Manual immutable Drive backup/restore is implemented, with resumable
chunks, cancellation, account binding, server MD5 and downloaded SHA-256 checks,
review and import into a separate folder. OAuth activation/live account acceptance
is pending. This does not satisfy the automatic personal SyncProvider milestone.
An independent self-hosted shared-note/Canvas preview is documented in
[setup](../development/shared-vault-setup.md) and [ADR 0027](../adr/0027-shared-vault-preview-and-drive-backups.md).
The historical status below predates these workflows; its personal sync gates remain.

2026-09-13 update: account/secure storage/quota/root/discovery UI is now implemented.
The historical foundation table below predates this account slice; current details
and remaining transfer gates are in the
[Google account milestone](../planning/google-account-milestone-2026-09-13.md).
**Consumer cloud sync remains incomplete.** No Vault transfer controls are exposed.

Full owner brief received 2026-09-12. Google Drive is first, WebDAV only after
Drive end-to-end works. Requirement IDs remain in
[sync-and-collaboration](sync-and-collaboration.md); this page tracks the concrete
milestone without duplicating the feature catalog.

## Implemented foundation

- Native Vault ownership and recoverable permanent-delete tombstones.
- Repository inventory retaining Archive/Trash, source bytes and empty folders.
- Provider-neutral reconciliation with SHA-256/common bases, no timestamp winner.
- Coalescing outbox, versioned durable local state and separate installation identity.
- Fake-provider tests for three replicas, restart/offline, conflicts, missing files,
  moved paths, uncertain upload acknowledgement and failed apply/checkpoints.
- Real native Vault replica adapter, verified staged transfers, exact owning-file
  apply, conflict alternatives, remote deletion recovery, Notes moves, live draft
  checks and Vault-bound checkpoints; tested with two real local Vaults.

The engine and state store are not yet connected to real Vault sync in the UI.
Ordinary local edits still save normally; there is no claim that they currently
upload or appear as Pending Sync in the app.

## Required report / acceptance map

| Owner report topics | Current status |
|---|---|
| 1–4 Storage audit, authority, inclusion and architecture | Documented against code; inventory implemented |
| 5 Provider API | Engine contract implemented; discovery/auth/session APIs still to extend |
| 6–8 Durable state, device identity, hashes | Foundation implemented/tested; not composed into Settings |
| 9 Pending queue | Tested through engine calls, not yet triggered by application durable commits |
| 10–11 Tombstones and conflicts | Local and remote tombstone recovery, native conflict alternatives and reconciliation tested; resolution UI pending |
| 12–13 Google OAuth and scope | Not implemented; planned drive.file only, separate Windows/Android adapters |
| 14 Google setup | Researched guide/example; current build does not consume client IDs |
| 15–24 Drive structure, IDs, appProperties, feed, upload/discovery/download/deltas | Designed, not implemented or account-tested |
| 25–26 Rename/move | Native Notes moves and lost acknowledgement replay tested; other physical owner-file moves and empty folder transfer pending |
| 27 Archive | Contents included; newly added device-only folder Archive metadata blocks preflight until portable migration is implemented |
| 28 Trash/delete | Trash owning files included; native permanent-delete recovery implemented |
| 29–30 Attachments/resumable upload | Native streamed staging/hash/apply and immutable content-path attachment flow tested; live resumable sessions pending |
| 31–32 Retry/backoff and watcher loops | Idempotent replay tested; scheduling/backoff/origin integration pending |
| 33 FTS | Remains derived/excluded; sync state survives separately |
| 34–35 Windows/Android | Local platform validation recorded in current task; no cloud device acceptance |
| 36–38 Settings/status/conflict UI | Not implemented; no dead Connect controls added |
| 39–40 WebDAV/self-host | Deferred until Drive works; setup requirements documented |
| 41 Security | Path/identity/version/collision guards and lock tests; auth/remote-adapter review pending |
| 42–47 Tests/builds/smoke | Actual results recorded in current task; simulations are not real account acceptance |
| 48–49 Windows paths | `build/windows/x64/runner/Release/orbit_note.exe`; ship complete Release directory |
| 50–52 Limits/deferred/next | Complete Google Drive integration and remaining native boundaries; WebDAV afterward |

No provider is advertised as working. Preserve this distinction in release notes.
See [architecture](../architecture/sync.md) for state formats and safety boundaries.
