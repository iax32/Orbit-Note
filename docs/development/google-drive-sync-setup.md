# Google Drive developer setup

## Automatic native sync preview — 2026-10-15

1. Open a native Vault, then Settings → Sync → Continue with Google. Signing in
   restores account access; only previously saved per-Vault opt-in resumes sync.
2. Choose **Enable automatic sync** and review the exact account/Vault and scope.
   This includes authored objects, Archive/Trash content, attachments and explicit
   deletions. It excludes caches, device settings/history and empty folders.
3. Saved local work queues within about two seconds without being postponed by
   continued typing. Active-Vault remote checks run about every five seconds while
   Orbit remains open; local integrity reconciliation runs about every 30 seconds
   and full cloud audits every 15 minutes. Network/draft/conflict delays can extend
   delivery. Last cloud check and completed full sync are shown separately. **Sync now** bypasses retry delay. No Windows service
   continues after closing. Temporary network failures back off; permission/token,
   quota/configuration failures require attention before automatic requests resume.
4. **Pause sync** keeps both local files and immutable Drive revisions. Resume
   retains the same account/folder/common bases. Changing accounts cannot silently
   rebind existing sync history; use a separate local copy for another account.
5. On another device, open Settings in a native Vault and **Browse synced Vaults**.
   **Open in a new local folder** verifies the canonical manifest, asks for a parent
   folder and creates a separate local copy before downloading. Matching names
   never merge identities. Multiple matching remote folders need an explicit pick.
6. Conflicts list local/remote divergence and concurrent branches. **Compare and
   resolve** previews text (up to 256 KiB) or binary/deletion metadata. Edit the
   local note first to combine wording, then review again. **Keep this device** or
   **Use cloud version** appends a resolution; a newer local edit invalidates the
   review. **Recovery files** can export retained originals. Permanent-delete
   restores/mismatched deletion bases require explicit local recovery rather than
   bypassing the repository's delete safety.

### Transfer several Vaults together

In **Settings → Sync**, connect Google, then choose **Upload multiple Vaults**.
The picker lists the current and recent Vaults. **Add Vault folder** adds one;
**Find Vaults in a folder** checks a chosen folder and its immediate children
(for example, Desktop). It does not recursively crawl the computer. Nothing is
selected by default. Choose individual checkboxes or **Select all**, then
**Upload and sync selected Vaults**. The displayed account receives the selected
notes, boards, attachments, Archive/Trash and deletion records. Existing cloud
changes can download too; actual conflicts remain for explicit review.

The batch processes one Vault at a time through the normal sync engine. Each row
shows waiting, transferring, up to date, needs review, failed or cancelled status.
A locked/missing/unsupported Vault fails independently. **Cancel transfers** stops
further work without deleting completed files; **Retry unfinished Vaults** reuses
durable upload plans and already-created download folders. Account/Vault changes
invalidate the batch. Copied folders retaining the same Vault UUID require choosing
only one copy; matching display names with different identities are independent.

On another device, use **Download multiple Vaults**, select the desired cloud
Vaults, and choose one parent folder. Each gets a separate new local folder and is
added to the recent Vault list without switching or merging the active Vault.
The Vault switcher uses the saved Vault name. Incomplete folders remain available
for recovery/retry; no existing local folder is replaced. The native recent list
retains up to 50 locations so larger downloads remain discoverable.

Successful transfers retain per-Vault account/folder bindings. Automatic sync runs
when that Vault is open. The optional **Keep these Vaults updated while Orbit is
open** checkbox adds only completed transfers to a device-local schedule. In
**Manage scheduled Vault checks**, inspect the selection/results, check now,
choose 1/5/15 minutes (default 5), pause/resume, remove locations or forget the
schedule without deleting local/cloud files. The schedule is bound to the selected
Google account and survives app restart; it never silently switches accounts.
It opens one inactive Vault at a time under its normal OS lock and closes it
afterward. Missing/locked locations are reported independently. Individually
paused or unbound Vaults stay paused; the active Vault uses its existing controller.
Checks wait while Shared Vault is connecting/connected, transfers are busy or
the Google account needs attention. Network failures back off; reconnect then
explicitly retry account errors. No service continues after Orbit closes.
Without the checkbox, run the batch again for inactive Vaults. A cancelled first transfer
does not newly enable automatic sync. Previous automatic-sync opt-ins remain in
effect. Open a Vault individually to compare conflicts or repair unsupported
content. History, caches, device settings and empty folders still stay local.

