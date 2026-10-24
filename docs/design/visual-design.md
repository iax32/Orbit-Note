# Visual design direction

## Settings hierarchy — 2026-10-23

Settings uses a quiet category sidebar on wide displays and an integrated,
scrollable compact layout at narrow widths or enlarged text. Consistent grouped
cards separate section headings, setting labels, descriptions and values. Search
shows matching entries across categories; it does not render every panel upfront.
Advanced theme controls stay folded until requested. Readable semantic palette
roles and real Material surfaces keep selected rows and interaction feedback
visible. Controls stack before labels/values are squeezed; search submit and
result dragging dismiss the keyboard. [Behavior and validation](../tasks/settings-workspace-2026-10-23.md).


## Shared semantic colors and new Orbit default — 2026-10-23

Orbit's default uses layered graphite surfaces, warm white text and a restrained
violet accent. All 113 built-in palettes now share the foreground contrast
contract: primary text at least 7:1, secondary/muted text, links, status and
accent ink at least 4.5:1 against the eleven tested state surfaces; focus ink at
least 3:1. These are token-level checks, not whole-app accessibility certification.
Original palette surfaces/identity remain, with older foregrounds calibrated.

New/missing accent preferences follow the theme. Explicit accent presets retain
their choice and hue while adapting their shade for readability. Explicit role
color overrides/custom packs remain exact and user-owned. Shared Material text,
input/floating/focus roles, graph categories, collections/statuses, code/LaTeX,
callouts, Canvas controls and cached previews now follow the current palette.
Status tints and filled-control ink use actual contrast. Recovery controls use
the selected base family with a readable fallback.

Authored ink, object colors, covers, blueprint sheets/white pens, writing designs,
PDF highlights/paper and publication colors remain independent content choices.
External Google button branding and stable collaborator identity colors retain
their purpose; name-label ink is contrast-aware. The other chat's exact answer
was unavailable; this implements the documented principles rather than claiming
to have read it. [Scope, checks and limits](../tasks/semantic-color-system-2026-10-23.md).


## System appearance — 2026-10-22

Paired families optionally follow the OS light/dark appearance, retaining their
identity, user typography and independent document surfaces. The switch names the
visible member; stopping automation preserves that look and manual selection wins.
Preview/export use effective colors, including explicit accents. Unpaired custom
themes are not recolored or assigned a guessed companion. Existing motion-off/OS
reduced-motion handling remains; selected editor text/focus survive color changes.
[Scope and evidence](../tasks/system-appearance-2026-10-22.md).

## Coordinated light/dark palettes — 2026-10-22

The 100 additional palettes use authored paper/night neutrals, restrained accents
and independently adjusted semantic foregrounds. Eight collections span Studio,
Ocean, Forest, Earth, Botanical, Sky, Warmth and Creative. All existing shared
roles follow the palette. Main text, secondary/muted text, links/status/focus and
filled-control ink are tested against actual state surfaces, including pressed,
selected and floating. Decorative separators remain quiet. Contrast targets and
explicit limits are documented in the [task](../tasks/appearance-palettes-2026-10-22.md).

Pair switching/search/filters keep selection visible, and six-card pages bound
rendered previews. Large text stacks cards and wraps controls without clamping.
New palette selection preserves typography/corner preferences and can follow the
pack accent rather than replacing it with the old global accent. The original
13 packs, custom roles and recovery paths remain. No full-app WCAG certification
is implied for authored content or arbitrary custom overrides.

## Custom-font reading comfort — 2026-10-03

Selected note fonts now refresh existing Rich blocks immediately. Prose, Read,
aligned blocks, tables and callouts share the selected size and body line spacing.
Headings have a compact 1.3 line-height and consistent six-level hierarchy.
Times New Roman/Georgia use regular body/control weights, actual bold headings
and neutral tracking instead of intermediate weights/compressed sans tracking.
Segoe UI keeps its existing interface hierarchy. Family-appropriate document
fallbacks preserve serif/monospace intent where a chosen family is unavailable.
Settings offers a live reading preview; try 18–20 px for serif comfort, with no
automatic preference changes. Fonts are rendered as text, never scaled bitmaps.
Native display/rasterization quality is not verified by headless layout tests.
See [validation evidence](../tasks/font-comfort-2026-10-03.md).

Sources: S10–S12. Orbit Dark, curated light/dark palettes and optional system
switching for paired families are implemented; see implementation status for limits.

## Delivered color customization — 2026-09-30

