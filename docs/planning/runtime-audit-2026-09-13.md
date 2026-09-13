# Runtime audit verification — 2026-09-13

Scope: owner-supplied Gemini report and implementation prompt. Cloud sync is
excluded. The current worktree contains substantial earlier work; the report's
clean-worktree statement is outdated for this checkout. Preserve those changes.

| Finding | Current classification | Evidence before changes |
|---|---|---|
| TaskDetail custom status | CONFIRMED | Stored status is passed to a fixed five-item dropdown |
| TaskDetail stale blocker | CONFIRMED | Stored ID is passed to a dropdown limited to active Tasks |
| createTaskFromFinding blocker abuse | ALREADY FIXED | Current creation uses sourceNoteId and no blockedBy |
| Mixed folder deletion | CONFIRMED | Repository discovers contained objects from physical owner paths only |
| Mixed folder rename/move | CONFIRMED | _moveNotes updates physical Notes, not other owners' folder properties |
| Mixed batch Move | CONFIRMED | Explorer invokes moveNote for every selected object |
| Swallowed Note move errors | CONFIRMED | Controller catches and ignores move failure, then edits folder metadata |
| Connector endpoints | CONFIRMED | Bounds/reverse flags, generic minimum-size resize, no endpoint handles |
| Connector labels | CONFIRMED | _edit excludes arrow/line; painter draws no label |
| Canvas ancestors | CONFIRMED | Shell returns immediate parent/current only |
| Minimap padding clicks | CONFIRMED | Coordinates mapped without checking rendered content rectangle |
| Rich block reorder spacing | CONFIRMED | _moveBlock discards blank blocks and serializes the entire document |
| Heading collapse identity | CONFIRMED | Collapse keys concatenate heading level and text |
| Search title/syntax snippets | CONFIRMED | No title lookup; cleaned body removes query punctuation before match |
| Folder-name dialog validation | CONFIRMED | Dialog trims/submits names before repository validation |

Order: reproduce/fix TaskDetail, then recoverable universal folder commands and
Explorer entry points, then Canvas and editor/search edges. Existing native
folder recovery, editor undo and source-preservation tests remain mandatory.

## Reinspection and outcome

The table above records the initial audit. Subsequent shared-worktree changes had
already added connector labels/anchors, full Canvas ancestors, minimap clamping,
title/syntax snippets and duplicate-heading ordinals. Those changes were preserved
and regression checked. Reorder spacing and heading identity were PARTIALLY FIXED:
leading blanks were still lost, and title-based keys still changed on rename.
`createTaskFromFinding` was ALREADY FIXED and was not patched again. The original
clean-worktree claim was OUTDATED. No cloud engine/provider/auth implementation was
changed for this task.

### Task details

Fixed-value dropdowns asserted when saved statuses or blocker IDs were absent from
their item lists. TaskDetail now uses the saved View's Kanban preset, retains unknown
current statuses, and offers explicit missing/deleted/non-Task blocker entries.
Opening a detail pane does not rewrite stored metadata. Expanded dropdowns fit
narrow panes; successive property edits merge current controller state.

### Folder commands and data safety

- Deletion sends all contained Universal Objects to Trash, resets membership to
  Notes root, and removes empty physical folders. Restore does not recreate the
  deleted hierarchy. Attachment bytes are retained.
- Rename/move updates all descendants. Notes move physically; Canvas/View/Task/file
  owners retain their canonical owner paths and receive updated folder metadata.
  IDs and unknown properties remain intact.
- Mixed selection moves are one repository command. Notes moved together keep
  their relative links to one another. Controller failures remain visible and do
  not trigger a second metadata-only mutation.
- Native commands preflight hashes/collisions and keep durable staged recovery.
  Interrupted work rolls forward on reopen; external changes prevent overwrite
  and retain read-only recovery. Physical Note rename precedes metadata rewrite;
  failure attempts to return the untouched source to its original path.
- Portable folder names are validated inline using shared path rules, including
  reserved names and trailing spaces/dots. Generic object titles are unaffected.

### Canvas

Free connectors now have explicit world endpoints, with zero-sized axes allowed.
Endpoint handles change one end; whole movement transforms both; gesture history
supports undo. Existing anchors, routing, markers and label editing remain in use.
Bounds/reverse flags remain serialized for older readers; legacy records are read
without bulk rewriting. Connector labels are persisted and painted at the path.
The existing ancestor walk handles deep nesting with a visited set; minimap taps
are clamped to the rendered content rectangle rather than extrapolated through
letterbox padding. The regression coverage for these latter two features is
limited; no live deep-tree navigation session was performed during this run.

### Notes and search

Block moves preserve leading blanks, unequal trailing gaps and CRLF. A necessary
separator at a new paragraph boundary is added without normalizing other blocks.
Moved-block focus uses its new offset instead of matching duplicate source text.
Heading collapse uses transient block IDs, follows title edits and block movement,
and restores matching pane state using a document hash. IDs do not enter Markdown.
Title and Markdown-syntax snippets were already present on reinspection and passed
existing regression tests.

### Tests and major files

New suites: `task_detail_safety_test.dart`, `universal_folder_safety_test.dart`,
`connector_endpoints_test.dart`, `runtime_editor_preservation_test.dart`.
Coverage includes custom statuses, broken blockers, mixed-folder identity/reopen,
preflight failure, interrupted recovery, external edit protection, relative links,
legacy/zero-axis connectors, endpoint drag/undo, source spacing and collapse restore.
The Explorer test now checks invalid folder input stays open without mutation.
The workflow test adapter explicitly models folder-command support; real recovery
is tested separately with native temporary Vaults.

Principal implementation: `workspace_views.dart`, `workspace_folders.dart`,
`native_folder_commands.dart`, storage interfaces/native adapter,
`workspace_controller.dart`, `note_folder_explorer.dart`, `note_path_links.dart`,
`path_safety.dart`, Canvas scene/connectors/editor/painter, `rich_markdown_editor.dart`.

### Boundaries and deliberately deferred work

- Browser storage cannot provide this native recoverable folder command and rejects
  it before writes. No unsafe sequential fallback is used.
- Native multi-file recovery is roll-forward, not filesystem-wide atomicity.
  An external edit during recovery can require manual review of retained inputs.
- Heading state may reset after arbitrary external structural changes. Full native
  cross-block selection and persistent Markdown block IDs are not introduced.
- Existing attached connectors follow their referenced placements; translating a
  connector does not move the objects it references.
- Live multi-device sync/provider/OAuth work remains deferred by the owner prompt.
- Suggested next task: browser-safe transactional folder commands with failure
  tests, before enabling mixed-folder mutations on that adapter.

### Final validation

- `dart format lib test tool` and no-change format check: 189 files, clean.
- `flutter analyze`: no issues (7.6 seconds).
- `flutter test`: **463 passed, zero failures**.
- `flutter build windows --release`: success (45.8 seconds).
- Process smoke: newly built EXE remained running after 5 seconds; only that
  smoke process was closed. This checks startup, not an interactive manual tour.
- Evidence: `.local/runtime-final-{format-check,analyze,tests,windows,smoke}.log`.

Windows EXE: `C:\Users\iax\Desktop\Orbit Note\build\windows\x64\runner\Release\orbit_note.exe`
Release directory: `C:\Users\iax\Desktop\Orbit Note\build\windows\x64\runner\Release`