Personal sync pauses while Shared Vault is connecting or connected. Cloud revisions are never
automatically purged: changed content consumes additional Drive storage. Native
limits are 2 GiB/blob, 32 MiB/structured source, 10,000 retained revisions, 64
parents per resolution and existing 16 MiB checkpoint files. Empty folders are not
replicated; folder Archive metadata blocks setup until a portable migration exists.
Some non-Notes physical moves remain unsupported. Unexpected cloud removal,
changed immutable bytes, unsafe paths/newer formats and dirty drafts stop apply
instead of deleting or overwriting user work. Initial incomplete downloads are
retryable in their separate folder; do not delete retained Drive revision files.

This is a native preview, not public Google/mobile rollout acceptance. Existing
owner-testing desktop registration and narrow drive.file scopes are unchanged.
Real-account acceptance passed on 2026-10-15 with two isolated native clients on
one PC: exact note/Canvas/attachment transfers, conflicts and explicit resolution,
interrupted uploads, lost responses, tombstones and restart checkpoints. The owner
completed Google consent. Physical two-device and application UI/secure-store
acceptance remain unperformed; actual evidence is in
[current task](../tasks/current.md). The following dated registration/foundation
entries are historical and superseded for this slice.

### Opt-in real-account acceptance

`test/google_drive_live_acceptance_test.dart` is skipped by default, including CI
and the normal full suite. On Windows, run it explicitly from the repository root:

```powershell
flutter test --no-pub --reporter expanded --dart-define=ORBIT_LIVE_DRIVE=true test/google_drive_live_acceptance_test.dart
```

This requires the existing ignored `config/google-drive.local.json` Desktop app
registration. The system browser opens for the owner's Google consent; the
harness does not control the browser, read the app's stored account, or save
tokens to disk. Use an approved test user while Google registration is in Testing.
No new OAuth scope is requested. A fresh consent is required on every run.

The run creates a uniquely named **Orbit Sync Acceptance …** cloud Vault and two
separate native Vaults under `.local/drive-live-vaults/`. All uploaded content is
synthetic. Production auth, Drive, repository, staging and engine code handle the
transfers. Only the test transport injects an offline period, an interrupted
acknowledged chunk and a lost revision response. It checks exact Markdown and
attachment hashes, Canvas unknown-data preservation, bidirectional creation,
conflict copies/resolution, resumable restart, deletion tombstones and clean
restart checkpoints. Credentials, request headers and session URLs are not logged.

`.local/drive-live-result.json` records sanitized phases and the fixture name;
the cloud folder and local fixtures are retained for inspection, including after
failure. Remove only that run's clearly identified synthetic data when finished.
The run uses two independent native repositories/HTTP clients **on one PC**. It is
real-account transfer evidence, not physical two-device, application UI scheduling,
Android sign-in, or secure credential-store acceptance. A second machine must
separately sign into the app, browse the synthetic cloud Vault, open a new local
folder, verify a change in each direction, and check attachment availability and
offline conflict recovery before recording physical two-device acceptance.

2026-10-13: Windows Desktop registration, owner test user, narrow scopes and Drive
API are active in `orbit-note-511512`. Real OAuth, identity, quota and Vault/backup
listing passed. The Windows release includes the client. Manual backup/restore is
implemented; automatic Vault sync and Android activation remain unfinished. See
[current activation and usage](google-drive-activation.md).

Earlier milestones below are historical; consumer automatic-sync requirements
remain acceptance gates, not a claim that they are delivered.

## Consumer experience (required release behavior)

On first launch, offer **Use Google Sync** and **Continue locally**. Google Sync
opens the system account sign-in, then lets the user select an existing cloud
Vault or sync a new/local Vault. Orbit creates or reuses its Drive folder and
performs verified initial transfer before claiming the Vault is synced. On later
launches, restore the account and selected Vault without repeating onboarding.
Local use remains available during cancellation, sign-out and network failure.

The distributor must ship the Google app identifiers with the application. Never
ask consumers for Cloud projects, client IDs, credential JSON or API activation.
Do not release a build advertised as Google-sync-ready with a disabled login
button or with only account discovery implemented. Developer setup below is a
one-time distribution prerequisite, not a user onboarding step.

