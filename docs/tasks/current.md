# Current task — Explorer actions and keyboard navigation

Status: implemented; final validation in progress, 2026-09-11.

The owner asked to continue documented features. This is the next bounded NAV-02/
NAV-10 slice from the visual pass: explorer rows and context-menu interaction.
Preserve existing repository commands and the prior Windows baseline.

## Delivered

- Shared OrbitExplorerRow, with clear hover/selection/focus and restrained surfaces.
- Right click and Shift+F10/context-menu key open the same actions as the visible
  more button, without opening the note as an incidental side effect.
- Folder Left/Right collapse/expand; Enter/Space activate the focused row.
- Copy note reference produces a stable-ID wiki reference with a readable title.
- Existing Open beside, Move, Trash, folder create/rename/move commands retained.
- Mutation menu items disabled for read-only workspaces/unsupported note formats.
- Folder naming dialog uses the existing OrbitDialog surface.

## Validation

Run formatting, analyzer, all tests and Windows release. Exercise real explorer
right-click, keyboard menus, side-by-side opening, collapse/expand, persisted
collapse state on reopen and exact note-body preservation. Screenshot the context
menu. Existing move/history/conflict tests remain the safety foundation.

No data format, storage authority, migration or architecture change. Notes/slash
menus and inspector/split transitions are not implemented in this slice.

## Next recommended task

Searchable, keyboard-navigable Rich slash and block insertion menus, reusing Orbit
controls and preserving source ranges, undo and caret state. Read the editor spec
and existing source-projection tests before starting.
