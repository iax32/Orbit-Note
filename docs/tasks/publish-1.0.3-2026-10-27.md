# Publish Windows and Android 1.0.3 — delivered

User requests current source and both release builds on GitHub, explicitly without
tests, analysis, formatting gates or GitHub Actions runs. No new app features.

- Bump version to 1.0.3+4 for Android update compatibility.
- Build locally; restore missing Java/Android SDK in ignored workspace tooling.
- Reuse the original Android preview package and signing identity; never replace
  its key or publish signing/account secrets.
- Package the complete Windows runtime as a setup EXE and Android as an APK.
- Commit/push source with [skip ci]; use a preview tag outside the v* build trigger.
- Upload binaries and checksums through GitHub Releases, without running workflows.

Existing user Vaults and temporary personal PDFs are excluded from publication.
All source dependencies, including the required local pdfrx overrides, are included.

## Published result

- Public release: https://github.com/iax32/Orbit-Note/releases/tag/preview-1.0.3-2026-10-27
- Source commit: `1151e7f27599b4472e21a6d878719b8dc432e93b`, pushed to main with
  `[skip ci]`. Audited 320 application/platform/library/documentation/test/tool
  source files; no credentials, user Vaults, generated builds or private PDFs.
  The two binary vendor assets match the published pdfrx dependency exactly.
- Windows 1.0.3+4 built locally (104.1 s) and packaged as a complete setup EXE
  (25.5 s), 27,239,363 bytes. Existing registered Google desktop configuration.
- Android 1.0.3 / version code 4 built locally (677.2 s after restoring the missing
  SDK/Java toolchain), universal release APK, 139,462,466 bytes.
- Android package `org.orbitnote.app.preview`; original signing certificate
  SHA-256 `9d426e5cb073eec911c459acfe29421da8274d9d3feb5466c955e96fd7eb6c84`
  confirmed by APK signature metadata. Existing preview installations can update.
- Uploaded both installers, release-manifest.json, Windows-package.json and
  SHA-256 manifests; verified remote asset sizes and draft=false after publication.
- Windows setup SHA-256:
  `ed337c919d2e2403c6f4c2f7a0bf84496a27ddd8556ca908111c284b90496749`.
- Android APK SHA-256:
  `3a6a69009d5871c0983de685493235ee0f12d7ab0abd134b72890753dd0fa15e`.

No application tests, format/analyze gates or GitHub Actions were run for this
publication, per explicit user instruction. Builds and package/signature/upload
metadata were checked. README downloads now point to this release.

Android Google sign-in remains unconfigured (no distributor Android server client
in local configuration or repository variables). The APK retains the existing
local-only Google mode; offline and self-hosted collaboration features remain.
No physical-device acceptance or Windows code signing is claimed.

Suggested next task: configure the distributor Android Google registration against
the existing preview signing identity; do not change/regenerate the preview key.
