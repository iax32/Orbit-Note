# UI and layout system

## Settings navigation and code defaults — 2026-10-23

The existing SettingsView API is retained through its original export, with its
implementation extracted to settings_view.dart. Category/search/scroll state is
transient. Actual preferences use the existing controller updateSession/device
settings path. No new settings database or package is introduced. Resets change
only the selected section's fields, capture current values at confirmation, and
reject Undo after a touched value or owning Vault/session changes.

The flat session adds defaultCodeWrap (false) and bounded codeFontSize (14,
10–26 px), preserving unknown/old fields. Existing monoFontFamily/showLineNumbers
now reach code controls through OrbitCodePreferences. Font/size can update live
without replacing text controllers; new panes inherit wrap/number defaults and
local pane choices remain. Classic blueprint is accepted by the existing paper
choice validator. [Evidence and limits](../tasks/settings-workspace-2026-10-23.md).


## Semantic color propagation — 2026-10-23

OrbitColors is the shared UI palette; Material defaults receive explicit text,
input, floating and focus tokens. Common object/status/priority helpers keep
navigation, collections and graphs consistent. Every built-in is calibrated
against actual state surfaces; explicit role overrides retain their authored
values. New preferences follow the theme accent; preset accent shades adapt
without rewriting the saved choice. Recovery resolves the current base palette
separately from overrides. Code token caches retain parsing but refresh color
spans on palette changes; Canvas/minimap repaint/cache keys include semantic
colors. Interactive grid ink uses canvasGrid, while publication rendering and
explicit drawing/object colors retain their independent semantics. No storage
schema or authority change. [Evidence and limits](../tasks/semantic-color-system-2026-10-23.md).


Status: accepted product direction; basic two-pane persistence now exists. The
[implementation status](../planning/implementation-status.md) separates it from advanced docking.

## Default experience

Device-local appearance can follow OS brightness within a matched palette family.
The effective member is derived at render time; OS changes do not rewrite the
saved palette or trigger persistence/editor replacement. Manual selection disables
following; disabling following pins the visible member. Remembered Space appearance
includes the preference, with old fixed descriptors defaulting to manual. Preview,
gallery and theme export share app resolution. Unpaired themes retain their authored
colors. [Behavior and validation](../tasks/system-appearance-2026-10-22.md).

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

## Enlarged text and dialog layout

The shared palette browser (2026-10-22) builds at most six cards per page in both
Settings and Theme Gallery. Search and mode/collection filters do not change the
active preference until applying a palette. Show active resets filters/page;
paired switching reveals the destination's collection/mode/page. Controls wrap,
cards stack at enlarged text, and the existing settings/dialog owns scrolling.
No nested full-gallery scroll surface or fixed-height text cards are introduced.

Shared Orbit dialogs scroll their headings with content and retain a separate
action footer. Settings controls move below labels when text size or available
width makes a two-column row impractical. Dropdowns and theme controls wrap or
stack without clamping text scaling. Theme gallery/generator secondary tools
belong to scrolling content, keeping Close/Cancel/Apply reachable in short windows.

PDF connected notes/review and Canvas inspectors follow the same rule: headings,
filters, item labels, and action groups wrap or stack at narrow widths and enlarged
text sizes. Long source warnings remain readable. Canvas layers use lazy slivers
in the heading's scroll surface, with recovery/close actions in the fixed footer.
Card inspectors fit the actual board viewport and scroll title, source warnings,
details, and footer actions together below wrapping inspector controls. Text
scaling is never clamped to make a panel fit.

PDF navigation dialogs use wrapping, variable-height lazy rows in a shared scroll
surface for headings, filters, and results. Keyboard selection reveals measured
row geometry; rows taller than the viewport reveal their beginning. Bookmark
previews precede the list, while Close/Open page stay in the footer. Rename help,
failure messages, and zoom validation wrap without truncating authored input.
Canvas search is bounded by the board viewport: search/navigation/close controls
remain above scrolling categories and lazy results. Labels and snippets wrap,
and navigating active results reveals them without changing board geometry.

Object inspectors stack property labels and removal controls above typed values
when width or text size requires it. Property values, tags, reference titles,
precise destination badges, and mention snippets wrap completely. Relation tabs
wrap and expose their selected state; local graph controls wrap within the panel.
Property forms share the Orbit dialog's single scrolling content surface and
separate action footer. Validation messages wrap without a fixed line limit;
authored values remain editable after failure and unchanged on cancellation.

Workspace search keeps the query field above a shared scroll surface for filters,
status messages, and variable-height lazy results. Titles/context/excerpts and
long filter values wrap; keyboard navigation reveals measured row geometry.
Preview headings/content scroll together while Open remains reachable. Saved
search dialogs use scrolling content, wrapping validation, and separate actions.
The command palette retains search and Close above scrolling type filters,
grouped entries, and shortcut help; tall selected entries reveal their beginning.

Quick Switcher keeps search, Clear, and Close above scrolling lazy results and
shortcut hints. Full titles, create-note labels, and context wrap; status badges
move beneath text at narrow widths or enlarged sizes. Keyboard selection uses
measured row bounds and cancels obsolete reveals on query changes/disposal.
Selected rows expose button/selected semantics, retain focus across selection
changes, and support Tab plus Space/Enter activation. Text scaling is preserved.

The note link picker uses Orbit's scrolling heading/search/status and lazy results,
with Cancel in the separate footer. Titles, stable IDs, and aliases wrap fully;
keyboard selection reveals measured row bounds, including tall-row beginnings.
Result semantics merge label, selected state, and activation into one accessible
button. Query/clear resets scrolling and selection, and the Clear control returns
focus to search. Text scaling is preserved without a fixed dialog content height.

Smart View filters, Space management, dashboard customization and task planning
reuse OrbitDialog's scrolling content and separate action footer. Controls wrap;
expanded dropdowns retain enlarged text at narrow widths. Smart View tables use
lazy variable-height rows with horizontal column scrolling; boards/list/gallery
also create visible items lazily. Dashboard widths use responsive one-to-three
column spans. Spaces serialize existing pane/view descriptors, not another docking
engine. Reset in Settings/Spaces restores navigation without deleting knowledge.
Calendar moves preview before applying and offer a date-picker alternative to drag.
