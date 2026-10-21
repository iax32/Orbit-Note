# Spatial boards

## Everyday Canvas starters — 2026-10-20

The **Canvas template library** toolbar button and **Add from template library…**
context action offer searchable starters with vector previews from the existing
Canvas renderer: Mind Map, Idea Exploration, Reflection Board, Outdoor Adventure,
Nature Observation, AI Experiment Board, Travel Planner and Story World.

Insertion appends fresh ordinary placement IDs beside existing content, selects
the inserted items and fits the camera. One Undo removes the complete insertion.
Existing content/unknown metadata and canonical references remain intact. Sticky
notes and endpoint-bound connectors are editable, movable and removable using the
normal tools; templates introduce no special locked content or copied objects.
Late dialog callbacks refuse changed boards/permissions. Consumed preset markers
keep a deliberately emptied starter empty on reopen. AI starters run no model.
[Evidence](../tasks/canvas-review-templates-2026-10-20.md).

## Selection and transfer quality — 2026-10-18

Gesture cancellation restores prior selection/geometry and cancelled navigation
restores the camera. Read-only changes, unguarded external revisions and
two-finger handoff cancel provisional drags. Guarded workspace editors preserve
competing gestures for recoverable draft review without overwriting shared data.
Clipboard commands have separate undo boundaries and refuse stale
board/read-only/menu completions. Ink duplicate/paste/align/distribute preserves
local coordinates and all authored sample data; only the placement origin
moves. Slow supported text/image paste retains its
captured world position. See the [desktop behavior and evidence](desktop-interactions.md).

## Editable UML class diagrams — 2026-10-16

Canvas's Shapes and diagrams menu (also available on empty-space right-click)
creates three-compartment class boxes and relationships. Double-click a class
or UML connector, or choose Edit selected UML item, to edit it. Classes support
names, optional stereotypes/abstract names, attributes and operations, one member
per line with authored visibility/type text. Empty compartments remain visible.
Classes use Orbit's theme surface and foreground, restrained separators, rounded
corners and a small accent beneath the name. Class accent color follows the
ordinary Canvas color control; existing stored colors remain intact. Canvas,
note previews and SVG share the same palette. Text remains vector-rendered.

Connect UML classes offers association, dependency, generalization, realization,
aggregation and composition, with plain/open-arrow/hollow-triangle/hollow- or
filled-diamond markers. The editor explains parent/whole direction and provides
endpoint roles, multiplicities, attachment sides/positions and routing lanes.
Connectors follow class movement/resizing through the existing engine. These
are visual UML relationships, not new universal objects or knowledge relations.

Insert UML example adds the four supplied medical-domain classes and attached
associations in one undo step. All shapes retain ordinary selection, transforms,
remove, undo and copy/paste behavior. Pasting the whole diagram remaps placement
IDs and bound endpoints. Class members/roles are searchable. Dialogs guard
against read-only, locked and externally replaced scenes; cancellation adds no
half-created class. Geometry, members and unknown fields persist in Canvas JSON;
SVG/PNG preserve the diagram appearance. Older readers retain named-rectangle
fallback and unknown UML data. No scene migration or alternate canvas engine.

Export diagram to Markdown in Shapes and diagrams sends the selected UML
classes (or all visible UML classes when nothing is selected) to a new note or
appends them to a searchable existing Markdown note. Copy live diagram for
Markdown supports pasting at the caret instead. The precise reference retains
placement IDs, not duplicated content or a screenshot. Relationships between
the selected classes update live, including newly added internal relationships.
Rich and Read show the shared Canvas vector renderer, expansion/zoom, source
navigation and selectable class details; Rich can edit through the existing
Canvas editor. Removing the embed preserves its source. Missing/hidden items
show an explicit retained-reference warning and never fall back to unrelated
board content. Guarded saves reject stale/competing drafts; failed appends can
be retried without duplicating the embed.

The Markdown block remains a source link in other readers. Published PDF/HTML/
Word currently retain that link and the existing unsupported-preview warning;
they do not contain a self-contained diagram snapshot.

