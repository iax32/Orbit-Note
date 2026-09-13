# Cloud sync — delivery status

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