Every user's storage belongs to their signed-in Google account. The distributor's
Cloud project identifies the application; it is never a common Vault or a source
of end-user access tokens. Drive requests use that user's OAuth authorization;
root IDs are stored separately by Google subject. Root/Vault discovery is limited
to files owned by the current user, and a saved root whose ownership has changed
is rejected. Shared/team storage is outside this personal-sync milestone.
All requests in one operation retain its starting Google subject, including
pagination, manifest inspection and root metadata waits. A listed Vault carries
that account identity; selecting it after switching accounts fails before any
Drive request. Inspection rechecks folder ownership and Vault identity before
reading its manifest. Root creation is serialized on the device to prevent
duplicate folders from simultaneous setup calls.
See Google's [ownership fields](https://developers.google.com/workspace/drive/api/reference/rest/v3/files)
and [owner search filters](https://developers.google.com/workspace/drive/api/guides/search-files).

## Historical registration progress — 2026-09-13 (superseded)

Created the distributor project `orbit-note-508518` (Orbit Note) and submitted
Drive API activation. The owner declined the proposed policy acceptance and use
of their personal email as a visible support contact. The unsubmitted branding
form was cancelled; the console confirms Auth Platform remains unconfigured.
Do not reuse that email or accept the policy without new explicit authorization.
An approved app support contact is still required. No OAuth client has been
created or embedded yet; the existing
Windows build remains unconfigured. Verify activation before live acceptance.

## Google Cloud project

1. Create/select one Google Cloud project owned by the Orbit distributor. Keep
   Windows and Android OAuth clients in that project for the same application.
2. Enable Google Drive API in APIs & Services.
3. Configure Google Auth Platform branding, support contact, audience and developer
   contact. Choose the appropriate internal/external audience; for development,
   add explicit test users. Public release needs accurate privacy/disclosure pages.
4. Under Data Access request `openid`, `profile`, `email`, and
   `https://www.googleapis.com/auth/drive.file`.
   It is the narrow per-file scope for files the app creates or the user opens
   with it. Do not request full `drive` merely to make discovery convenient.
   See [Drive scope guidance](https://developers.google.com/workspace/drive/api/guides/api-specific-auth).

## Android identity

5. Create an Android OAuth client for the current application ID
   **`org.orbitnote.app`**. Register the signing-certificate SHA-1 requested by
   Google; keep SHA-256 available for other identity/distribution integrations.
   Inspect fingerprints using the Android Gradle `signingReport` task.
6. Register the actual certificates used by each build: debug for local tests,
   release for direct distribution, and Play App Signing certificate for Play
   builds. An upload certificate is not necessarily the certificate on users' APKs.
7. The repository currently signs release with the debug key. Configure real
   signing before public distribution; keep keystores/passwords outside Git.
8. The maintained `google_sign_in` package does not support Windows. Its Android
   implementation uses platform identity/authorization and requests Drive access
   separately from sign-in. If configuring without `google-services.json`, current
   package setup requires a web-client ID as `serverClientId` in addition to the
   registered Android package/certificate. This is an identifier, not permission
   to run a web redirect flow on Android or embed a web client secret.
   See [Android package setup](https://pub.dev/packages/google_sign_in_android)
   and [authorization API](https://pub.dev/packages/google_sign_in).

## Windows identity

9. Create a **Desktop app** OAuth client. Use system-browser authorization with
   PKCE S256, cryptographically random state/verifier, and a temporary loopback
   listener bound only to loopback. Validate state and redirect path; limit listener
   lifetime; close on cancellation. Do not use an embedded browser or deprecated
   copy/paste out-of-band flow. Google supports loopback for desktop, not Android:
   [native OAuth](https://developers.google.com/identity/protocols/oauth2/native-app),
   [loopback guidance](https://developers.google.com/identity/protocols/oauth2/resources/loopback-migration).
10. Desktop credential downloads may contain a client-secret field. A distributed
    native client cannot keep it confidential; it is not a backend security
    boundary. Validate the token exchange requirements for the Desktop client
    during adapter implementation. Never substitute a confidential web client
    secret or commit private credential downloads to the repository.

## Configuration and token custody

Public build configuration is in
[`google-drive.example.json`](../../config/google-drive.example.json). Use separate
development and release configuration files outside source control. These client
IDs are public application identifiers, not access/refresh tokens. Configured releases expose direct sign-in. Unconfigured Windows previews offer
validated Desktop JSON import into device secure storage; local use still works.

Copy the example to ignored `config/google-drive.local.json`, or, after
downloading the Desktop client JSON, run
`./tool/configure_google.ps1 -DesktopCredentials 'C:/path/to/download.json'`.
It validates the Desktop client type and saves only the required native build
values into the ignored configuration, without printing them. Optionally pass
`-AndroidServerClientId 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com'`.

The configuration contains:

- `ORBIT_GOOGLE_DESKTOP_CLIENT_ID`: Desktop OAuth client ID.
- `ORBIT_GOOGLE_DESKTOP_CLIENT_SECRET`: the value from that Desktop credential
  download if Google's token endpoint requires it. This is a distributed native
  client value, **not a confidential server secret**. Leave empty if unnecessary;
  never substitute a web/server client secret. Keep the download/private config
  out of Git. PKCE and the exact redirect/state checks protect the native flow.
- `ORBIT_GOOGLE_ANDROID_SERVER_CLIENT_ID`: the same project's Web OAuth client ID
  required by the Android identity SDK. Only the ID, never its client secret.

Build with `flutter build windows --release --dart-define-from-file=config/google-drive.local.json`
or `flutter build apk --debug --dart-define-from-file=config/google-drive.local.json`.
Use a separate ignored release file for distributor-owned production clients and
the actual release signing certificate. A normal app user never configures these
values or visits Google Cloud Console; the distributor supplies them at build time.

### Release workflow configuration

The release workflow now passes validated platform-specific configuration into
both Windows and Android builds. Previously it omitted all Dart defines, so even
an app with a registered Google client would ship with sign-in disabled.

For GitHub release builds, set repository variables
`ORBIT_GOOGLE_DESKTOP_CLIENT_ID` and `ORBIT_GOOGLE_ANDROID_SERVER_CLIENT_ID`.
If required by Google's Desktop token endpoint, store the native Desktop client
value in repository secret `ORBIT_GOOGLE_DESKTOP_CLIENT_SECRET`. Never store
account access/refresh tokens or a confidential Web client secret in these values.
See [GitHub configuration variables](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-variables).

The manual workflow has a `google_mode` choice; tag builds use repository variable
`ORBIT_GOOGLE_BUILD_MODE`. The default is `local-only`. Choose
`google-account-preview` only after configuring the appropriate clients. Missing
or placeholder app IDs fail before compilation. Release notes state the mode and
that automatic Vault synchronization is unfinished. This gate checks configuration
shape, not Google registration validity or live sign-in acceptance.

For a local Windows preview after importing developer configuration, prefer
`./tool/build_windows.ps1 -Flutter 'C:/path/to/flutter/bin/flutter.bat'`.
It automatically preserves the ignored client configuration. `-LocalOnly` is an
explicit opt-out. The equivalent low-level commands are:

```powershell
$env:ORBIT_GOOGLE_BUILD_MODE = 'google-account-preview'
dart --packages=.dart_tool/package_config.json tool/prepare_google_build.dart --platform=windows --config=config/google-drive.local.json --output=.local/google-build.windows.json
if ($LASTEXITCODE -ne 0) { throw 'Google build configuration failed.' }
flutter build windows --release --dart-define-from-file=.local/google-build.windows.json
```

Run `flutter pub get` before that helper on a clean checkout. The explicit Dart
entry point avoids running unrelated application native-asset hooks during this
standalone configuration step. Only the required platform app identifiers/native
client value are emitted; unrelated environment secrets and user tokens are never
embedded. Generated configuration stays in ignored `.local/`, outside artifacts.
These are distributor commands, never consumer onboarding instructions.

After building: Settings → Sync → Continue with Google. Check the profile and
Google storage, then use Prepare Orbit folder. This creates/reuses only the visible
root folder; the UI still says Local only because Vault transfers are not enabled.

The selected secure-storage adapter is `flutter_secure_storage` 11.1.1. The resolved
Windows adapter uses DPAPI-protected application-support storage. Android uses
Keystore-backed secure storage; Google services manage authorization token refresh.
Its minimum API 23 is below the current Flutter app minimum. Tokens and
WebDAV passwords belong in OS-protected device storage, never preferences, Vaults,
sync metadata, exports or logs. Android authorization refresh should use its
platform-supported path; do not invent a refresh token if the platform does not
expose one. See [secure-storage platform setup](https://pub.dev/packages/flutter_secure_storage).

Android release Internet permission is present. Automatic OS app backup is disabled
to avoid transferring device-bound secure material; manual Orbit export remains
available. Do not disable TLS checks or
request broad external-storage access for an app-private local Vault.

## Development and public release acceptance

Testing-mode restrictions and token lifetime can differ from a production OAuth
app. Follow the current console verification checklist rather than treating a
successful developer login as distribution approval. `drive.file` is classified
as non-sensitive in Drive guidance; branding, user-data policies and any additional
scopes still matter. See [OAuth policies](https://developers.google.com/identity/protocols/oauth2/policies).

Verify: cancelled consent, denied scope, expired token, revoked access, sign-out,
restart, offline edit, Windows-upload/Android-download and reverse, same-project
cross-client file visibility, root rename, and concurrent edits. Test with a
disposable Vault/account folder first. Do not log tokens or authorization codes.

No private credentials are needed for repository audit or fake-provider tests.
Real account/device acceptance is a separate required check before release.
