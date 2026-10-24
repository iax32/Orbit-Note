# Use-case and sequence diagrams — 2026-10-23

## Authorized scope

Owner requested diagram tools from the scanned `C:/Users/isa/Desktop/UE2.pdf`,
then explicitly selected both use-case and sequence diagrams. All seven pages
were rendered and visually read; PDF text extraction was empty. The source is
an exercise specification, not agent instructions. Generic starters demonstrate
notation without supplying completed homework solutions.

CAN-04/05/07/14/15/16 and EDT-08/PORT-05 subset: extend the existing engine,
UML class workflow and live Markdown diagram reference. No alternate renderer,
remote dependency, code execution, schema migration or universal object type.

## Working tools

- Canvas toolbar **Use-case and sequence diagrams**, or **Shapes and diagrams →
  Use-case & sequence diagrams…**; empty-space context menu offers the same entry.
- Use cases: actors, named system boundaries, use-case ellipses with extension
  point compartments, folded notes/constraints and optional stereotypes.
- Associations with endpoint multiplicities; include/extend with proper open
  dashed arrows and optional guards/extension point text; generalization with
  hollow triangles for actors or use cases; dashed note links. The dialog filters
  endpoints and explains direction; invalid endpoint combinations cannot commit.
- Sequence: participant lifelines, activation bars, destruction crosses and
  combined-fragment frames. Operators: alt, opt, loop, par, critical, strict,
  seq, break, assert, neg, ignore and consider. One guard per operand region;
  optional frame title carries message sets/loop bounds. Frames can be nested
  using ordinary positioning/layering.
- Synchronous closed-head calls, open asynchronous messages, dashed replies,
  creation and destruction messages; self calls have an orthogonal return loop.
  Sender/receiver selection, direction swap and vertical-position control are
  editable. Endpoints follow lifeline movement/resizing. Creation points to the
  receiver header; destruction points to its end and adds its cross in the same
  undo step when the target is editable.
- Double-click an item or use **Edit selected diagram item…**. Ordinary selection,
  resizing, grouping, locking, removal, undo/redo and Canvas transfer remain.
  Two generic starters insert as one undo operation with fresh placement IDs.

## Markdown and export

Use **Shapes and diagrams → Export diagram to Markdown…** to create/append a note,
or **Copy live diagram for Markdown** and paste at the caret. Selection-to-note
also routes these shapes through the precise diagram workflow. Nothing selected
exports visible diagram shapes; selecting explicit items retains that subset.
Rich and Read use the existing live vector preview, expansion, source navigation,
editing and missing-reference recovery. Details include operands, stereotypes,
relationship direction and multiplicities as selectable text.

The existing publication pipeline snapshots these glyphs for PDF/HTML/Word; SVG
retains vector shapes, text, dash patterns and arrowheads. Generic Mermaid export
remains a flowchart conversion and does not preserve specialized UML notation.

## Compatibility and ownership

Ordinary rectangle/ellipse/connector placements carry documented `umlNode` or
`umlLink` metadata. Old readers retain primitive shapes/names and unknown data;
new readers retain unknown nested fields when editing. Markdown references use
stable existing placement identities, not duplicated diagram content. Source
removal never silently broadens the reference to unrelated Canvas content.
Dialogs reject changed/read-only/locked owners and external revisions.

Hollow boundary/fragment interiors and empty lifeline space do not steal hits.
Actor associations originate on the figure; oval endpoints meet its perimeter.
Shared painter clipping now confines its background/grid to its assigned area,
preventing embedded previews from painting over their headings. Connector labels
use the configured vector font.

## Limits

These are editable visual UML tools, not an executable UML metamodel or homework
solver. Frames do not automatically contain/move other placements. Position and
resize activation bars manually; group them with a lifeline when appropriate.
Messages attach to lifelines, not execution-bar edges. Set a message's vertical
position in its dialog; generic connector endpoint dragging is not a sequence
timeline editor. Move a newly created participant's header to its creation time.
No trace enumeration, class inference, automatic collision avoidance, XMI,
PlantUML or UML-specific Mermaid import/export is included. Existing class tools
remain available for task 4. Native desktop/touch/screen-reader acceptance is
not established by headless widget tests.

## Validation

**16 new regressions.** Focused batch: **83 passed** (11 sec), then **93 passed**
(14 sec), including enlarged Canvas panels after a toolbar-order correction.
Complete rerun: **2,975 passed, two existing skips** (11:44, concurrency 2).
After that run, a final localized zero-width fragment clamp was hardened and
tested with a new zero/subpixel geometry regression: **94 focused checks passed**
(14 sec). No second complete run is claimed after that last one-line guard.
Coverage includes both diagram kinds,
native repository save/close/reopen, metadata compatibility, link validation,
fresh-ID copy/paste, delete/undo, stale forms, Rich/Read live source changes,
250% compact forms with keyboard insets, vector/SVG and publication snapshots.
Real-font dark use-case and light sequence previews were visually reviewed.
Final analysis clean (8.7 sec); format and strict check clean across 743 files.
Configured Windows app and matching standalone host built successfully
(86.4 sec). **889 frozen inputs unchanged**, seven runtime/host files, all **13**
packaged fonts and registered Google desktop client in AOT verified. Standard
JavaScript web build passed (97.5 sec). Its pre-existing Google Identity SDK Wasm
dry-run incompatibility and missing Cupertino-font warning remain; no Wasm build
is claimed. No app/host was launched, no private account/Vault
data was accessed, no archive/publication/shutdown occurred. No Android build or
native touch/screen-reader acceptance is claimed. The two pre-existing skips
are native symlink permission and interactive Google-account acceptance.

The first complete run was
stopped after two compact layer-panel checks found that the extra shortcut
pushed the existing Layers button offscreen. The shortcut now follows Layers,
retaining existing command positions; both panel checks pass in the 93-test batch.

Initial test-only issues (a nonexistent light-theme helper, duplicate endpoint
matcher for a self call, tooltip finder and fake-async image rendering) were
corrected; the clean focused batch includes those cases. Prior dirty work remains.

Next suggested task: UML-specific PlantUML text import/export with fidelity
reporting. Stop before implementing it.
