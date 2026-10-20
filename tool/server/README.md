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

Preview limit: live updates cover existing notes and Canvas boards. New objects,
deletions and attachment changes require a new shared snapshot. Snapshot sharing
discloses the whole exported Vault, including portable history, Archive and Trash.
Google Drive personal sync pauses while shared access is connecting or connected.
