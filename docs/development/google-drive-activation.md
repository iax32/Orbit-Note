# Google Drive activation — Windows account preview

2026-10-15: a native automatic-sync preview is now available after explicit
per-Vault opt-in. The existing registration/scopes below are unchanged. Real
account transfers passed with two isolated native clients on one PC, including
verified note/Canvas/files, offline conflicts, explicit resolution, resumable
restart, lost acknowledgements and tombstones. The owner completed fresh browser
consent; credentials stayed in memory and only synthetic acceptance data was
uploaded. Physical two-device and installed-app secure-store acceptance remain
unperformed. See
[sync usage and limits](google-drive-sync-setup.md). Prior backup-only delivery
statements below are historical for this feature slice.

## Registered and verified — 2026-10-13

Orbit Note now uses dedicated project `orbit-note-511512`. The older
`orbit-note-508518` project was inaccessible from the relevant accounts. The owner
explicitly authorized browser registration and policy acceptance. Branding,
external Testing audience, owner test user, **Orbit Note Windows / Desktop app**
client, Google Drive API and `openid`, `profile`, `email`, `drive.file` scopes are
configured. The owner completed Google's test-app notice and account consent.

A temporary check using the production Windows OAuth and Drive API adapters
successfully exchanged authorization, verified identity, read storage quota and
listed Orbit Vaults/backups. Credentials stayed in memory; no Vault upload,
restore or original-file change occurred. This verifies real account access,
not installed-app secure-storage acceptance or large live backup transfers.

## Use the configured Windows release

Run `build/windows/x64/runner/Release/orbit_note.exe`, with its sibling files.
Open **Settings → Sync → Continue with Google** and choose the registered owner
account. The browser consent is still required; no Cloud configuration entry is
needed in this build. Complete sign-in once in the app to save its account on the
device. The temporary verification did not sign the desktop app in for you.

Explicit sign-in prepares/reuses an empty account-owned Orbit folder and refreshes
storage and backup listings. It does not upload a Vault. Startup account restore
remains read-only. Folder failures retain the account and show a retryable error.
**Back up this Vault** performs a deliberate immutable backup; **Restore** verifies
and reviews it before importing into a separate local folder. Local use stays
available offline. This is manual backup/restore, not automatic Vault sync or
Drive multiplayer.

Google registration is currently **Testing**, with the owner's account allowed.
Other users require explicit test-user registration or a separate public rollout.
Android client/certificate registration remains unfinished.

## Preserve registration in future Windows builds

The downloaded Desktop JSON and `config/google-drive.local.json` are ignored local
files. Never place account tokens, passwords or private downloads in Git/Vaults.
Import a new developer download with:

```powershell
./tool/configure_google.ps1 -DesktopCredentials 'C:/path/to/downloaded-desktop-client.json'
./tool/build_windows.ps1 -Flutter 'C:/path/to/flutter/bin/flutter.bat'
```

The build helper validates platform-specific defines and includes the registered
client. Invalid configuration fails rather than silently producing a local-only
release. `-LocalOnly` explicitly opts out. GitHub builds still require their own
repository variables/secrets; local registration does not configure hosted CI.

Unconfigured Windows previews offer **Continue with Google → Import desktop
client…** as a recovery path. They validate the Desktop JSON, store only native
client fields in device secure storage and then sign in. Configured releases
cannot be overridden. Web clients and arbitrary endpoints are rejected. Normal
consumers should receive the configured release, not perform developer setup.

[Developer setup](google-drive-sync-setup.md) retains Android and CI instructions.