Mermaid remains the existing flowchart exporter: its UI warns that it does not
preserve class compartments or UML notation. UML classDiagram import/export,
self-associations, automatic obstacle avoidance, code generation and semantic
validation of free-form signatures/multiplicities are not part of this task.
Evidence and build results are recorded in the current task.

## Linked model assets — 2026-10-11

OBJ/GLB attachments can be placed as ordinary object cards with their canonical
object identity and an independent placement UUID. Model cards identify their
source type and open the offline viewer. Placement removal preserves the asset;
the existing scene/history/save engine handles edits without a new scene format.

Status: planned M3; advanced views M5+; portals/conversion exploratory.
Sources: S01, S03, S08, S09 in the [source map](../product/conversation-extraction.md).
Architecture: [shared canvas engine](../architecture/canvas-engine.md).

## Purpose and workflow

A user brainstorms a project by arranging existing notes, tasks, images and sources
in space. They can add a Backend frame, organize cards into columns, draw connections,
and open any object for deeper editing. Board geometry expresses visual organization;
the knowledge remains available through documents, search and structured views.

## Requirements

| ID | Observable behavior |
|---|---|
| CAN-01 | Board navigation supports pan, zoom, reset/fit selection and fit content. Camera changes do not modify world-space object positions. |
| CAN-02 | Place an existing object as a card, and create new content intentionally. Multiple placements can reference one object with independent geometry and display settings. |
| CAN-03 | Cards offer compact, card, preview and selected-property presentations where appropriate; editing opens or edits the underlying object, and other views update. |
| CAN-04 | Support text, images, files, shapes, connectors, groups, frames and columns progressively; identify what is content versus a reference or decorative element. |
| CAN-05 | Select by click/tap, additive selection and region; move, resize, rotate, align, distribute, group, lock, duplicate or remove selected elements with explicit semantics. |
| CAN-06 | Snapping supports grid, edges, centers, alignment guides and equal spacing, with a temporary bypass; guides must remain correct while zoomed. |
| CAN-07 | Connectors support free anchors or element endpoints, labels and optional semantic relations; connected edges follow element transforms. |
| CAN-08 | Layers control visibility, locking and stacking. Frames/columns organize geometry; creating a collection or promoting a frame to a knowledge object is a separate explicit action. |
| CAN-09 | Embed live saved views such as a task table or Kanban without copying their records; visible interactions route to their underlying object/view commands. |
| CAN-10 | Auto-arrange can propose grid, horizontal/vertical, tree, mind-map, timeline, Kanban-like or cluster layouts. Applying an arrangement is reversible. |
| CAN-11 | Semantic zoom simplifies distant content while retaining useful titles/group context; large scenes remain navigable through culling, indexes and bounded caches. |
| CAN-12 | Exploratory portals can enter a referenced board and return; preserve navigation history and prevent recursive rendering/loading loops. |
| CAN-13 | Exploratory document-to-board and board-to-outline conversion preserves source references and makes interpretation/fidelity loss reviewable. |
| CAN-14 | Each completed drag/resize/stroke/arrangement is an intelligible undo operation; cancelled gestures restore before-state and do not commit partial geometry. |
| CAN-15 | One Universal Canvas lets writing, ink, sticky notes, real object/task/project cards, media/PDF highlights, shapes, diagrams and live views coexist. Presets never define incompatible content types. |
| CAN-16 | Shape/diagram tools include rectangles, circles, diamonds, lines and arrows for flowcharts/architecture diagrams, using the same transforms, selection and connectors as other Canvas content. |
| CAN-17 | Brainstorm, Diagram, Project Board, Lecture Notes, Mind Map and Research Board presets change initial tools/background/layout settings only; switching preserves every element's capabilities. |

S10 names this combined experience **Orbit Canvas / Universal Canvas**, including
Excalidraw-style diagramming concepts. Board/freeform/annotation remain consumer
presets/adapters of the accepted shared engine, not feature-restricted formats.
Live Smart Views include tasks, databases and calendar (CAN-09); graph widgets and
graph-to-Canvas conversion are owned by LNK-13; portals remain CAN-12.

## Detailed interaction contracts

Selecting a card and editing text inside it are distinct input modes. Keyboard
shortcuts for tools must not steal ordinary typing. Space-drag temporary pan and
modifier-wheel zoom are examples to evaluate, not final global bindings. An object
must stay under the expected pointer anchor through a transformed drag.

