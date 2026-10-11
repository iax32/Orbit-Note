# Activate Google Drive for this build

## Start here if you are unsure

Open [Orbit Note's Google setup page](https://console.cloud.google.com/auth/overview?project=orbit-note-508518)
in your browser and sign in with the account that owns the project. No downloaded
Desktop OAuth JSON was found in the usual Downloads folder during this task.
The next step is Google's **Branding** form, followed by **Audience** and
**Clients → Create client → Desktop app**. The checklist below explains each field.
When you download the JSON, keep it in Downloads and provide its file path;
the existing helper imports it without displaying its contents. Your email alone
cannot activate the sign-in button. Google registration remains incomplete.

## Registration status

The existing distributor project is `orbit-note-508518`. OAuth registration was
previously stopped before a client was created. The owner has now offered a support
email and requested setup help; no email is hard-coded as a storage account or
substitute for authorization. No Google console changes were made in this task.

## One-time developer registration

1. Sign into Google Cloud Console and select **Orbit Note / orbit-note-508518**.
2. Enable the Google Drive API if it is not enabled.
3. Open Google Auth Platform → Branding. Set Orbit Note as the app name and select
   the support email you intend users to see. Review Google's policy/consent setup
   yourself; prior policy acceptance was declined, and an email alone does not
   authorize accepting terms.
4. Choose the External audience in Testing and add the owner account as a test
   user. Add the narrow `openid`, `profile`, `email`, and `drive.file` scopes in
   Data Access. Public distribution has a separate branding/verification process.
5. In Clients, create an OAuth client of type **Desktop app**, name it Orbit Note
   Windows, and download its credential JSON. Do not create a Web client for the
   Windows loopback/PKCE flow.
6. Keep the download outside Git. From the repo run:

```powershell
./tool/configure_google.ps1 -DesktopCredentials 'C:/path/to/downloaded-desktop-client.json'
```

This creates the ignored local build configuration, without printing its contents.
Build Windows with the configured defines using the existing
[Google setup guide](google-drive-sync-setup.md#release-workflow-configuration).
Do not paste passwords, access tokens or refresh tokens into this chat or config.
The path to the downloaded developer configuration is sufficient for importing it.

Android also requires registration of `org.orbitnote.app` and the actual signing
certificate, plus the same project's Web **client ID** for the Google platform SDK.
See the existing setup guide; never embed the Web client secret.

## Current Drive behavior

Settings → Sync → Continue with Google uses the system authorization flow. A saved
account reconnects on startup without opening the browser. Sign-in and account
refresh load storage information, Vaults and available backups automatically;
temporary service failures remain retryable. After signing in,
**Back up this Vault** creates a timestamped immutable backup under
your own Orbit Note folder. Transfer progress and Cancel are available. **Refresh
backups** lists account-owned Orbit backups. **Restore** verifies SHA-256 and the
manifest, shows the existing import review and creates a new local folder.
Your current local Vault is not overwritten.

This is manual backup/restore, not automatic Vault synchronization or multiplayer
through Drive. Core local features still work offline. OAuth registration, actual
sign-in, quotas and live transfers remain unverified until the client exists.

References: [native OAuth/PKCE](https://developers.google.com/identity/protocols/oauth2/native-app),
[narrow Drive scopes](https://developers.google.com/workspace/drive/api/guides/api-specific-auth),
[resumable uploads](https://developers.google.com/workspace/drive/api/guides/manage-uploads).
