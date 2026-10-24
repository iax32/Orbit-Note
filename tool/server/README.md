# Orbit Note server

Double-click **Start Orbit Server.cmd**. It runs the included standalone
`OrbitNote-Server.exe`; Flutter/Dart are not needed on the host. Keep the console
open while using the server and press Ctrl+C to stop. No Windows service is
installed. The build does not contain keys or Vault data.

Default private data: `%LOCALAPPDATA%\OrbitNote\Server`. The first start creates
`owner-key.secret` there. Keep the directory private, outside a Vault or shared
Drive folder. Back up the entire directory while the server is stopped. Never
share the server owner key; create room invitations in Orbit instead.

On the host, Orbit → Settings → Sync → Shared Vault: use
`http://127.0.0.1:47831`, paste the owner key and choose **Test server connection**
before **Share this Vault**. The test reads authenticated server information; it
does not upload a Vault. `/healthz` exposes only basic readiness for monitoring.

For another device, set up an HTTPS reverse proxy to `127.0.0.1:47831` with a
hostname and valid certificate you control. Then use that HTTPS address in Orbit
and invitations. Do not send another device a localhost address or publicly
expose the unencrypted port. The app does not bypass certificate checks.

After connecting, **Remember connection on this device** stores your room grant
in device secure storage. **Reconnect saved server** restores access after a
restart. **Forget saved connection** removes that local capability; it does not
revoke server access or delete data. The server owner can revoke invitations.

New rooms created with the updated app support live new objects, Trash/restore,
permanent deletions and verified resumable attachments. Note cursors/selections
are source checked; conflicting edits need review. Legacy rooms retain their old
snapshot behavior: create a new shared Vault/invitation to enable live replication.
Use matching updated clients; old clients cannot silently enter live rooms.
Snapshot sharing
discloses the whole exported Vault, including portable history, Archive and Trash.
Google Drive personal sync pauses while shared access is connecting or connected.

## Restart and recovery

Before upgrading, stop the host and back up the whole private directory. New live
journal records require the updated server. An exact private
`events.before-live-v2.jsonl` is retained before the first new record kind; it
excludes later changes and is not a complete current backup. Preserve current
journal, blobs and keys together. Do not run an older host against the live log.
Limits include 2 MiB/document, 10,000 identities, 128 MiB room metadata/history,
and the existing 128 MiB initial snapshot. Larger live assets can exceed the
downloadable snapshot size; the snapshot endpoint then refuses with a clear
error. Disk usage/journal compaction is not automatic. Provision host storage.

Optional secure client reconnect runs on launch/resume. No closed-app mobile
worker or Windows client service is installed. Physical-device and deployed TLS
acceptance remain separate from local synthetic tests.

Use the client and server from the same updated Windows build. The server now
identifies each start so connected clients can reset their update cursors after
a restart or restored backup. If shared content differs or disappears, clients
retain local work and ask for review before publishing. An unchanged restart
continues normally. Server identity/protocol changes pause automatic requests.

The in-app **Set up a host for your devices** guide creates a domain-only proxy
configuration example. **Check shared changes now** requests current state, and
returning to the app checks active sessions without bypassing revoked access.
No DNS, certificates, proxy or background service are installed automatically.
