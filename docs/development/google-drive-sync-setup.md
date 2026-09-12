# Google Drive developer setup

Status: researched configuration plan, 2026-09-12. Auth and sync are **not yet
implemented**. The example below documents proposed configuration keys; current
Orbit builds do not consume them. Do not expect a Connect button from this guide.

## Google Cloud project

1. Create/select one Google Cloud project owned by the Orbit distributor. Keep
   Windows and Android OAuth clients in that project for the same application.
2. Enable Google Drive API in APIs & Services.
3. Configure Google Auth Platform branding, support contact, audience and developer
   contact. Choose the appropriate internal/external audience; for development,
   add explicit test users. Public release needs accurate privacy/disclosure pages.
4. Under Data Access request `https://www.googleapis.com/auth/drive.file`.
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

Proposed public build configuration is in
[`google-drive.example.json`](../../config/google-drive.example.json). Use separate
development and release configuration files outside source control. These client
IDs are public application identifiers, not access/refresh tokens. The runtime
must reject missing configuration with an actionable message while local use works.

The proposed secure-storage adapter is `flutter_secure_storage`, which lists both
Windows and Android support. Verify the selected version's native mechanisms,
minimum platform requirements and backup behavior before adding it. Tokens and
WebDAV passwords belong in OS-protected device storage, never preferences, Vaults,
sync metadata, exports or logs. Android authorization refresh should use its
platform-supported path; do not invent a refresh token if the platform does not
expose one. See [secure-storage platform setup](https://pub.dev/packages/flutter_secure_storage).

Add Android release Internet permission when implementing networking. Exclude
secure credential material and device identity from Android backup/transfer as
required by the selected storage implementation. Do not disable TLS checks or
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