Settings exposes fifteen shared UI color roles through a disclosure section.
Role editing supports a color preview, hex, HSV sliders, swatches, cancel/apply,
per-role default and full reset. Preferences use the existing local session; old
sessions keep the default theme. Material controls and Orbit semantic surfaces
share the chosen roles. Recovery controls and the editor retain a neutral palette.
Document ink, per-item canvas colors and PDF paper tones remain content-specific.
See [task evidence](../tasks/colors-bookshelf-2026-09-30.md).

Orbit's default theme is dark graphite with muted violet accents and a
restrained galaxy influence. Use contrast, spacing and hierarchy to make long
reading/writing comfortable. Avoid neon/gaming styling and decorative clutter.
Retain accessible light, dark and system choices; theme preference is reversible.

The center content dominates. A small activity rail selects context; left
navigation follows that context, the central workspace supports tabs/splits and
later docking, and an optional right inspector exposes details. Ordinary users
start with a calm layout. Progressive disclosure reveals advanced properties,
toolbars and customization only when relevant.

Specify shared tokens for surfaces, text, focus, selection, accents, spacing,
typography and motion before multiplying custom components. Validate contrast,
text scale, keyboard navigation, disabled states and high-DPI rendering. Meaning
must not rely on violet/color alone. Empty/loading/error/read-only/offline states
deserve the same design attention as a populated screen.

Power users may change panels, navigation, shortcuts, dashboards, themes and
saved Space layouts. An accessible reset and safe layout remain reachable when a
panel/plugin fails. See [layout architecture](../architecture/ui-layout.md),
[customization](../features/customization-and-spaces.md) and [motion](motion.md).

## Quiet observatory refinement (S12)

Use deep graphite surfaces rather than pure black, muted violet for selection and
primary actions, and small cool-blue accents for secondary context. Reserve green,
amber and red for outcomes that need those meanings. Decorative stars, constant
orbiting particles and bright nebula gradients must not compete with writing.

The current semantic radius scale is 8 logical pixels for controls, 12 for cards
and 16 for floating/dialog surfaces. Rounded rectangles are the default; do not
turn every control into a pill. Keep borders subtle and focus indicators visible.
Use comfortable readable text, deliberate whitespace and restrained shadows.

Notes and Canvas share the same shell. Split right/down creates another view of
the same object, with a draggable divider and independent reading state. A pane
is not a second note. Focus hides optional side panels and offers a visible exit;
layout reset remains reachable. Nested docking, tab transfer and named Spaces
extend these existing requirements rather than becoming competing shell systems.

## Premium desktop refinement (2026-09-10)

Keep the existing OrbitColors palette authoritative. Material surface-container
roles now map explicitly to graphite tokens, with automatic elevation tint
disabled. Violet identifies selected controls, primary actions and keyboard focus;
ordinary button labels remain neutral. Preserve semantic error/success colors.

Use Segoe UI with a deliberate 28/24/20-pixel heading hierarchy and 12–15-pixel
interface text. Note content retains the user's editor size preference. Controls,
filter chips and segmented selectors use the 8-pixel rounded-rectangle token.
Floating menus/dialogs use bordered graphite surfaces. Hover, focus, pressed and
disabled states remain distinct; shared styling retains Material keyboard and
accessibility behavior. Do not remove focus affordances to make controls quieter.

Home content is bounded to 1120 pixels and Settings to 960 pixels, including
padding, so controls do not stretch across the entire desktop. These are maximums,
not minimum widths. Tabs use a quiet raised active surface and violet underline;
bookmarks use a small accent icon rather than a separate gold card treatment.
The Notes formatting bar groups prose, list and code tools in a
single horizontally scrollable surface. The secondary Notes close control sits
in its own editor header, aligning both writing areas in a horizontal split.

## UI refinement (2026-09-21)

Use the shared 4/8/12/16/24/32/48 spacing scale. Neutral hover/pressed overlays
keep violet reserved for selection and keyboard focus. Retain the existing
semantic typography, surfaces, radius, and short motion tokens.

Explorer starts with a compact date row, with an expandable calendar and saved
expanded/collapsed preference. Creation/import and object-type filtering live in
menus. Secondary object actions reveal on hover/focus (remain visible on touch
platforms and for the selected object). Home leads with the date and useful work;
resume rows and idle focus use dividers rather than decorative cards. Resume
actions stack when width or text scaling makes a row impractical.

Canvas groups text, drawing, and insertion tools into flyouts. Selection actions,
arrangement, grouping and layering are contextual; shortcuts continue to work.
The context Inspector starts with properties and links, with its local graph
available on demand. Notes wrap header controls at narrow widths, retaining a
shared minimum header height for aligned split panes. Settings and empty-state
copy should describe the current state without promotional slogans.

See [review and validation](ui-refinement-review.md) for delivered changes and
remaining visual limitations.

