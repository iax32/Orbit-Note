# Device sync and self-hosted recovery — 2026-10-21

## Scope

Owner-authorized synchronization, hosting and multiplayer reliability update.
Implements subsets of SYNC-02/03/04/05/12 using existing storage and providers.

- Drive foreground scheduling retains edits made during an active transfer and
  coalesces a follow-up pass. Transient failures use their actual retry deadline;
  Pause cancels retries. Status distinguishes newer queued local edits from an
  acknowledged transfer. Foreground checks retain account/access/opt-in guards.
- Active shared sessions check server state before publishing. Optional ephemeral
  server-incarnation metadata resets a stale delta cursor after restart/restore.
  Different or absent documents require review with local work retained; uncertain
  acknowledgements are not blindly replayed into a restored journal. Same-version
  different-content responses also require review. Unchanged restart state resumes.
- Foreground/resume requests made during a shared poll are coalesced. Server role
  changes are checked before publication. Existing independent merges, Canvas
  review, history, grant revocation and idempotent acknowledgement replay remain.
- Shared settings include a host/HTTPS/invitation guide, validated hostname-only
  proxy snippets, an explicit current-state check, host/access/acknowledgement
  status and owner-key/connectivity diagnostics. No credentials enter snippets.

Host-incarnation guards also travel with edit proposals: a restart between the
state check and publication returns a typed conflict before any journal mutation.
Canvas comparisons reject changed hosts before applying choices; existing conflict
bases are invalidated on restart instead of reused across uncertain ancestry.

## Validation

22 new behavior regressions: six active Drive scheduling tests and 16 shared-host,
compatibility, race, permission and layout tests. Final focused suite: **83 passed**.
Preliminary regressions exposed the legacy-host full-state handshake, stale Canvas
reviews and the preflight/publication restart race; those paths are now guarded.
Final full suite: **2,837 passed, 2 existing skips** (Windows link privilege and
manual real-Google consent). Formatting/strict check: **716 files, clean**.
`flutter analyze --no-pub`: **no issues**. The final code/test/build-input snapshot
contains 778 files and remained unchanged through validation.

Configured Windows app + standalone host build: **passed** (app compile 88.9s).
Standard JavaScript web release build: **passed** (65.8s). Existing Google SDK
Wasm dry-run incompatibility and missing Cupertino font warnings remain; no Wasm
or web account-sync support is claimed. No new package was added to hide them.

Local runnable: `build/windows/x64/runner/Release/orbit_note.exe`, version
1.0.2+3, with its complete sibling runtime and matching `collaboration` folder.
Seven required runtime/host files exist; `data/app.so` and standalone host are
fresh after this build began. All 13 authored font hashes match packaged bytes.
No `.secret`, `.jks`, `.keystore`, `key.properties` or private Google configuration
files were present in that release tree. The host `--help` smoke check exits 0
without starting a persistent service. No app or installer was launched.

Logs/check records are device-local under `.local/sync-quality-*`: final focused,
full-final-verified, format, analyze, windows, web, final-source and build-verification.
The final source snapshot stayed identical through tests and builds. Publication
and APK rebuilding were not part of this request.
All tests use synthetic Vaults, simulated Drive HTTP and ephemeral loopback hosts.
No personal Vaults, real Google account actions or desktop-control testing.

## Compatibility and limits

No authored-data or persisted format migration. Protocol 1 gains an optional
`epoch` response/query/edit field; old clients/servers remain protocol-compatible.
Update the standalone host alongside the client for restart-cursor recovery.
A host incarnation change with differing content intentionally requires review,
including a healthy restart with remote edits made before this client reconnects.
This protects against restore ambiguity rather than guessing an ancestor.

Drive remains foreground native-folder sync. Mobile OAuth/public rollout and
physical two-device/TLS acceptance remain unverified. Shared sessions still cover
existing notes and Canvas; new objects, deletions and attachment changes require
a new shared snapshot. The guide does not install a proxy, configure DNS/firewall,
create certificates, start a background service or imply end-to-end encryption.

Suggested next task: durable shared new-object/attachment synchronization with
explicit deletion and recoverable operation replay; stop before implementing it.
