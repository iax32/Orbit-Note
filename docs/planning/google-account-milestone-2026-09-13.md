# Google account milestone — 2026-09-13

Status: **partial milestone; account/storage/discovery slice implemented**.
This is not complete consumer cloud sync. Upload, download, Vault binding and
automatic Google Drive reconciliation are not enabled. Settings explicitly says
Local only. Do not remove that boundary or advertise transfers as complete.

## Audit against current code

| Area | Classification at start | Outcome |
|---|---|---|
| SyncEngine, SyncProvider, reconciliation | WORKING foundation | Retained, no second engine |
| Native WorkspaceSyncReplica, staging, hashes, tombstones | WORKING tested foundation | Retained |
| Device sync state and installation identity | WORKING foundation | Retained |
| Conflict preservation | PARTIAL | Durable alternatives exist; resolution UI pending |
| Watcher/draft/Vault-switch guards | WORKING local infrastructure | Automatic cloud scheduling not wired |
| Google provider/auth/secure storage | NOT IMPLEMENTED | Account adapters and Drive account/discovery API added |
| WebDAV provider | NOT IMPLEMENTED | Deferred; no existing adapter to replace |
| Cloud settings/account display | NOT IMPLEMENTED | Real configured sign-in, account and quota UI added |
| Root/Vault discovery | NOT IMPLEMENTED | Account-scoped root ID and paginated discovery added |
| Initial transfer and live Drive changes | NOT IMPLEMENTED | Still pending safe provider publication |

The prior runtime fixes and additional working Footnote/Underline features remain
intact. Current test count may exceed the supplied 463 baseline because the shared
worktree contained additional feature work. No resets or unrelated reversions.

## Delivered behavior

Windows uses system-browser Authorization Code + PKCE S256, a cryptographic state,
an ephemeral IPv4 loopback port and a three-minute callback timeout. State/path/
authority and code uniqueness are checked before exchange. Cancellation closes the
listener. The response page does not reflect codes, state or provider errors.
Google's HTTPS userinfo endpoint supplies the stable `sub`; email is display data.
No unverified ID-token parsing is used as identity validation.

Android uses maintained `google_sign_in` 7.2.0 and its Credential Manager adapter.
Identity (`authenticate`) is followed by separate Drive scope authorization.
Silent restoration uses lightweight authentication plus noninteractive scope
authorization. Google services retain refresh credentials; Orbit does not invent
or export an Android refresh token. The SDK account ID is the stable Google user
identifier; it is not email. Real device acceptance remains required.

Scopes are `openid`, `profile`, `email`, and `drive.file`. Desktop credentials use
`flutter_secure_storage` (Windows DPAPI); Android uses platform-secure storage for
the connected profile marker and Google services for authorization credentials.
Android network permission is present in release and OS automatic app backup is
disabled to avoid transferring device-bound credential material. Manual Orbit
exports remain available. No tokens enter Vault files, logs or ordinary settings.

Saved desktop sessions restore without opening a browser and coalesce refresh
requests. Invalid/revoked grants produce reconnect state while local editing stays
available. Reconnect can require the prior subject; Change account is a separate
confirmed sign-out/sign-in action. Credential writes and deletion are serialized
to prevent a late refresh from recreating a signed-out session.

Settings shows account name/email, an optional cached-in-memory profile image with
icon fallback, Google-reported quota and local authored Vault size. Quota refresh
is cached for five minutes with explicit refresh. Remaining storage is total limit
minus total Google usage, never Drive-only usage. Missing/malformed values remain
unknown, large integer values use BigInt, no reported limit is not described as
zero, and Workspace pooled-storage wording avoids claiming personal allocation.
A 90% warning is passive. The max-file/remaining-space preflight model is tested
but not yet connected to a transfer workflow.

Root preparation is explicit and creates a visible Orbit Note folder. A persisted
Google-generated ID makes lost-create-response retries reuse the same remote ID.
Root rename/move does not change its identity. A missing known root or ambiguous
multiple roots stops safely for review. Cross-device simultaneous first-root
creation can still produce multiple roots; this is a remaining setup limitation.

Discovery lists only app-authorized Orbit Vault folders using appProperties and
pagination, preserving same-name/different-UUID entries separately. Verify checks
the canonical `workspace.json` UUID/format/version against the folder hint. Folder
metadata is a lookup aid, not canonical object identity. This build does not create
remote Vault manifests or open/download the discovered Vaults.

## Safety gate before the next transfer slice

