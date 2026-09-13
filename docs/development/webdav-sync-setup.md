# WebDAV setup and acceptance requirements

Status: deferred until Google Drive works end-to-end. No WebDAV provider or
Settings controls are implemented. This is the agreed setup/validation contract.

Use a dedicated HTTPS WebDAV directory and preferably a narrowly scoped app
password on the chosen server. Keep its URL, username and directory mapping
device-local; store the password/token in OS-protected storage, never Vault files.
No TLS bypass. Development HTTP may be considered only for explicit loopback use.

The eventual Test Connection must verify authentication, PROPFIND support, scoped
directory creation and strong conditional request semantics. Test failed auth,
expired TLS certificates, partial multistatus replies, denied MKCOL, unavailable
server, 412 conflict, retry, move and delete intent. Reject unsafe write servers;
do not fall back to unconditional last-write-wins.

Use server sync tokens when supported, otherwise bounded directory/ETag
reconciliation. Provider capability differences do not justify a second SyncEngine.
An interrupted listing is never a mass deletion. See
[WebDAV RFC 4918](https://www.rfc-editor.org/rfc/rfc4918) and the
[provider-neutral design](../architecture/sync-design.md).
