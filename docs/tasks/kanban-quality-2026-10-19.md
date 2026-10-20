# Kanban and project-board quality

Status: validated, 2026-10-19. Owner requests subtle issues that become visible
in large/specialized projects. Scope: existing VIEW-01/02/04/06 collection boards,
safe mutations/creation, imported/unknown data, collection switching and narrow
layouts. No new feature layer, schema, dependency or personal Vault changes.

Plan: reproduce reserved-name column collisions, stale callbacks, failed/delayed
inline creation, membership disagreement and read-only controls. Reuse canonical
queries and validated folder/object commands, retain current/unknown data and
preserve failed drafts. Exercise native move/reopen and synthetic large/lazy
fixtures; format, analyze, full tests and configured release builds. No desktop
control or shutdown. Stop after reporting this batch and one suggested next task.

## Implementation

- Replaced the board's duplicate per-object membership filter with the shared
  canonical query. Avoids reconstructing/scanning member lists for every card and
  disagreement between manual and course membership. Writable-member maps follow
  the query result identity, including its relative-date cache invalidation.
- Namespaced private project/folder column keys distinguish real `none`/`root`
  names from missing values; authored metadata is unchanged. Group lookup uses
  one ID Set; columns and vertical cards are built lazily.
- Captured controller, definition, workspace generation and view epoch guard old
  drop/option/completion callbacks. Deleted/unrelated/read-only sources cannot be
  edited through retained controls. Checkbox changes merge latest source data;
  no-op drops do not produce unnecessary dirty state.
- Folder drops route through the validated move/flush command. Failed commands
  report errors without presenting a metadata-only move. Source identity/body and
  unknown data survive native save/reopen.
- Inline Add captures source context, rejects duplicate submits and merges latest
  original manual membership after async creation. Failure retains typed titles
  for retry; disposed/switched views do not receive old setState callbacks.
  External regrouping keeps the title but requires a new deliberate column choice.
- Unsupported grouping/preset/query values show preserved-data states. Read-only
  definitions disable add, completion, configuration and dragging.
- Toolbar controls, columns and preview use actual pane bounds and text scaling.
  Narrow previews replace the deck instead of squeezing it to unusable width.
  Preview focus now makes the existing Escape label functional. Columns/cards
  remain readable with long paths/tags; originals remain unchanged.

## Validation

`test/kanban_quality_test.dart` covers reserved-name collisions, failed creation,
stale/current-data controls, unrelated/deleted sources, read-only settings,
unsupported definitions, delayed/single-submit creation with concurrent members,
course/manual membership, no-op drops, lazy project groups, enlarged-text preview,
retry/regroup drafts and a native folder move/reopen in an isolated temporary root.
No personal Vaults or desktop-control tooling are used.

The 180-project fixture mounts fewer than 15 columns and searches an off-screen
source. The native fixture verifies file relocation, removal of the old path,
retained Markdown body and unknown metadata after reopening. A 390×844 / 200%
text preview capture is at `work/ui/kanban-narrow-preview.png`. These are synthetic
headless checks, not a physical pointer/touch performance guarantee.

The first reproduction attempt stalled during loading and was stopped; it is not
counted as a completed test run. A subsequent matrix exposed actual toolbar
overflow and missing preview Escape focus; both received targeted fixes. One
read-only test initially targeted a RawTooltip instead of its IconButton and was
corrected. The external-regroup fixture also needed to cancel its simulated-clock
autosave timer before pumping frames; its targeted rerun and final matrix pass.

Final focused checks: **45 passed**, including **18 new regressions**. Required
`dart format lib test` and strict check pass across **669 files**; analysis reports
**no issues** (7.9s). Scoped `git diff --check` passes with existing CRLF notices
only. Logs: `.local/kanban-quality-{format,format-check,analyze,final-focused}.log`.
Full suite: **2,503 passed**, **2 existing skips**, 5m34s, with
`flutter test --no-pub --concurrency=6 --reporter expanded` and the existing
bundled Python runtime for IDE fixtures. Skips remain native Windows symlink
permission and manual real-Google-account consent/synthetic-upload acceptance.
`.local/kanban-quality-tests.log`.

## Releases and boundaries

- Configured Windows release: **passed**, 130.8s, retaining the existing Google
  desktop registration. Standalone server rebuilt without starting a server or
  packaging keys. `.local/kanban-quality-windows-build.log`.
- Standard JavaScript web release: **passed**, 121.1s. Existing Google Identity
  Wasm dry-run incompatibility and missing Cupertino font-family warnings remain;
  this does not claim a Wasm release. `.local/kanban-quality-web-build.log`.
- Runtime verification confirms the EXE, Flutter/PDFium/SQLite DLLs, ICU/Dart/assets
  and standalone server/launcher. Both payloads are newer than current source
  inputs and differ from the prior collection build. Both font manifests retain
  four OrbitTerminal faces, each hash matching its source asset.
  `.local/kanban-quality-release-verification.json` records SHA-256:
  Windows `data/app.so`, 24,576,912 bytes,
  `B9553DE6B655CA5F254025FCEE0D07748663B9CC72C5EAB6B642943C633D0530`;
  web `main.dart.js`, 10,512,832 bytes,
  `7DCDBF999FB62896619757354E2DD10F4069EC4F0614D917DB09311A0C92AAD1`.
- No app/test/standalone-server process remains running. Runnable Windows app:
  `build/windows/x64/runner/Release/orbit_note.exe`, with adjacent bundle files.

Physical-device pointer/touch acceptance remains unverified; no desktop control
was used. No personal Vaults, schema, dependencies or unrelated changes were
altered. No shutdown occurred. This does not claim all application bugs are fixed.
Legacy creation defaults remain, including generic task creation in the Other
type group; a dedicated type-specific creation flow remains a separate audit.

Suggested next task: specialized-object creation flows, including the generic
Other type group. Stop before implementing that next batch.

Follow-up: the Other-type task fallback and hidden-type creation are corrected in
[creation/source workflow quality](file-workflow-quality-2026-10-19.md). The record
above describes this earlier batch's boundary, not current remaining behavior.