No new decorative motion, fonts to download, storage changes or dependencies are
introduced. Existing reduced-motion preferences and layout recovery remain in
effect. Desktop captures plus narrow Notes at 150% text scaling are checked;
full high-DPI and multi-monitor manual acceptance remains separate.

### Notes follow-up — 2026-09-11

The formatting bar now shrink-wraps its controls at the left, retaining horizontal
scrolling on smaller panes; it does not draw a full-width strip. Rich text remains
centered, with compact block spacing and hover/focus-only desktop insert/menu
chrome. Touch controls and keyboard/assistive access remain available.

### Research and source previews — 2026-09-11

The desktop Vault control shows its name rather than an unexplained folder icon;
the chooser distinguishes the current Vault with selection color and a check.
Source files use a graphite reading surface, restrained violet code icon, file
identity header and quiet read-only status. PDF highlights use translucent violet
and a collapsible graphite list with explicit source-review messages. Preserve
focus and hover feedback on Material-backed interactive rows.

### Custom controls and bounded motion — 2026-09-11

See the [visual pass audit](observatory-pass-2026-09-11.md) for delivered components,
screen coverage and remaining work. OrbitControl/ModeControl replace the stock
Notes segmented selector, Canvas primary tools and rail states. OrbitDialog and
OrbitSearchField change composition rather than only ThemeData. Keep the original
graphite/violet palette, quiet markers and clear keyboard focus.

### Search and calendar sizing — 2026-09-21

Canvas search reserves a full row for typing; result count and navigation actions
wrap below it when needed. Explorer calendar day cells have a minimum height and
grow with text rather than clipping enlarged dates or activity indicators.

### PDF control sizing — 2026-09-22

PDF find uses a full input row with wrapping match controls. The highlights panel
scrolls its filters and lazy review list together so short panes and enlarged text
do not clip controls. Annotation dialog styling and save behavior remain unchanged.

### PDF keyboard focus — 2026-09-22

Connected notes focuses its filter on opening; Enter opens the first match and
Escape returns to the reader. Its header/filter/results scroll together. The
thumbnail rail has a violet focus outline and selected page semantics. Up/Down
and Home/End navigate and reveal pages; Enter returns to the reader and Escape
closes the rail. Existing pointer and Tab activation remain available.

### Product quality pass — 2026-09-26

### Dashboard hierarchy refinement — 2026-10-04

Project, Course and Reverse Engineering dashboards use content-first hierarchy:
spacing, typography and quiet separators carry section structure while bordered
cards remain for independent objects or compact status groups. Project progress
is a single bounded separator; task and resource titles remain direct links.
Reverse Engineering metrics are grouped values without five repeated cards, and
its target header has no decorative gradient. Accent continues to identify active
context and creation. This is a focused subsystem pass; the broader visual audit
remains documented in [the delivery report](../tasks/product-coherence-2026-10-04.md).

Selected surfaces use a restrained accent blend, independently of neutral hover
and pressed surfaces. Focus uses the brighter accent outline. Existing checkmarks
and underlines remain non-color selection cues. Shared mode controls reserve the
underline space so changing modes does not shift their geometry.

### Obsidian visual language expansion — 2026-10-05

The shell supports thirteen curated first-party theme families, including slate
and amber Obsidian Ember, Nord, Dracula, Catppuccin, Rosé Pine, Solarized, and
Gruvbox variants. Each pack resolves through the same semantic token map, and
applying one updates interface/document/monospace typography and corner style as
a single reversible preference change. The workspace header is a quiet raised
workbench strip with a destination/document breadcrumb and visible command
palette affordance. Tabs and the activity rail retain Orbit's violet active edge,
while each theme supplies its own accessible accent. Further PDF/Canvas toolbar
alignment is intentionally a separate pass.

### PDF and Canvas workbench surfaces — 2026-10-05

PDF and Canvas now use the same `OrbitWorkbenchToolbar` surface: graphite
workbench background, quiet semantic dividers, compact secondary context labels,
and the existing horizontally scrollable controls. Labels disappear below 560
logical pixels so narrow panes keep their tool vocabulary without introducing a
second row. The surface does not change commands, shortcuts, document state, or
canvas persistence. Side panels and inspectors remain a separate composition
pass.

### Apple modern theme foundation — 2026-10-05

Framework-owned surfaces now inherit the same Orbit language: flat app bars,
quiet navigation indicators, graphite bottom sheets, semantic dividers, and
accent-only progress states. These tokens preserve the user's selected theme,
font, density, zoom, and corner style. The direction takes Apple's clarity,
deference, and state discipline as inspiration while retaining Orbit's own
graphite/violet identity and power-user controls.

