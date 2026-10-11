# Product quality audit — 24 September 2026

Recorded before implementation. Scope: the owner's attached product-design brief;
preserve current LaTeX, PDF, canvas and storage work. Native baseline: isolated
in-memory Windows review app, 1266 × 713 capture. Screens: Home/Explorer, note,
Canvas, Tasks, Settings. Evidence is under `work/ui/product-quality/before-*`.

## Findings and decisions

| Area | Concrete finding | Decision |
|---|---|---|
| Template-like patterns | Home quick capture nests a filled field inside a rounded surface. | Flatten capture into one field. |
| Nested cards | Settings' sync card occupies most of the initial viewport. | Put everyday appearance/editor preferences first; retain account controls below. |
| Rounded rectangles | Inspector type badge, icon tile and identity section repeat containers. | Use a quiet icon and plain type label. |
| Copy | Home capture explains Enter in its placeholder; empty states use large display treatment. | Short, factual copy and smaller empty-state hierarchy. |
| Hierarchy | Home date, capture, creation actions and recent chips precede continuation. | Tighten spacing and reduce decorative treatment. |
| Spacing | Shared 4–48 scale exists, but controls use unrelated 3/6/10 padding. | Apply semantic control metrics where shared. |
| Radius | Only control/card/floating names exist. | Name small, panel, menu and dialog roles; keep compatible aliases. |
| Icons | Shared icon size is 17, feature icons vary 13–22. | Establish 14/16/18/20/24 roles, use 18 in common controls. |
| Chips | Home recent objects are framed chips; task default priority is colored. | Quiet recent links; reserve emphasis for actionable states. |
| Permanent actions | PDF has a long undivided toolbar before navigation. | Put navigation first and group reading/research actions. |
| Material appearance | Fields, popup menus and segmented controls have different density/selection. | Shared theme states, geometry and typography. |
| Duplicate patterns | Mode controls add a selected underline as an extra layout child. | Keep selection indication without changing control height. |
| Selection | `OrbitColors.selected` aliases hover; active state lacks a separate surface. | Distinct selected surface with existing underline/check cues. |
| Focus | Shared controls have a ring; palette lacks arrow-driven result selection. | Preserve focus rings; add keyboard result navigation and visible selection. |
| Typography | Settings uppercase tracked captions differ from page/section text elsewhere. | Semantic text roles inheriting the selected font family. |
| Density | Settings copy and sync content consume first screen. | Smaller section headers and preferences-first order. |
| Empty states | 32px purple icon in a 72px tile competes with content. | Neutral icon, restrained title and one action. |
| Toolbar overload | Canvas already groups tools; PDF still combines every action in one run. | Preserve canvas tools; structure PDF groups with separators. |
| Panels | Explorer and Inspector already have recovery and responsive breakpoints. | Retain architecture; reduce inspector ornament and retain scrolling. |
| Identity | Graphite, violet active underline and blue secondary already work. | Strengthen these existing signals; no new gradients, logos or visual effects. |

## Surface review

- Home, Explorer, rail, tabs: retain collapsed calendar, New menu, hover actions
  and active underline; simplify capture/recent controls and keep content width bounded.
- Notes/LaTeX: preserve editor internals; shared mode/field/menu changes apply to chrome.
- Canvas/Inspector: keep grouped drawing controls and user-authored colors; simplify identity chrome.
- Tasks/Calendar/Graph: retain established views, focus and navigation; apply shared states.
- PDF: preserve reader engine, shortcuts and tooltips; improve toolbar order/grouping.
- Settings: preferences first; preserve all local/account controls and motion recovery.
- Palette: group commands/recent knowledge, add arrow/Enter navigation and keyboard hints.
- Dialogs/menus/toasts: shared geometry, restrained titles, bounded notifications.
- Motion/accessibility: retain Normal/Reduced/Off and OS caps; verify focus and scaled layouts.

## Implementation and validation plan

1. Shared semantic tokens and controls, without a new design framework.
2. Home/Inspector/Settings and PDF chrome; palette interaction.
3. Behavior tests for keyboard/selection and responsive boundaries; full format,
   analysis and tests. Native before/after review and production Windows build.
4. Report verified results separately from untested physical DPI configurations.

No changes authorized to sync protocols, authentication, storage formats,
migrations, graph physics, PDF engine or editor document models in this pass.
