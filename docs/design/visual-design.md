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
