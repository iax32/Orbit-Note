# Self-hosted shared Vault preview

This preview shares an explicit whole-Vault copy. Existing active Markdown notes
and Canvas boards support simultaneous editing, names and pointers. New objects,
deletions and attachments are not streamed; start a new shared snapshot for those.
Other files are included in the initial copy. Share only a Vault whose entire
contents you intend to disclose, including Archive, Trash and portable history.

## Start the server

Use a private **separate data directory**, outside any Vault, on the machine
hosting the service. Protect it with OS account permissions and back it up.
Do not put credentials or the server journal into an Orbit Vault or public Git.

From this repository with the configured Dart SDK:

```powershell
dart --packages=.dart_tool/package_config.json tool/collaboration_server.dart C:/OrbitServerData
```

Default: `127.0.0.1:47831`. The command creates `owner-key.secret` in the private
server data folder. Paste its contents into Orbit's owner-key field; never send
that server key to collaborators. Leave this process running while collaborating.
Ctrl+C shuts it down. No server process starts with Orbit automatically.

The normal Windows release includes `collaboration/OrbitNote-Server.exe` and
**Start Orbit Server.cmd** alongside its README. Double-click the launcher on the
host computer; it uses `%LOCALAPPDATA%/OrbitNote/Server` as private data storage.
Keep its console open while collaborating and press Ctrl+C to stop. No Dart SDK,
ZIP extraction, installed Windows service or automatic app startup is required
for the packaged server. Server keys/data are never packaged. Google sign-in is
independent of this self-hosted service. The application still runs normally from
the release directory's `orbit_note.exe`.

Repository maintainers can rebuild just the standalone host:

```powershell
./tool/build_server.ps1 -Dart 'C:/path/to/flutter/bin/cache/dart-sdk/bin/dart.exe'
```

`tool/build_windows.ps1` builds both the app and standalone host. Creating server
data inside a directory containing, or nested within, an Orbit `workspace.json`
is rejected before creating the key/journal. Stop the service before copying its
whole private directory for recovery. Preserve the owner key and journal together;
do not replace a lost key or delete journal records to work around a failure.

To host remotely, put an authenticated-to-this-service **HTTPS reverse proxy**
in front of the loopback service. A Caddy configuration, for an actual domain you
control, is:

```text
notes.your-domain.example {
    reverse_proxy 127.0.0.1:47831
}
```

Replace the example with your domain and configure its DNS/firewall/TLS on your
host. Do not forward the unencrypted service port publicly. The app accepts HTTP
only for loopback; it never disables certificate verification. No proxy, domain,
port-forward or background service is installed by this task.

## In Orbit

1. Open Settings → Sync → Shared Vault · self-hosted.
2. Enter the HTTPS server address (or localhost for a same-machine test) and server
   owner key. **Test server connection** checks protocol/readiness without uploading
   a Vault. Enter your display name; **Share this Vault** uploads an explicit copy.
   Localhost always means the current device, not another person's host computer.
3. **Remember connection on this device** stores only this room capability in
   OS-protected local storage. **Reconnect saved server** explicitly rejoins after
   restart; it still checks current server roles, revocation and local divergence.
   **Forget saved connection** removes this device's saved capability without
   deleting local/cloud files or revoking other people. **Copy my connection**
   remains available for private manual recovery. The server owner key is never
   remembered. No saved capability enters the portable Vault or its backups.
4. Enter the other person's display name, choose Editor or Viewer, and create a
   private invitation. Send the copied invitation yourself through a private channel.
5. They open the same Settings dialog and paste it into **Join shared Vault**.
   A different Vault is downloaded, reviewed and imported into a new local folder.
   An existing matching UUID is never merged solely because its name matches.
6. Open a shared note or Canvas. A status strip shows connectivity and people;
   Canvas pointers use world coordinates, note pointers relative viewport positions.
   Presence is approximate, ephemeral and separate from durable saves.

Owner can revoke an invitation. This stops server access, but cannot retract
copies already downloaded. Disconnect keeps local files. Network interruption
does not stop local editing. Independent edits merge; overlapping changes or
divergence on rejoin appear in Shared Vault settings. Keep the local version or
explicitly adopt server content with the previous source retained in file history.

Connection interruptions now back off automatically up to 30 seconds between
attempts. **Retry now** is available in Settings and the shared-document strip.
Denied/revoked access pauses automatic requests: check your invitation/server
permissions before retrying. Pending-document counts include shared drafts that
have not saved locally or whose server acknowledgement is uncertain. They exclude
new objects, which this preview does not stream. Disconnecting invalidates pending
connection replies; it does not erase local work. Credentials remain in memory
unless explicitly remembered. Drive sync pauses during connection setup as well
as while connected, so the two authorities cannot apply competing updates.

`GET /healthz` returns only service/readiness (HTTP 200 or 503) without an owner
key. `GET /v1/server` requires the owner bearer key and exposes protocol, readiness,
room count and current capabilities. It never returns keys or Vault content.
Browser-origin requests are still refused. A journal write failure makes the
server unready; stop it and recover storage before reconnecting. These diagnostics
do not configure TLS or prove another device can reach the host.

## Bounds and evidence

Initial backup: existing portable 80 MiB decoded/128 MiB encoded limit. Each live
document: 2 MiB JSON. Server retains bounded recent editing bases; older bases
require review. At most 128 active presence sessions per room. Access is a private
invitation capability with server-bound display names, not verified Google identity.
Desktop/native clients only; browser-origin requests are refused. Deployment over
the public Internet, TLS and multiple real devices need separate checks. Automated
two-client/server-restart and device-continuity tests are in
`test/collaboration_test.dart` and `test/device_sync_continuity_test.dart`; see
current task for actual results. No persistent server is started by these checks.
