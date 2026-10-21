# GitHub Windows/Android publication — 2026-10-21

Status: in progress. Owner explicitly requested pushing the accumulated source and
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
only version/docs are updated. Publication checks remain pending.

## Limits

Windows is unsigned. Android remains a release-mode signed preview using
org.orbitnote.app.preview and the retained preview key, local-only for Google
sign-in, pending physical-device acceptance. Windows testing-account restrictions
remain. No claim of Wasm or physical clipboard/two-device acceptance.

Suggested next task: physical Android update/import and cross-device acceptance;
stop before implementing that follow-up.
