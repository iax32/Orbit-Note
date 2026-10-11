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

A Windows server executable was built at
`.local/collaboration/orbit_collaboration_server.exe`. This task started it hidden
on `http://127.0.0.1:47831`, with private data in
`C:/Users/isa/AppData/Local/OrbitNote/CollaborationPreview`. The owner key is
`owner-key.secret` inside that folder. Its contents were not printed or uploaded.
This is a local process, not an installed Windows service or public endpoint.
Its PID/startup logs are in `.local/collaboration/`; do not rely on it surviving
a reboot. The Windows app was subsequently rebuilt and packaged at
`release-assets/OrbitNote-Windows-x64.zip`, including the standalone server under
`collaboration/OrbitNote-Server.exe` and a setup README. No private keys/server data
are packaged. Google sign-in is still unconfigured; it is separate from this server.

To stop the hidden instance started by this task, verify its executable before
stopping the recorded process (a saved PID can be reused after exit):

```powershell
$orbitServerPid = [int](Get-Content .local/collaboration/server.pid)
$orbitServer = Get-Process -Id $orbitServerPid -ErrorAction SilentlyContinue
$orbitServerExe = (Resolve-Path .local/collaboration/orbit_collaboration_server.exe).Path
if ($orbitServer -and $orbitServer.Path -eq $orbitServerExe) {
    Stop-Process -Id $orbitServer.Id
}
```

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
2. Enter the HTTPS server address (or localhost for a same-machine test), server
   owner key and your display name. **Share this Vault** uploads an explicit copy.
3. Use **Copy my connection** and save it privately for restarting/rejoining.
   Losing this connection currently requires recovering server data or creating
   a new shared room; the UI does not store invitations in a Vault.
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

## Bounds and evidence

Initial backup: existing portable 80 MiB decoded/128 MiB encoded limit. Each live
document: 2 MiB JSON. Server retains bounded recent editing bases; older bases
require review. At most 128 active presence sessions per room. Access is a private
invitation capability with server-bound display names, not verified Google identity.
Desktop/native clients only; browser-origin requests are refused. Deployment over
the public Internet, TLS, multiple real devices and Google account acceptance need
separate checks. Automated two-client and server-restart tests are in
`test/collaboration_test.dart`; see current task for results.