“Duplicate placement” refers to the same object. “Duplicate object” creates a new
identity and is a different command. “Delete/remove from board” removes selected
placements/decorations; object trash requires a separate explicitly named action.
Copying between boards should preserve object references within a workspace; a
cross-workspace copy needs an import/ID-remapping decision before support is claimed.

Creating a semantic arrow between a project and a technology needs a clear source,
target and relation type (“Project uses Technology”). Reversing an arrow should
not silently invert a knowledge relation. Removing its visual representation
should not delete the relation unless that is the selected, explained action.

Frames can initially be visual grouping. Later promotion can make “Backend” a
project/component object with status, owner, deadline and relations; geometry stays
separate. Mind-map creation should create/select real referenced objects where
knowledge nodes are intended, while keeping graphical groupings lightweight.

## States, persistence and performance

An empty board has usable navigation and a creation affordance only for supported
tools. A missing object displays an unresolved card with recovery/navigation options.
Hidden/locked elements respect selection rules; hidden elements do not intercept
pointer input. Read-only boards can still pan/zoom/copy references.

Persist stable element IDs, reference IDs, world geometry, z/layer order, style and
relation references. Separate personal camera position from intentionally shared
presentation state when sync is introduced. Follow open board serialization and
checkpoint rules; never rewrite a huge board for every pointer sample.

Large-scene goals are measured in [quality requirements](../product/quality-requirements.md).
Only visible/near-visible content should mount interactive widgets. Far-away images
need thumbnails or deferred loading. A board that fits entirely on screen can still
be dense; culling alone is not a guarantee of unlimited performance.

## Acceptance scenarios

- CAN-01/05/06: at several zoom levels, drag/resize a card and verify pointer
  anchoring, snapping and saved/reloaded world coordinates.
- CAN-02/03/07: show one note twice, edit it elsewhere, remove one card and verify
  the other card/content/relation remain correct.
- CAN-08/14: cancel a multi-selection drag involving a locked layer; no unintended
  items move, and a completed drag creates one undo step.
- CAN-09/11: profile a representative board with live views and high-resolution
  attachments; record visible item count, frame timing, memory and persistence cost.
- CAN-12/13: reject a recursive portal or conversion proposal without changing data.

## Delivery

M3 begins with camera, visible object cards, selection, durable placement and undo.
Add connectors and grouping incrementally. Ink reuses this engine in M4. Live
views, advanced auto-layout, portals and conversions are not first-board prerequisites.

## Delivered column and website-card subset — 2026-09-11

The Add / organize board content menu creates empty columns or packs selected
placements into a column. Rename the heading inline; drag its header to move
members. Drop a card inside to add/reorder it; drag out to detach it. Tidy Column
reapplies spacing. Removing a column retains its items. Commands share Canvas undo,
copy/paste remaps column/placement IDs, and unknown fields/object IDs survive reload.
Nested columns and general groups remain planned; locked members prevent parent
moves/automatic arrangement.

Website cards store a readable title and validated HTTP/HTTPS URL and open by an
explicit double-click/Open action. They do not fetch remote previews. Existing
notes/tasks/files remain real object references. More Milanote-style workflows,
including anchored connectors, nested boards, native content editing on cards,
advanced groups and collaborative publishing, remain in the single backlog.

Website cards now support Edit selected link in Add / organize board content.
Editing validates HTTP/HTTPS, retains geometry/identity/unknown fields and uses
the existing undo history. Locked or changed cards are not overwritten by a stale
dialog. Creation, editing and persisted geometry are covered by widget tests.

## Creative-project boards and removal — 2026-10-09

Selected items expose a Remove from canvas toolbar button. Right-click inside a
column/frame includes removal alongside insertion actions. Removing a placement
never deletes its source; removing a column detaches children. Undo restores the
scene, and locked/read-only items retain their existing protection.

In the Notes folder context menu, New Creative Project collects an optional brief
and builds a references board (Inspiration, Research & sources, Chosen direction)
and a production board (Explore, Decide, Produce, Review). Cards reference actual
brief/decision notes, task objects and a milestone view. Moving cards changes
placement only; it does not automatically change task status or milestone.

