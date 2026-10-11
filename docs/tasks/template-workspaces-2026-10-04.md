# Template workspaces refinement — 2026-10-04

The explorer already had durable scaffolds for University, Game Dev, and
Reverse Engineering, but creation only asked for a name. That made the first
workspace feel generic and hid useful context behind defaults.

## Delivered

- University Course creation now collects course code, semester, ECTS, and
  lecturer. The values are stored on the overview object and printed into the
  generated course overview.
- Game Project creation now collects genre, target platform, and engine before
  scaffolding the GDD, boards, canvases, tasks, and milestones.
- Reverse Engineering creation is visible again from the Notes explorer and
  collects architecture, file format, target platform, and version before
  creating the connected research workspace.
- Added Research, Content Pipeline, and Personal Planning Kanban presets with
  useful stages and exposed them in both board selectors.
- Added Software Design Brief, Research Log, and Book & Course Reading note
  templates with practical fields, checklists, provenance, and follow-up
  sections.

Existing controller methods, object IDs, folder layouts, and unknown metadata
remain compatible. The new forms only supply optional values to the existing
storage boundary.

## Validation

- Focused University, Reverse Engineering, Game Dev, folder explorer, and note
  template tests pass.
- `flutter analyze --no-pub`: no issues found.
- Strict format across `lib`, `test`, and `tool`: 382 files, 0 changed.
- Full `flutter test --no-pub`: **1,210 passed**.
- Windows release build succeeded; output is
  `build/windows/x64/runner/Release/orbit_note.exe`.

## Next boundary

The next template pass should add saved, user-editable template presets with a
preview of the folders, views, and starter objects before creation. That needs a
small preview model and migration-safe persistence rather than more hard-coded
menu entries.
