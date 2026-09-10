# Shared spatial canvas and ink engine

Status: accepted reuse direction ([ADR-0006](../adr/0006-spatial-canvas-reuse.md));
a first board/ink consumer now exists; advanced consumers remain M3/M4 work. See [objects](universal-object-model.md) and
[storage](storage-formats.md) when changing persistent geometry.

## One engine, several presentations

| Consumer | Configuration |
|---|---|
| Infinite board | Spatial cards, groups/columns/frames, connectors, pan/zoom |
| Freeform page | Click-to-write, page-like or extendable bounds, pen tools, paper backgrounds |
| PDF annotation | Page-index/normalized page-coordinate adapter, shared ink and selection |
| Image annotation | Image-coordinate adapter with region references and shared ink |
| Mind-map/graph view | May reuse camera, hit-testing, primitives; layout algorithm remains separate |

A linear Markdown document uses its editor. Reusing canvas primitives does not
require implementing the text editor as a board. Conversion creates linked
presentations with explicit handling of layout/fidelity loss and reversible commands.

## Components and ownership

- Camera: pan/zoom and invertible world↔screen transforms. Moving the camera never
  rewrites object positions. Use floating-point world coordinates and bounded zoom.
- Scene: elements with stable IDs, geometry, z/layer order and content references.
  Object placements resolve live content; shapes/frames may be local decorations.
- Spatial index: viewport and nearby hit-test queries (start with a measured grid;
  replace with R-tree/quadtree only if evidence warrants).
- Renderer: batch ink/shapes/connectors with `CustomPainter`; mount Flutter widgets
  for visible interactive cards/editors. Cull outside viewport plus overscan.
- Input/tool controller: select, pan, text, pen, highlighter, eraser, shape,
  connector; own pointer capture and mouse/touch/stylus arbitration explicitly.
- Selection/transform: point hit test, box/lasso, multi-select, move/resize/rotate,
  snapping and alignment; honor locked/hidden layers and nested transforms.
- Command adapter: coalesce a drag or stroke into one undoable command. Cancelled
  input restores before-state; pointer samples do not each create history entries.
- Serialization adapter: scene and ink data conform to the shared open formats.

## Ink

Retain editable vector samples with x/y, elapsed time, width/color/tool, and
optional pressure/tilt. Missing stylus data has a predictable fallback. Store
bounds per stroke; avoid one widget per stroke. Paint active ink in a separate
layer, commit on stroke end, and simplify/calculate previews off the hot path.
Smoothing must not destroy original samples needed for faithful reconstruction.

Start with stroke erasing and lasso move; segment erasing, recognition and
ink-to-shape/object conversion are later tools. Recognition is optional and its
result needs review. Page/image transforms preserve alignment under zoom, resizing,
rotation, and PDF page changes. Never flatten the only editable original into PNG.

## Content and interaction details

Cards can show compact titles, previews, or selected properties of one object.
Live tables/views embed view definitions. A connector may reference a semantic
relation; decorative arrows do not silently create knowledge edges. Removing a
placement never deletes its object. Portals must eventually guard recursion and
loading depth; do not recursively mount a whole nested workspace.

Tools should support familiar pan gestures and keyboard alternatives. Pen draws
while touch pans where hardware allows; validate palm rejection on real devices.
Provide focusable object lists and accessible commands alongside spatial gestures.

## Performance design and measurement

Never mount or scan every scene element on every pan, zoom, or pointer update.
Use visible queries, granular subscriptions, dirty-region invalidation and bounded
image/PDF caches. Decode thumbnails appropriate to zoom; virtualize PDF pages.
At distant zoom simplify previews and dense connectors (semantic level of detail).
Introduce tiles/caches only with invalidation and memory measurements.

Proposed benchmark goals, to pin to hardware in M3:

- Smooth 60 Hz ordinary desktop interaction (about 16.7 ms total frame budget).
- Representative 10,000-element board and at least 100,000 ink samples.
- Exploratory 100,000 lightweight-element stress scene; 120 Hz only where feasible.
- Visible rendering work scales with visible complexity; huge total scenes still
  consume data/index memory, and a fully visible dense scene remains expensive.

Record device, build mode, scene, viewport, p95 frame times, memory and input latency.
Use profile/release measurements, never a debug FPS promise. Test transformed
hit-testing, zoom anchoring, z-order, multi-selection, undo, save/reload and lost
pointer/cancel events. Large-scene durability follows the storage checkpoint contract.

The [Universal Canvas spec](../features/spatial-boards.md) permits all supported
capabilities to coexist. Brainstorm/Diagram/Project Board/Lecture/Mind Map/Research
presets change defaults only. PDF source-coordinate adapters reuse the common ink
engine. Scale checks include tile/chunk awareness, image resolution management,
asynchronous I/O and granular updates; incremental persistence must honor the
authoritative storage/recovery contract rather than silently relying on SQLite alone.