## Reference capture and curation — 2026-10-09

Creative-board file drops capture original attachments as canonical file objects
with project/folder context and preview cards. Any Canvas also offers Import
reference files from its toolbar or Add / organize menu. Batches are bounded to
100 files, using existing incoming-file size checks. Files are processed locally;
unsupported media retains its file card and original-open fallback. Creative drops
capture SVG/Mermaid as source files; existing diagram import remains available.

Drops use the actual Canvas surface and a frozen world position. Unlocked columns
receive spaced cards after existing members and expand without moving those
members; free-space batches use three-column grids. Placement is one Canvas undo
command. Read-only/future scenes reject placement, and unavailable targets retain
saved sources in the Vault. Import undo removes placements, not owned source files.

Reference details are optional placement metadata: caption, HTTP/HTTPS source URL,
comma-separated tags and Inbox/Review/Chosen/Archived state. Edit through the card
context menu or Add / organize. Bulk state changes affect unlocked selected cards;
Archived is a label, not deletion. Details never alter shared source content.
Changed cards reject stale dialog saves; unknown scene/placement fields survive.
Card footers reserve preview space for captions and state/tags. Canvas search
matches those details and source URLs. Explicit Open reference source launches a
validated URL; no previews or remote metadata are fetched.

Create linked reference summary produces an ordinary Markdown snapshot of selected
references, or all references when nothing is selected. It includes canonical
source/board UUID links, captions, source URLs, states and tags. Creative-project
summaries retain project/folder context. Later caption edits do not rewrite snapshots.

## Course boards and draft safety — 2026-10-13

Courses & study progress creates linked study boards with lecture/reference,
practice/assignment and exam-review columns. Material placements reference their
original objects; two ordinary Smart Views keep all material/open assignments
current. Selected saved-query card previews now use the same scoped member IDs
as painted previews, with source navigation rather than unfiltered Vault tasks.
Overlapping pane gestures retain a conflicting scene for explicit recovery;
the shared scene is not overwritten. Resolving/discarding a conflict reloads the
shared scene and invalidates stale local scene undo as for external revisions.

## Math Lab and editable plot snapshots — 2026-10-14

Add / organize board content and the context menu open the same offline Math Lab
as notes. Calculations/templates become ordinary formula sticky cards. A function
plot creates a formula/parameter/window card, bounded grid and axes, sampled ink
segments and labels as one grouped insertion with one undo. Existing Canvas line,
ink, text and sticky primitives own the snapshot; no second spatial engine or
custom plot schema. White blueprint pen and current drawing colors are honored.
Ungroup to edit individual strokes; moving/deleting the group uses normal placement
controls. SVG and documented Canvas JSON preserve the ordinary editable primitives.
Changed Canvas identity/source, read-only scenes and cancelled dialogs refuse
insertion. Plots are explicit snapshots, not live symbolic graphs. Domain errors,
out-of-window samples and large jumps split curves; 257 samples may still miss
singularities or fine oscillations. Original expression, parameters and windows stay
on the formula card so a user can recalculate deliberately. No user Vault migration.

Math cards allow ordinary resize/editing and initially grow to fit matrix rows.
Simple matrices up to 6×6 have aligned readable bracket/row previews on Canvas;
full TeX typography remains available in Math Lab/Equation Studio/notes. The board
continues using its Unicode text preview for unsupported/nested mathematical forms;
original TeX is preserved rather than claiming full symbolic typesetting parity.

## Mathematical comparisons and tables — 2026-10-14

Math Lab can compare up to four functions on one shared coordinate window. Canvas
inserts grouped ordinary ink segments with distinct curve colors, a source/parameter
card, grid, axes and labelled expressions. The selected pen color is retained for
the first curve/grid; additional curves use the shared comparison palette. Numeric
value tables remain ordinary formula-card TeX snapshots, with readable bounded array
row previews and widths sized for columns. New comparisons/tables fit the selected
placements into view using existing camera transitions. Grouped edits undo as one
command; snapshots stay editable through existing ink/text/placement controls.
No new Canvas element type, object identity, spatial engine or workspace migration.
