# Visual design direction

Sources: S10–S12. Orbit Dark is implemented. Future light/system variants remain
planned; see implementation status for the delivered subset.

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
not minimum widths. Tabs use raised bordered cards and a violet object icon for
the active tab. The Notes formatting bar groups prose, list and code tools in a
single horizontally scrollable surface. The secondary Notes close control sits
in its own editor header, aligning both writing areas in a horizontal split.

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
