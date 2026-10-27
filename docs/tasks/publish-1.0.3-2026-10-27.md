# Publish Windows and Android 1.0.3 — in progress

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