### Inspector and PDF side-panel surfaces — 2026-10-05

Contextual panels use an identity-first header: a small accent icon tile, a
short title, supporting context, and actions that wrap safely in narrow panes.
Connected Notes, PDF Review, and the Object Inspector now share this language.
The header carries hierarchy while panel content uses the existing dividers and
theme tokens; no feature action or data contract changes.

### Apple and Obsidian workspace language — 2026-10-05

The shell uses a stable panel-colored activity rail, quiet icon-only selected
states, and a unified document tab strip. Active tabs are raised and rounded;
inactive tabs stay visually quiet until hover or keyboard focus. The strip keeps
the overflow search, pinning, reordering, close actions, and keyboard behavior.
This takes macOS clarity and Obsidian's persistent tab/sidebar workbench as
inspiration while retaining Orbit's own graphite/violet identity.

Home uses a period heading as the primary visual anchor on wide screens. Its
navigation and review controls collapse into a compact, overflow-safe row on
small screens; at extreme text scaling the review action moves below the row so
navigation never clips. Theme selectors show a miniature workspace preview so
surface hierarchy can be judged before applying a preset.

UI typography roles inherit the configured font; document typography remains
editor-owned. The spacing scale stays 4/8/12/16/24/32/48. Named control sizes are
32/36/44 and icon sizes 14/16/18/20/24. Radius roles distinguish small details,
controls, cards/panels, menus and dialogs. No new shadows or ornamental gradients.

Home shows continuation before capture, uses a single capture surface and quiet
recent links, and stays within 1080 logical pixels. Settings starts with appearance
and editing; account and data controls remain below. Inspector identity uses a
plain type label and icon. Empty workspaces use a small neutral icon and factual
title. Calendar empty agendas scroll in short panes.

Home continuation cards omit LaTeX preambles. Workspace note statistics appear
only in the Notes destination; LaTeX uses a document/character label instead of
prose word and reading-time estimates. Note editors omit the scroll/reading-progress
stripe; normal scrolling and saved document positions remain available.

PDF navigation/zoom precede reading and research tools, with shared separators
and a visible horizontal scrollbar when tools exceed the pane. Canvas uses the
same separators between selection, authoring, history and import/export tools.

The command palette groups Recent, Continue, Create, Navigate and Workspace.
Up/Down reveals the selected result; Enter/numpad Enter opens it, and Escape
closes the dialog. Search resets selection and ignores stale asynchronous results.
A single type menu filters Notes, Canvases, Tasks or Files, applying the filter
before the visible result limit. Everything restores commands and knowledge.

### Readability and density refinement — 2026-10-03

Shared UI geometry lives in OrbitDensity and composes with device-local zoom.
Comfortable rows/controls are 36px, small controls 32px, tabs 220px and board
columns 304px; Compact saves spacing (30/28/188/272) while keeping body/metadata
font sizes. Semantic text roles retain chosen interface fonts: body 14px,
object 15px, section 16px, metadata/caption 12px. Task titles use 14.5px with
1.45 leading; Explorer titles use 13.5px with 1.4 leading. Default secondary
and muted colors become #C2BECE/#918C9D; user overrides remain authoritative.

Overflow is explicit: tabs keep their readable width and expose searchable
open/recent tabs. Idle Explorer actions hide but remain available on focus and
selection. Note formatting can scroll, while Undo/Redo remain visible. Task
Detail bounds its working width and collapses advanced properties. Game health
metrics use plain grouped values instead of four separate metric cards.

App zoom composes text scaling and semantic geometry; it does not transform the
root render tree or alter the viewport, DPR or keyboard insets. Existing motion
policies, document typography, source/history and canvas gestures remain.
Remaining legacy labels and planning/Canvas composition need dedicated passes;
see the visual ergonomics task report for scope and validation.

### Calendar workbench refinement — 2026-10-04

Planning views use the same calm workbench language as the rest of Orbit Note:
thin graphite dividers, a single blue focus accent, restrained metadata, and
content-first rows. Month and Week are explicit view modes, while selected days
and event/task types retain enough contrast to support scanning. On narrow panes,
calendar controls wrap instead of forcing horizontal scrolling.

### Visual and motion refinement — 2026-10-04

The activity rail is a darker navigation spine with one animated active edge.
Tabs use quiet surface transitions for active, hover, and focus states. The
Orbit mark has a framed treatment with a reliable icon fallback. Shared control
feedback uses the existing motion scope and disappears or becomes immediate in
Reduced and Off modes. The shell gains character through geometry, hierarchy,
and state clarity rather than continuous decoration.