The existing engine requires **atomic conditional publication**, including races
between fresh remote inspection and a content write. Drive v3's `version` field is
not itself a compare-and-swap parameter. The currently reviewed files.update docs
do not establish the complete required contract for binary and resumable writes.
Do not set `supportsConditionalPublication = true` based only on a preceding GET
or fake-provider tests. No live credentials were available to perform isolated
Drive conformance experiments. This uncertainty blocks safely enabling writes; it
does not block account, quota or discovery work.

Next: prove conditional content publication and concurrent creation semantics with
a disposable Drive fixture (stale write must reject without changing bytes), then
implement GoogleDriveSyncProvider against the existing SyncEngine. Cover response
loss, resumable finalization and first-publication races before UI upload/download.
Initial download must stage a separate native Vault and validate its manifest,
UUIDs, paths and attachments before exposing it. Preserve the inventory's Archive,
empty-folder and physical-move limitations until explicitly addressed.

## Owner report coverage

| Requested topics | Result |
|---|---|
| 1–2 Existing sync/Google code | Audit above; sync foundation existed, Google implementation did not |
| 3–9 Auth/platform/scopes/storage/restoration/identity | Implemented as above; real account acceptance untested |
| 10–12 Profile/avatar/switching | Implemented and widget/unit tested; no automatic Vault upload |
| 13 Root behavior | Implemented, rename and lost-acknowledgement tests |
| 14 Remote manifest | Read/verify only; remote creation pending |
| 15 Discovery | Implemented pagination/UUID distinction; real cross-client visibility untested |
| 16–18 Upload/download/UUID reconnect | Transfers and binding pending; UUID verification exists |
| 19–24 Quota/math/missing limit/pooled quota/Vault size/warnings | Implemented; Vault sizing uses file stat, not full attachment hashing |
| 25–26 Preflight/maxUploadSize | Model and tests implemented; transfer UI wiring pending |
| 27 Drive changes | Pending provider implementation; no recursive sync scan added |
| 28 Offline | Local save/reopen explicitly tested during Google failure; no claim of automatic catch-up yet |
| 29–30 Reauth/errors | Sanitized account-specific errors; local files unaffected |
| 31–35 Tests/analyzer/platform builds | Final evidence below |
| 36–37 Manual OAuth/Drive | Not performed: private client configuration/account credentials absent |
| 38–39 Developer configuration | See linked setup guide and public example |
| 40 Windows EXE | `build/windows/x64/runner/Release/orbit_note.exe` |
| 41 Limitations | Transfers, automatic sync, conflict UI, live OAuth acceptance; browser auth intentionally excluded |
| 42 Next cloud milestone | Proven Drive publication + initial upload/download on existing engine |

## Validation

Account-ownership follow-up: root and Vault discovery now filter to the signed-in
user's owned files. Previously saved roots must still be owned by that user.
Added tests for two accounts creating distinct roots with their respective OAuth
authorization and for rejection of a root transferred to another owner. All 511
tests pass; analyzer clean; 204 files format-clean; Windows release built in 72.9s
(`.local/google-ownership-*.log`). The owner's personal email was
not published: the unsubmitted Google branding form was cancelled after they
declined its use. The developer Cloud project never supplies a shared storage
account. Actual Vault upload/download remains unfinished.

Final checks for this account slice: 509 full tests passed; `flutter analyze`
reported no issues. Format verification covered 204 Dart files with zero changes.
Windows release built successfully (9.9s incremental) and stayed running during a
five-second startup smoke check. Android debug built successfully (48.8s), with
existing `desktop_drop`/`pasteboard` Kotlin migration warnings. The developer
configuration helper parses successfully and its output path is Git-ignored.
Evidence is in `.local/google-final-*.log`. Builds without client configuration keep
Continue with Google disabled with a clear explanation; no fake login is used.

The owner clarified that consumers should only sign in with Google, with no API
setup. App registration and build configuration are therefore distributor tasks,
never consumer Settings fields. The Google Cloud credentials page was inspected;
it requires owner sign-in before registration can be checked. Live OAuth and Drive
acceptance remain unverified. The missing registration and the unfinished transfer
adapter are separate blockers; supplying a client ID alone does not complete sync.

[Developer setup](../development/google-drive-sync-setup.md) ·
[Google native OAuth](https://developers.google.com/identity/protocols/oauth2/native-app) ·
[Android adapter](https://pub.dev/packages/google_sign_in_android) ·
[Drive About](https://developers.google.com/workspace/drive/api/reference/rest/v3/about/get) ·
[Drive upload semantics](https://developers.google.com/workspace/drive/api/guides/manage-uploads) ·
[Drive update reference](https://developers.google.com/workspace/drive/api/reference/rest/v3/files/update)
