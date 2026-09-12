# M6 sync audit — current repository, 2026-09-12

Status: pre-implementation audit. Cloud sync is **not implemented**. This report
must not be used as evidence that Google Drive or WebDAV is ready for real Vaults.
The owner's new provider order is Google Drive first, WebDAV second. It supersedes
the older Supabase-first roadmap language without changing file-first authority.

The received brief ends at the heading `ARCHIVED CONTENT`. Remaining requirements,
especially archive/deletion/retention behavior, have not been received. The design
below identifies conservative defaults and unresolved release gates explicitly.

## Scope and baseline

Inspected AGENTS, README, product principles/definition/quality requirements,
architecture and ADRs, implemented formats and schemas, feature requirements,
backlog/roadmap/current task/status, and development workflow. Code evidence below
takes precedence over dated completion claims. The working tree already contained
PDF reader/tests and PDF documentation changes; these have been preserved.

No sync/auth implementation, credential store, durable outbox, provider mapping,
or installation identity was found in the current application. No credentials
were requested, read from personal files, or transmitted. No personal Vault was
opened or uploaded during this audit.

## Actual ownership and storage

| Data | Current code / durable owner | Sync treatment |
|---|---|---|
| Vault identity/name | `WorkspaceRepository.initialize/renameWorkspace`; `workspace.json`, v1, id/name/createdAt | Same manifest UUID on both devices; preserve raw unknown fields; never match by name |
| Notes | `ObjectCodec`; `Notes/**.md`, Orbit YAML envelope plus original body | Exact bytes; UUID inside file is identity; no decode/re-encode during transfer |
| Structured objects | `Objects/*.object.json` | Tasks, events, file metadata and other types use the same envelope; sync whole owning file |
| Canvas | `Boards/*.board.json`; `CanvasScene` and common object envelope | Whole current scene file, including references and ink; no second Canvas schema |
| Drawings | Codec/loader recognize `Drawings/*.drawing.json` | Preserve supported envelope and unknown data; not evidence of a complete drawing UI |
| Files/PDF/images | `importAttachment`, `Attachments/<sha256>/<safe-name>` plus orbit.file object | Original bytes first, metadata second; verify digest; no execution |
| PDF work | Bookmarks/form drafts are file-object properties; highlights/comments are ordinary note objects | Existing owning files carry them; reader caches and page positions excluded |
| Folders | Actual directories under `Notes`; `WorkspaceFolderStore` | Preserve empty directories as well as file paths; existing moves are Notes-only |
| Smart Views | Product specifications describe them; no separate saved-view store/`Views` codec found in current implementation | Do not invent `Views/` records or claim view-file support; future formats require a registered policy |
| Calendar/task state | `UniversalObject.properties`; calendar projects those objects | Replicate authored properties, not generated calendar grid/occurrences |
| Search/backlinks | `ObjectIndex`, native `DriftObjectIndex`, schema 3 | Derived; never upload SQLite, WAL, SHM or quarantined invalid indexes |
| Open panes/preferences | `SessionState`, `.orbit/device/settings.json` | Device-only: tabs, positions, cameras, note mode, collapsed folders, split ratios, motion |
| Selected Vault/recent paths | Application-support `selected-workspace.json` | Device-only; native paths must never become cloud Vault identity |
| History | `.orbit/history/*.before` plus metadata | Retain locally; not a remote operation feed; current retention is bounded |
| Recovery | `.orbit/recovery`, sibling `.orbit-*.tmp`, imported recovery | Never replicate executable journals or replay another device's journal |
| Trash | `deletedAt` in the owning object file; restore clears it | Normal replicated content transition; concurrent edit/Trash is a conflict |
| Permanent deletion | `deletePermanently`/`emptyTrash` directly delete owning files | **No retained tombstone exists.** Must be repaired before sync deletion ships |
| Archive | No explicit archive command/state found in the audited app | Do not equate missing, filtered, collapsed, trashed and archived content |

The filenames in the conceptual user example are not all implemented formats.
Canonical task/event/file records currently live in `Objects`, not separate Tasks,
Calendar or PDF metadata directories. Attachments can outlive deleted file objects.
The existing backup deliberately retains unknown files and recovery material;
therefore backup inclusion is **not** a safe sync inclusion predicate.

## Identity and revision findings

- Workspace creation, object creation and Canvas elements use offline UUIDs.
  Note titles can change while filenames remain stable. Explicit Notes moves
  preserve identity and rebase supported path links through the existing move journal.
- `UniversalObject.fromJson` currently accepts nonempty IDs; it does not enforce
  UUID syntax everywhere. Sync import must validate protocol identities without
  silently changing legacy IDs or normalizing existing user files.
- Workspace membership is supplied by the manifest when decoding. A foreign
  workspace ID in transport metadata must never grant permission to mix Vaults.
- `revision` increments locally; equal revision numbers on two devices do not
  imply identical bytes. SHA-256 preconditions exist for local saves and attachments.
- `_hashes` and `_paths` are in-memory repository state, reconstructed on open.
  There is no persisted common sync base, remote version, remote ID or cursor.
- `orbitLinkBindings`, aliases and explicit UUID links survive replication as
  existing object metadata. The transport must not rewrite references to Drive URLs.

## Commit, conflict and recovery findings

