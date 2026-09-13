# ADR 0019 — Native Google account adapters and secure sessions

- Status: accepted, account slice implemented; live provider acceptance pending
- Date: 2026-09-13
- Extends: ADR 0016/0017

## Decision

Keep the existing SyncEngine, provider contract and native WorkspaceSyncReplica.
Google authentication and Drive account/discovery are infrastructure adapters;
account/authorization never become repository requirements. The application
controller composes account state and Settings displays it independently from
Vault connection. No account action implies consent to upload a Vault.

Windows uses system-browser Authorization Code with PKCE S256, random state and an
ephemeral IPv4 loopback receiver. Secure storage retains tokens; the OIDC userinfo
endpoint provides `sub`. Android uses maintained Google identity (Credential
Manager via google_sign_in) and separate authorization for Drive scopes. Android
Google services own token renewal; Orbit keeps only a secure profile marker.

Use `openid profile email drive.file`, build-time client identifiers and OS-backed
secure storage. Desktop client-secret values, if required by Google's installed
client exchange, are not treated as confidential in distributed binaries. There
is no embedded web client secret, manual auth-code flow or token entry UI.

Quota preserves unknown/pooled semantics and int64 precision; it is advisory and
cannot block local saves. Root IDs are account-scoped and durable before create.
Auth/discovery does not assert the conditional publication needed by SyncProvider.
The Drive transfer adapter must prove that contract separately before enabling
automatic sync; API version metadata alone does not close a read/write race.

## Validation and consequences

Offline HTTP fakes cover sign-in/state/PKCE/timeout/cancel/refresh/revocation,
account identity, quota, root rename/retry, discovery and settings. Real native
OAuth, cross-client Drive visibility and OS-backed credential acceptance require
configured credentials/device checks. Web auth and WebDAV enhancements are deferred.

See [milestone evidence](../planning/google-account-milestone-2026-09-13.md) and
[Google setup](../development/google-drive-sync-setup.md).
