# Release hardening — 2026-10-05

This pass freezes the first public release to the local-first Windows x64
build. It does not claim Android, iOS, Web persistence, Google Drive sync, or
full PDF annotation parity without platform and credential evidence.

The candidate version is `1.0.0+1`; the release workflow requires tags to match
that value exactly (for example, `v1.0.0+1`).

Local validation for this pass: strict Dart formatting, `flutter analyze`, the
recovery regression tests, and the full Flutter suite (1,265 tests) pass.
The local Windows release command is currently blocked before compilation by
Flutter's plugin symlink check because Developer Mode is disabled on this host;
the Windows CI job remains the packaging verification path.

## Implemented in this pass

- Release tags now run formatting, analysis, PDFium setup, and the full Flutter
  test suite before either platform is built.
- Release tags must match the version declared in `pubspec.yaml`.
- Stable release workflow packages only Windows x64. Android remains a CI debug
  validation target until its own acceptance gate is approved.
- Published releases include a `SHA256SUMS` file for the Windows artifact.
- The command palette now exposes a recovery review dialog. It lists retained
  interrupted-save/conflict files, previews bounded text safely, and exports a
  copy without applying or deleting the retained original.
- README platform claims now match the stable release workflow. Web remains an
  experimental local preview until browser persistence and import are validated.

## Required before publishing an RC

- Choose and verify the Windows release version/tag and repository ownership.
- Complete Windows code-signing or document the unsigned portable distribution.
- Validate the exact Windows ZIP and checksum on a clean Windows machine.
- Exercise the recovery review dialog alongside backup/restore, PDF annotation,
  editor, Canvas, DPI,
  clipboard, and drag/drop acceptance matrix in the [Windows 1.0 acceptance
  matrix](windows-1.0-acceptance-2026-10-06.md).

## Known product boundaries

Google account connection does not synchronize Vault contents. PDF OCR,
redaction, signatures, threaded comments, and full page editing remain outside
the local-first release cut. Android/iOS/Web remain outside the 1.0 artifact
until their platform acceptance is completed.