`WorkspaceRepository._serial` serializes commands only within that repository
instance. `_save` checks local revision, manifest hash and expected file hash,
then invokes `WorkspaceStore.write`, then updates memory/index. A failed index
update does not undo a durable file save. Controller autosave is currently 450 ms;
the network must use an additional coalescing interval, not that per-draft cadence.

Native writes preserve previous bytes, flush staged data and a recovery journal,
recheck the expected hash and rename. This is useful existing infrastructure, but
the final check/rename pair is **not atomic cross-process compare-and-swap**.
There is no native Vault lock. External programs can still race an advisory lock;
hash rechecks and recoverable alternatives remain necessary even after adding it.

Existing external conflicts retain `.pending` bytes. `saveConflictCopy` can create
a new local object. Neither is a cross-device conflict resolution protocol with
durable remote alternatives, shared ancestry and replicated resolution decisions.

Permanent deletion currently has no expected-hash argument, before-image or
portable deletion record. Missing files cannot safely mean delete: a missing file
may also be a move, an incomplete download, provider revocation or an external edit.
Never release sync that turns every remote 404 or missing listing row into deletion.

`NativePathMoves` already stages and journals Notes moves. Unresolved moves cause
read-only opening. Extend/reuse that command boundary rather than copy/delete
remote replacements beside existing object files and create duplicate UUIDs.

## Watcher and draft coordination

`NativeWorkspaceStore.changes` excludes `.orbit`, temporary writes and attachments.
The controller debounces hints by 400 ms and checks hashes. Startup/resume/directory
reconciliation supplements events. Dirty drafts prevent automatic external reload.

Sync needs its own durable-commit notification and startup reconciliation. It
cannot use the watcher as the outbox, cannot rely on attachment events, and cannot
apply remote changes behind dirty drafts. Download asynchronously; enter the
repository's short serialized apply boundary only after staging and validation.
Revalidate the target hash, Vault identity/generation and draft state at that point.
Vault switching must cancel/detach the old session before applying any late reply.

## Platform findings

- Windows and Android use the native store through conditional imports. Browser
  storage is a base64 localStorage adapter with a memory index; it does not have
  native folder, quota or locking guarantees. Production web sync is out of scope.
- Native store defaults use application document paths. A new-device Android
  download needs an explicit app-private destination and safe staging publication;
  it cannot assume the desktop folder picker works as a mobile Vault browser.
- Existing backup import publishes a new directory after complete staging, but
  its 80 MiB decoded limit is below the 100 MB single-attachment import limit.
  Reusing the JSON backup container for initial sync would reject valid Vaults
  and multiply memory use. Reuse its validation/publication ideas with streaming.
- Android application ID is `org.orbitnote.app`. Release currently signs with the
  debug signing configuration. No production release signing is configured.
- The main Android manifest has no Internet permission. Debug/profile manifests
  do not establish release networking. Add the release permission when networking
  is implemented; no broad storage permission is needed for app-private Vaults.
- No OAuth or OS-backed token storage dependency exists in `pubspec.yaml`.
  `url_launcher` already provides the system-browser launch boundary.

## Release gates, ordered by data-loss risk

1. Local coordination, durable deletion intent and interrupted-delete recovery.
2. Explicit sync inventory with paths/UUIDs/hashes, unknown-file reporting and
   case-insensitive collision checks; no wildcard `.orbit` upload.
3. Durable local sync database separate from the disposable FTS database,
   pending operations and common bases, crash-safe apply/ack transitions.
4. Conflict preservation with a reviewable UI, including delete/edit and
   rename/edit conflicts. No timestamp-only winner or automatic Canvas merge.
5. Provider write-race proof. Read-version-then-unconditional-write is unsafe.
   Verify conditional mutation behavior, or use immutable revision publication
   with recoverable conflicting heads; do not assume Drive version is a lock.
6. Google auth on both platforms, secure storage, Drive scoped discovery,
   incremental Changes feed, resumable transfer and initial/new-device flows.
7. Real two-device restart/offline/concurrent-edit testing with configured Google
   clients; then WebDAV capability and conditional-request testing on real servers.

## Validation matrix for implementation

| Scenario | Required result |
|---|---|
| Offline local save, app restart | Bytes and pending intent remain; no sign-in dependency |
| Crash after content save but before queue update | Startup reconciliation recovers pending change |
| Crash after remote acceptance but before local acknowledgement | Retry discovers same operation; no duplicate object |
| Both devices edit from one base, including clock skew | Both alternatives retained; visible unresolved conflict |
| Delete on one device, edit/rename on offline device | No resurrection or loss; explicit conflict |
| Simultaneous initial upload / same Vault names | UUID separation, idempotent root/entry creation |
| Rename Drive root or entry | Continue using provider IDs; preserve object UUID |
| Lost/invalid cursor, denied access, remote root moved/trashed | Reconcile or pause; no mass local deletion |
| Interrupted blob transfer / wrong checksum | No published dangling metadata or corrupted attachment |
| New-device download interrupted | Original Vault untouched; staging remains resumable |
| Dirty editor during download; Vault switch during response | Draft retained; no late application into another Vault |
| Index deletion/rebuild | Pending sync, bases and conflicts survive |
| Case/path/symlink collision; unknown future protocol | Reject publication safely, preserve source bytes |
| Disable sync / expired auth / server outage | Local open/edit/export continue normally |

Baseline validation is recorded in the current task after the audit checks finish.
