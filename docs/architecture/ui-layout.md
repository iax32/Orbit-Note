# UI and layout system

Status: accepted product direction; basic two-pane persistence now exists. The
[implementation status](../planning/implementation-status.md) separates it from advanced docking.

## Default experience

Desktop grows toward an activity rail, contextual left sidebar, center tabs/panes,
optional right inspector, and a modest status area. Calm defaults prioritize capture,
reading and finding content. The inspector reflects the selected object (properties,
backlinks, tasks, provenance), independent of the view showing it.

Narrow phones use a single primary view with accessible bottom/drawer navigation;
tablets can reveal more context. Adapt based on usable width and input, not a hard
platform-name check. Preserve focus, text scale, reading order and touch targets.

## M0 subset

Two destinations: **Home** and **Inbox**. At width >= 800 logical pixels use a
labelled `NavigationRail`; below 800 use `NavigationBar`. Home shows a short welcome;
Inbox shows an honest empty state. Neither creates notes or claims persistence.
Riverpod owns only selected destination state; the shell displays the corresponding
view. System light/dark theme with built-in accessible Flutter controls is enough.
No sidebar tree, tabs, custom docking, editor, workspace picker, or menu framework yet.

## Future layout model

A versioned layout tree contains split nodes (axis, bounded ratio, children) and
tab groups (stable IDs, active tab, view descriptors). A descriptor identifies
view kind, workspace/scope/object IDs and presentation state. No live widgets,
provider internals, executable code, or copied note bodies are serialized.

Validate depth, counts, dimensions, duplicate IDs, supported view types and active
tabs. Restore missing objects/plugins as informative placeholders. Persist device
window bounds locally; shared presets hold portable choices. Off-screen windows
return to a visible display. Space selection changes context/layout, not ownership.

Introduce command/view registries once multiple real consumers need them. Features
register views and actions; the shell decides where to host them. A panel is a
container, a view is a presentation, and neither owns knowledge.

## Customization ladder

1. Theme, density, font scale, hide/resize panels.
2. Reorder navigation, tabs/splits, pin and save workspace layouts.
3. Contextual Spaces, focus/Zen, dashboards with configurable widget grids.
4. Semantic theme tokens, keybinding/menu editors, shareable layout/theme files.
5. Plugin panels/views/widgets and eventually detached windows/multiple monitors.

Prefer semantic Flutter design tokens to arbitrary CSS or executable theme files.
Validate color/contrast, sane size limits and unknown fields. Keybinding conflicts
need discoverable resolution. Layout changes must be undoable/resettable. Maintain
an always-reachable “Reset layout” command plus a startup safe-mode recovery path
that bypasses broken layouts and disabled plugins; this comes with customization,
not as an unused M0 subsystem.

The command palette eventually becomes a central entry point for navigation,
search, creation and actions. Shortcut defaults must be reconciled and documented
when implemented; earlier chat shortcut examples are suggestions, not binding mappings.

Later [visual design](../design/visual-design.md) and [motion](../design/motion.md)
define the branded direction. M0's explicit system theme and tiny shell remain
unchanged. [Resume Context](../features/home-and-work-sessions.md) needs versioned
view descriptors and personal state separation before arbitrary restoration.
