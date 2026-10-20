# Source and Windows/Android preview publication

Status: in progress, 2026-10-20. User explicitly requested updating GitHub source
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
