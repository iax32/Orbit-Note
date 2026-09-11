# Spatial boards

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
