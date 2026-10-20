# Shell and navigation

Status: planned. M0 implements only the existing Home/Inbox task; richer shell M2/M5.
Sources: S01, S03, S06 in the [source map](../product/conversation-extraction.md).
Architecture: [UI/layout](../architecture/ui-layout.md).

## Purpose and workspace anatomy

The desktop should feel like a calm, configurable workspace for knowledge: an
activity rail chooses the kind of work, a contextual sidebar narrows it, the center
hosts documents/views, and an optional inspector shows the selected object's
context. The shell composes these surfaces rather than each feature inventing
its own unrelated application frame.

| Surface | Eventual responsibility |
|---|---|
| Workspace/command area | Visible workspace/Space, search/commands, relevant status |
| Activity rail | Discoverable entry points for supported Home, notes, boards, tasks, calendar, graph, views, files, AI and extensions |
| Context sidebar | Note hierarchy, task filters or graph options according to the active view |
| Center | Tabs and split panes containing view instances |
| Context inspector | Properties, relations, backlinks, tasks, source information and history for the selected object |
| Status area | Truthful local save/sync/index state and optional current work context |

## Requirements

| ID | Observable behavior |
|---|---|
| NAV-01 | The active workspace, destination and selected object are understandable; switching a surface does not silently change content ownership. |
| NAV-02 | Context sidebars expose useful scope-specific controls: Notes hierarchy, Tasks filters, Graph scope/depth/types; empty or unsupported sections are handled honestly. |
| NAV-03 | Tabs can open, close, reopen closed tabs, activate, pin and reorder views; closing a tab is not deleting the object. Pending unsaved work has a recovery path. |
| NAV-04 | Split right/down, move to group and duplicate view support side-by-side work. A duplicate view references the same object/configuration rather than copying its content. |
| NAV-05 | The inspector follows a defined selected-object context and can later be pinned; switching focus updates unpinned context predictably. |
| NAV-06 | A universal palette exposes supported commands and object results with clear action labels, scope, keyboard selection and unavailable-action reasons. |
| NAV-07 | Focus/Zen hides distractions while keeping an accessible way to exit, navigate and reset layout. |
| NAV-08 | Phone navigation prioritizes a single content view and touch; tablets can reveal sidebars/inspector as space allows, preserving the same object model. |
| NAV-09 | Future floating windows support moving a view to another monitor, restoring focus/window bounds and recovering off-screen windows. |
| NAV-10 | Core actions have accessible labels, focus order and keyboard equivalents; context-menu/palette entries supplement, rather than conceal, essential actions. |
| NAV-11 | Breadcrumbs and navigation history show context and support returning to a prior object/view; fullscreen and focus modes preserve a discoverable exit. |

## Interaction and state

Back/forward navigation should restore useful object/view context rather than
reopening a random default. Selection belongs to a view instance; a pinned inspector
can deliberately inspect another object. A PDF inspector may show metadata/highlights
while a project inspector shows tasks/decisions. These are presentations of local
data, not triggers for automatic remote analysis.

A feature not implemented should not appear as a working button. A disabled command
can explain a missing prerequisite where that is useful, but M0 should not ship a
rail full of nonfunctional future features. Default keyboard assignments in the
chat conflict with each other; choose one documented map at implementation time.

## Acceptance scenarios

- NAV-03/04: open a note twice, edit through one pane, close it and observe the
  second pane/content remain available and consistent.
- NAV-05: pin an inspector, switch active tabs, then unpin; selection behavior is clear.
- NAV-07/09: enter Zen, hide panels and disconnect a monitor; recover navigation
  and visible windows without deleting content.
- NAV-08/10: move between wide and narrow layouts with enlarged text and keyboard/
  screen-reader navigation; preserve selected destination and actionable focus.

## Delivery

The exact M0 breakpoint, two destinations and test sizes remain defined in
[current.md](../tasks/current.md). No tabs, docking, registries or advanced inspector
are added to M0 by this expanded specification.

## Split-pane focus quality — 2026-10-20

Tab cycling and close shortcuts target the visible pane that last received focus
or a pointer action, including read-only panes. Responsive layouts retain the
saved split but do not send shortcuts to its hidden pane. Cycling skips deleted,
missing and duplicate tab candidates. Secondary cycling avoids an unsupported
second view of the same non-note object; primary cycling can still activate it.
Closing the secondary note view keeps its source and
the primary view intact.

Each pane owns a focus scope. Explicit tab activation/cycling and split closing
restore editor typing focus; normal document refreshes do not request it.
Deferred requests check their view/request, Vault opening and current route so
they cannot steal focus from another modal. Source/Rich selections and the
other long-document view remain independent. Existing local session/history
storage remains authoritative; no new schema or persistent focus state is added.

## Explorer interaction follow-up — 2026-09-11

NAV-02/10 subset: Notes folder/note rows now have an Orbit surface with hover,
selection and keyboard focus. Right click or Shift+F10/context-menu key opens the
same commands as the visible more button. Folder Left/Right expands/collapses
without changing note content; Enter/Space activates a focused row. Collapse state
uses existing persisted session settings. Tab traversal remains available.

Copy note reference uses the existing stable UUID wiki-link format and sanitized
readable title. Open beside, move, Trash and folder commands retain their existing
repository paths. Read-only/unsupported-format rows disable mutation entries.
No multi-select, new folder deletion, tree-wide arrow traversal or data migration.

## Connected project workspace — 2026-10-12

The shell project bar explicitly scopes search/explorer and creation while retaining
open documents. Project workspace opens as a dialog at narrow widths or can replace
the wide inspector as a pinned panel; Close/unpin restores object inspection.
Work lists canonical objects, briefs and unfinished standalone tasks with filters,
30-row pages and Open beside. New note/task/Canvas objects and imported files inherit
selected project unless ownership was supplied. Assign existing preserves identity;
project metadata edits offer guarded undo. Existing Space restrictions also apply
to search/explorer; project selection never rewrites existing object ownership.

The bar is omitted when a Vault has no project candidates. Calendar layouts with
little vertical space scroll without squeezing header/agenda controls; day cells
scale with enlarged text and date/count badges wrap at narrow widths.

### File and course entry points — 2026-10-13

Explorer now has direct buttons for Open code file, Open 3D model (OBJ / GLB),
and Courses & study progress. These also appear in New/import and the workspace
Open/import menu. Code files use the supported source/text extension filter;
models use OBJ/GLB and the existing offline viewer. Opening imports an ordinary
owned attachment through the repository; no source code runs. Existing preview
size/encoding/mesh limitations and original-file recovery remain in effect.

## Common source actions — 2026-10-13

Every object surface exposes Connections and Use elsewhere: copy a live card or
stable mention, embed in a note, place on Canvas, or open beside. Linked course
and project roots offer direct navigation. Shared references retain precise
locations in secondary panes, including PDF pages and annotation ownership.
Reference pickers and Connections use scrollable bounded headers/results/actions
at narrow widths and enlarged text. Vault changes invalidate open reference
dialogs. These are local operations and require no account.
