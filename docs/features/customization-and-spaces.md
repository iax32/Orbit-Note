# Customization, layouts, themes and Spaces

Status: planned M5+; advanced keymaps/multi-window/plugins later.
Sources: S03, S06 in the [source map](../product/conversation-extraction.md).
Architecture: [layout model](../architecture/ui-layout.md).

## Purpose and workflow

Implemented 2026-10-08: named device-local Spaces/layouts can be saved, switched,
updated, renamed, duplicated and removed. Spaces restore tabs/panes/view state,
scope, dashboard and optional appearance; layouts restore pane arrangement.
All-Vault restores the prior context. Home supports adding/removing/reordering
tasks/recent/projects/inbox/views/shared-view widgets with responsive column spans,
apply/cancel and default reset. Unknown versions/widgets and missing objects retain
recovery paths. Settings/Home/rail expose controls; Ctrl+Shift+Space opens Spaces.
No files move or clone. Arbitrary docking, multi-window, portable import/export,
keymap editing and startup safe-mode expansion remain separate requirements.
See [ADR 0022](../adr/0022-smart-views-spaces-and-task-planning.md).

Implemented 2026-10-03: device-local whole-app zoom (75–200%) from Settings or
Ctrl +/=, Ctrl minus, Ctrl 0. Reset works with a dialog/editor focused. Layout,
icons and shared controls enlarge through semantic density tokens; text zoom
composes with OS accessibility scaling. The actual viewport, device pixel ratio
and keyboard insets stay unchanged; the root is not painted through a scale
transform. Stored document font sizes remain unchanged. Local wheel/pinch camera/PDF gestures
remain. Advanced layout/keymap/Spaces requirements are separately scoped.

The interface should adapt to the user. Someone can keep a quiet writing layout;
another can combine a board, graph, tasks and references across monitors. The same
workspace should allow both through progressive controls, saved layouts and
contextual Spaces with reliable recovery.

## Requirements

| ID | Observable behavior |
|---|---|
| LAY-01 | Basic controls offer light/dark/system appearance, font size, comfortable/compact/touch density and panel resizing/hiding without editing config files. |
| LAY-02 | Advanced layout can move/reorder the activity rail, explorer, inspector, tabs and supported toolbars; panels may dock where the layout supports them. |
| LAY-03 | Save, name, duplicate, switch, rename and remove layouts such as Writing, Research, Planning, University, Reading and Brainstorming. Removing a layout does not delete its objects. |
| LAY-04 | A Space remembers context such as layout, tabs, scope filters, dashboard, active project and optional appearance overrides inside one workspace. |
| LAY-05 | Home/dashboard customization lets users add, remove, resize and reorder supported widgets through an explicit customization mode. |
| LAY-06 | Semantic theme tokens cover surfaces, text, borders, accent/status colors, fonts, radius, spacing and density; theme files are versioned data, not arbitrary executable CSS. |
| LAY-07 | A keybinding editor lists commands and active shortcuts, detects conflicts and can reset bindings; optional Vim/Emacs/IDE-style presets require separately scoped behavior. |
| LAY-08 | Create menus and toolbars can show relevant object types/templates/actions, including extensions when available; removed items remain discoverable through supported navigation. |
| LAY-09 | Import/export layouts/themes validates versions, sizes, unknown views and references, with a preview and fallback for missing plugins. |
| LAY-10 | Reset current layout, reset UI settings and startup safe mode remain reachable after broken customization; resets preserve knowledge and recovery history. |

## Concrete examples

**Writing:** one document, narrow readable text width, minimal surrounding panels.
**Research:** sources/PDFs on the left, note in the center, citations/backlinks right.
**Planning:** a board above task and calendar views. **University Space:** courses,
papers, lecture notes and deadlines scoped to University. **Development Space:**
project notes, architecture board, tasks and optional integration panels.

A Space is a saved context, not another filesystem vault or security boundary.
Switching Space must not move files or clone objects. A “Shared Team” context from
the chat will require an actual shared-workspace ownership model underneath it;
its label alone cannot grant access.

## Persistence and proposed rules

Store serializable view descriptors and bounded layout trees. Keep device-specific
window bounds separate from portable presets. Proposed default: a Space overrides
only settings the user explicitly assigns; otherwise it inherits workspace/device
defaults. Unknown plugin panels reopen as placeholders with a removal/recovery
option. Removing a plugin does not delete its referenced content.

Theme contrast and minimum sizes need validation/fallback. A shortcut reset cannot
make the recovery path inaccessible. A layout import should not unexpectedly enable
network-capable plugins. Changes in explicit Customize mode should support preview,
apply/cancel and restoring a known-good state. Exact schema/precedence must be
confirmed when persistence is implemented.

## Acceptance scenarios

- LAY-03/04: switch Writing ↔ Research Spaces and restore tabs/scopes without extra objects.
- LAY-05/09: import a dashboard referencing an unavailable widget; preserve other
  widgets and display a stable placeholder instead of failing the whole Home view.
- LAY-07/10: create a shortcut conflict and hide navigation; use the documented
  recovery route to reset UI without changing a note, relation or canvas placement.
- LAY-01/06: apply a poor-contrast/oversized token set and obtain a readable fallback.

## Delivery

Start with standard system theme in M0, then basic preferences and real pane needs.
Save layouts before introducing a full editor; add Spaces and dashboards as separate
tasks. Community theme names in the chat are inspiration, not bundled assets or
third-party dependencies selected for this repository.
