# GitHub Windows/Android publication — 2026-10-21

Status: published. Owner explicitly requested pushing the accumulated source and
building/uploading Windows and Android releases. This task authorizes publication
and supersedes the preceding local-only task limits; no new feature scope.

## Plan

- Audit source and preserve ignored Vaults, SDKs, account config and signing keys.
- Version 1.0.2+3; preserve Android preview application ID and signing certificate
  so the previous preview can update. Keep Windows configured Google sign-in.
- Push current source without force and build an immutable dated preview tag.
- Use existing Windows setup and signed Android preview workflows; verify version,
  commit association, package/runtime files, signatures, checksums and hosted assets.
- Publish EXE/APK and verification files. Retain a local runnable Windows folder.
  No ZIP release asset, personal Vault operations, desktop control or app launch.

## Validation basis

Preceding math task: 46 new regressions; focused 192 passed; full 2,815 passed,
two existing skips (Windows link privilege / manual Google consent). Format and
strict check clean across 714 files; analysis clean; configured Windows/server
and standard web builds passed. App source is unchanged by this release task;
only version/docs are updated. Publication checks are recorded below.

## Source and build verification

Source commit `10c5cef8778e8f468edfadb966804455079f1e9b` was pushed without force
and tagged `preview-2026-10-21`. The 1,059-file source audit found no private/generated
paths, account tokens, private keys, configured private client values or oversized
source files. Release formatting/strict checks: 714 files clean; analysis: no issues.
No dependency or application behavior change was required for publication.

Builds dispatched against the same immutable tag/source:

- [Windows setup](https://github.com/iax32/Orbit-Note/actions/runs/39592328992): success.
- [Signed Android preview](https://github.com/iax32/Orbit-Note/actions/runs/39592331854): success.
- [Additional repository CI](https://github.com/iax32/Orbit-Note/actions/runs/39592325509):
  still running at publication; not represented as passing.

Windows setup fixed version 1.0.2.3 and manifest version 1.0.2+3 match source.
Installer checksum, required runtime/server files and all four terminal font hashes
match the runner manifest and source. No packaging compiler was installed locally;
the existing hosted workflow supplies Inno Setup. Local configured Windows/server
rebuild succeeded in 27.2 s. Its numeric resource version is 1.0.2.3, displayed as
1.0.2+3; runtime siblings and font hashes are verified. Run
`build/releases/1.0.2/orbit_note.exe`. No app, server or setup program was launched.

Android downloaded APK hash matches its runner checksum. The runner's apksigner
verification reports valid v2 signing with the retained certificate
`9d426e5cb073eec911c459acfe29421da8274d9d3feb5466c955e96fd7eb6c84`.
Badging confirms org.orbitnote.app.preview, versionName 1.0.2, versionCode 3,
Orbit Note Preview label and org.orbitnote.app.MainActivity launcher. Thus the
package/key identity matches the preceding preview; physical update acceptance
is still outstanding. No keystore was distributed or replaced.

## Publication

[Orbit Note 1.0.2 — Windows & Android Preview](https://github.com/iax32/Orbit-Note/releases/tag/preview-2026-10-21)
was published at **2026-10-21 11:40:04 UTC** as a prerelease, preserving earlier
releases. All seven assets were uploaded to a draft, compared against GitHub's
reported SHA-256 digest, byte size and uploaded state, then published together.
Source tag association was rechecked. No ZIP release asset is distributed.

| Download | Bytes | SHA-256 |
| --- | ---: | --- |
| OrbitNote-Windows-x64-Setup.exe | 26,624,515 | c3e1cbb00e24ce0d00ca7565ccfcc4a6f6f7e3fca7a4e3435f659c3e965bc2df |
| OrbitNote-Android-Preview.apk | 133,710,518 | 5df5a76e1172d779eb247d2684aa3dfb3ab10425e431e6ce27dd0c59c63a3ca9 |

Release also includes Windows-package.json, Android-signature.txt,
Android-package.txt, release-manifest.json and SHA256SUMS.txt. Ignored evidence:
`.local/github-20261021-{source-audit,builds,downloaded,artifact-verification,uploaded,published,local-windows}.json`
and `release-assets/preview-2026-10-21/`. Private configuration, tokens, Vaults and
signing keys remain outside Git and the distributed artifacts.

## Limits

Windows is unsigned. Android remains a release-mode signed preview using
org.orbitnote.app.preview and the retained preview key, local-only for Google
sign-in, pending physical-device acceptance. Windows testing-account restrictions
remain. No claim of Wasm or physical clipboard/two-device acceptance.

Suggested next task: physical Android update/import and cross-device acceptance;
stop before implementing that follow-up.
