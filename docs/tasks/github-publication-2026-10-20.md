# Source and Windows/Android preview publication

Status: published, 2026-10-20. User explicitly requested updating GitHub source
and uploading Windows and Android releases. This supersedes earlier tasks' local
build-only publication limits. No product feature work is included.

## Plan

- Review accumulated source additions and exclude ignored account configuration,
  tokens, signing keys, local Vaults, SDKs and compiled outputs from Git.
- Increment version to 1.0.1+2, preserving Android preview package/key continuity.
- Keep configured Windows Google sign-in and local runnable EXE folder. Package
  its complete runtime as a per-user Windows setup EXE without requiring a ZIP.
- Dispatch Android's existing signed-preview workflow and verify downloaded APK
  signature, certificate, package identity, version and checksum.
- Push source without force, publish an explicitly labeled dated GitHub preview,
  and verify downloadable assets and source association. Record actual checks,
  known platform limits and one suggested follow-up.

## Validation basis

The preceding editor transaction task validated the application source with
688-file formatting/strict checks, clean analysis, 214 focused tests and the full
suite: 2,628 passed, two existing skips. This publication changes version and
packaging; app behavior is unchanged. Release builds and packaging checks remain
pending. Android physical-device acceptance and app signing for Windows are not
claimed. The original lost Android production key is not replaced: preview uses
the already authorized dedicated key and `org.orbitnote.app.preview` identity.

## Source and build preparation

Source pushed without force to `main` at
`b669857503f6e89e80feecdf18f0142bcd680d7a`. The 1,027-file publication audit found
no private/generated paths, configured private client values, account tokens,
private PEM keys or oversized source files. Two upstream license trailing spaces
were normalized without changing license wording. Font bytes are unchanged.
Final local strict formatting: 688 files unchanged; analysis: no issues, 76.3 s.
Dependency resolution retained the lockfile and package versions.

The local attempt to install a packaging compiler was rejected by automatic
approval review as blocked by policy. No compiler was installed locally. The
Windows Actions runner already includes Inno Setup; the new separately dispatched
workflow uses it, retaining configured desktop Google sign-in through repository
variable/encrypted native-client secret. Neither value is committed to source.
The setup allowlist includes the app EXE, runtime DLLs, data assets, server,
launcher, server instructions and license. No app launch/autostart/service or
user-data deletion is configured. Packaging PowerShell syntax validation passed;
actual setup compilation subsequently passed on the hosted runner.

Dispatched against the same source commit:

- [Windows setup](https://github.com/iax32/Orbit-Note/actions/runs/39456556186).
- [Signed Android preview](https://github.com/iax32/Orbit-Note/actions/runs/39456550528).
- [Repository CI](https://github.com/iax32/Orbit-Note/actions/runs/39456549832).

## Published release and verification

[Orbit Note 1.0.1 preview](https://github.com/iax32/Orbit-Note/releases/tag/preview-2026-10-20)
published at **2026-10-20 18:35:43 Europe/Vienna**. Tag
`preview-2026-10-20` resolves exactly to the source/build commit above. It is
explicitly a prerelease; older stable releases were not overwritten.

Both hosted builds completed compilation, packaging/signature checks and artifact
upload successfully. Downloaded artifacts were checked before publication:

- Windows setup fixed version 1.0.1.2, application version 1.0.1+2 and exact source
  commit. Required EXE/DLLs, data, server/launcher/instructions are in its runtime
  manifest. All four terminal font hashes match source. Installer hash matches
  the runner manifest. No installer or application was launched on the user's PC.
- Android versionName 1.0.1, versionCode 2, preview application ID/label and launcher
  match expected identity. APK checksum matches the runner; v2 signature verified
  with the existing preview certificate
  `9d426e5cb073eec911c459acfe29421da8274d9d3feb5466c955e96fd7eb6c84`.
- Seven uploaded assets, including manifests/signature/package evidence and
  SHA256SUMS, have GitHub-reported SHA-256 digests and sizes matching local files.
  Evidence: ignored `.local/github-publication-{artifact-verification,published}.json`
  and `release-assets/preview-2026-10-20/`. No ZIP asset is distributed by this release.

| Download | Bytes | SHA-256 |
| --- | ---: | --- |
| `OrbitNote-Windows-x64-Setup.exe` | 26,477,930 | `b215ffbac9fa0a5d9a4dcfe1a767c5618fba48be73a51e6923469c020f778927` |
| `OrbitNote-Android-Preview.apk` | 132,284,374 | `42779e44f01a79ae8c0034d473a45346de523ec35d48bf2710d85507982a0363` |

The local Windows folder was rebuilt in 24.9 s with registered desktop Google
configuration and the standalone server. Its runner version is 1.0.1+2. Flutter
reused the unchanged previously validated Dart payload, whose hash matches the
preceding task; publication only changed version/packaging. Run
`build/windows/x64/runner/Release/orbit_note.exe` with its runtime siblings.

## Remaining limits and next task

Windows is unsigned. Android is local-only for Google sign-in, uses the existing
preview identity, and has not undergone a physical-device acceptance pass. Windows
Google testing-account/consent restrictions still apply. Self-hosted collaboration
remains a preview. No personal Vaults, tokens, invitation keys or signing keys were
published. No shutdown or desktop-control testing was performed.

Additional repository CI was still running unit/widget tests at publication;
formatting/analysis had passed. This is separate from the successful packaging
checks and the prior local 2,628-test run. Its status is linked explicitly in the
release notes rather than represented as passing.

Next suggested task: physical Android update/import and cross-device acceptance
using the published preview. Stop before performing that follow-up.
