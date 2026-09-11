# Current task — PDF reading to game-development documentation

Status: delivered and validated, 2026-09-11.

The owner prioritized PDF reading and game-development documentation over the
previously suggested Rich insertion-menu task. This bounded FILE-05/11 and GAME-02
slice reuses the existing reader, repository commands and ordinary Markdown notes.
The GAME-01 project preset/type registry prerequisite remains deferred.

## Delivered

- Reader action creates a Research note, Game design decision or Playtest finding.
- Current page supplies a stable UUID source link; selected text, when permitted,
  supplies an exact quote and the first selected page instead.
- Documents open beside their PDF and retain its checksum as provenance.
- Editable Markdown sections cover findings, design tradeoffs, implementation
  references, playtest reproduction, impact and follow-up validation.
- Highlights can be filtered by title, selected quote or note/comment body;
  filtering survives closing/reopening the panel during the reader session.
- Password/comment dialogs use the existing restrained OrbitDialog surface.
- Read-only state disables creation; duplicate in-flight requests are blocked;
  failed saves report an error without publishing a phantom note.

## Required documentation and boundaries

Read [attachments](../features/attachments-and-research.md),
[game development](../features/game-development-and-teams.md),
[implemented formats](../architecture/implemented-formats.md) and ADR-0013/0014.
No package, schema, storage authority or architecture change. The starters are
ordinary editable content, not project presets, automatic task creation or a
new template engine. A multi-page quote records its first page, as before.
Search is literal and session-local. Source re-anchoring, precise region navigation,
underlines/strikeout, OCR and full Game Design Document presets remain planned.

## Validation

Formatting/zero-change check passed for 120 Dart files; analyzer clean; all 183
tests passed. Native PDF tests cover document menu actions, current-page/selected
text provenance, failed-save feedback, read-only disablement and highlight filters.
Controller tests cover all three starters, durable reopen, rejected input, failed
creation without phantom objects and unchanged original PDF bytes.

Windows release build passed in 42.1 seconds. The PDF panel capture was inspected.
Hidden startup reached input idle and responded with no stderr, but exposed no
main window for graceful close. Only the owned smoke process (PID 12312) was
terminated for cleanup; interactive launch/close still needs manual acceptance.
Evidence: .local/pdf-documentation-tests.log, .local/pdf-documentation-build.log,
.local/pdf-documentation-release-smoke.json and work/ui/pdf-highlights.png.

## Next recommended task

Precise PDF highlight-region navigation, including visible source-version mismatch
handling. Preserve original PDF bytes and existing annotation identities. Rich
insertion-menu polish remains queued behind the owner's PDF priority.
