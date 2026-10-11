# Search workspace — 2026-10-01

## Scope

Owner requests useful new features that fit Orbit rather than decorative clutter.
Deliver a coherent LNK-01/12 discovery subset: named query/filter/sort recipes,
recent searches actually opened or saved, folder/tag/match filters, completed-task
exclusion, relevance/updated/title sorting, matched-text emphasis, read-only
previews, keyboard selection/opening, history clearing and saved-search management.

Shared search stays bounded to the first 100 location results. Filters/sorting
operate on that set; scope queries and pagination remain future work. Existing
FTS, source references, PDF tools and object identities are unchanged.

## Implementation

SearchView moves out of the large workspace views file, exported compatibly.
Domain SearchOptions and SearchLibrary contain view/filter and local recipe logic.
Device settings gain additive searchWorkspace v1 map, at most 24 named searches
and ten recent opened/saved queries. No note bodies/results are persisted here.
Unknown library fields/entries survive ordinary edits; future library versions
remain read-only. Old device settings keep empty defaults. Saving an existing
case-insensitive name replaces its recipe, with a notice in the dialog.
Saved recipes reference filter strings rather than snapshotting object content.

Preview uses the bounded matched passage and existing object context, with an
explicit Open at match action. Wide panes show an optional side panel; smaller
panes use a dialog. More filters are disclosed on demand. Keyboard arrows/Enter
operate while the query field is focused; ordinary buttons retain normal keys.
Escape closes the side preview or clears the query. History is recorded on open
or save, never each partial typed query, and has a clear action.

## Validation

- Format: `dart format lib test tool`, plus no-change check: 349 files, no changes.
- Final analyzer: no issues, 8.0 seconds (see `.local/search-workspace-analyze.log`).
- Eight new tests cover combined filters/stable sorting, unknown/future settings,
  recipe reopen and failed-write retry, stale-query suppression, keyboard/history,
  save/restore/remove/undo, readable excerpts and enlarged small-pane layout.
  **These tests could not run**: Windows Application Control rejected
  `flutter_tester.exe` before test execution. Focused run failed to load both
  files. Full `flutter test --no-pub --fail-fast` attempt failed at the first loader
  for the same reason; stalled cleanup was interrupted. Logs:
  `.local/search-workspace-focused.log`, `.local/search-workspace-full-tests.log`.
  Previous 1,027 passes predate this feature batch and are not new validation.
- Pure Dart diagnostic passed: recipe/unknown metadata, JSON settings roundtrip,
  bounded history, future-version rejection, compound filter/sort, metadata-safe
  undo that preserves history, and readable excerpts that leave source intact.
  Evidence: `.local/search-workspace-domain.log`. This does not replace the
  blocked widget or repository failure/reopen tests.
- Native in-memory review build succeeded (62.2s). Verified saved recipe restore,
  populated results, query arrow selection, side preview, exact highlighted Note
  navigation from Open at match, More filters disclosure, new recipe save and its
  appearance on the start page. No user knowledge was opened or changed.
  Small-pane/enlarged-text, remove/undo, error/retry and every filter combination
  still need the blocked automated acceptance checks. Final excerpt cleanup was
  applied after the review and validated in the pure Dart diagnostic.
- Final normal `lib/main.dart` Windows release built successfully (58.3s), replacing the
  temporary fixture: `.local/search-workspace-windows.log`.
  Final normal release launched, showed Home/Saved locally and opened the new
  empty Search workspace. No user content was edited. A final
  result-row refinement avoids repeating the title as a name-match excerpt.
- Android was not rebuilt; the Android SDK remains unavailable.

EXE: `C:\Users\isa\Desktop\Orbit Note\build\windows\x64\runner\Release\orbit_note.exe`.
Release directory: `C:\Users\isa\Desktop\Orbit Note\build\windows\x64\runner\Release`.

Implementation is delivered with an explicit validation gap, not marked fully
accepted. The OS policy needs an authorized resolution before Flutter test
acceptance can be completed; no security policy was changed or bypassed.

## Next suggested task

Run the new search workspace tests and the full suite once Windows permits the
existing Flutter test runner. Stop before adding more product scope. The next
feature candidate remains rebuildable PDF page-text indexing.
