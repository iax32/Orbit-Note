# Freeform pages, handwriting and drawing

Status: planned M4; recognition and advanced erasing exploratory.
Sources: S03, S07, S08, S09 in the [source map](../product/conversation-extraction.md).
Architecture: [shared canvas/ink](../architecture/canvas-engine.md),
[vector file formats](../architecture/storage-formats.md).

## Purpose and workflow

A freeform page lets a student type in one place, draw a diagram beside it, paste
an image, mark a PDF and connect the pieces. It uses the board's spatial/ink
primitives with writing-oriented defaults: vertical growth, optional page boundaries,
paper backgrounds and readily accessible pen tools.

## Requirements

| ID | Observable behavior |
|---|---|
| INK-01 | Clicking/tapping an appropriate empty region creates a positioned text area; text, ink, objects and attachments can coexist on one page. |
| INK-02 | Page presets support finite or extendable content regions. Changing a preset does not flatten or duplicate existing content. |
| INK-03 | Pen/highlighter retain editable vector samples and style; pressure, tilt and velocity may improve rendering when available, with predictable fallbacks otherwise. |
| INK-04 | Lasso selects ink/elements for move, resize, copy, delete, grouping or linking; selection should not require converting handwriting to text. |
| INK-05 | Stroke eraser removes complete strokes. Object erasing and later segment erasing have distinguishable modes; segment erasing preserves the remaining editable parts. |
| INK-06 | Layers can separate notes, ink, images, connections and background, or teacher material and personal annotations, with visibility/lock controls. |
| INK-07 | Backgrounds include blank, ruled, grid, dots, graph paper, Cornell layout, custom image and PDF page as supported presets. |
| INK-08 | PDF and image annotation reuse pen, highlighter, eraser, lasso, stroke serialization and undo with a source-coordinate adapter. |
| INK-09 | Optional recognition offers reviewed conversion to text, a linked existing object, a new concept/task, or a cleaned-up shape/connector while retaining the original. |
| INK-10 | Export editable drawing data and supported SVG/PNG/PDF renditions. A raster export is a derivative, not the only saved drawing. |
| INK-11 | Pointer cancellation, touch/stylus arbitration and app interruption preserve committed strokes; one finished stroke is one meaningful history operation. |

## Interaction details

Pen mode draws; touch may pan while a stylus draws where hardware supports that
separation. Mouse drawing remains possible. Provide explicit mode feedback and
keyboard alternatives for tools. Palm rejection, hover, pressure and tilt require
real-device validation; a shared engine alone cannot promise those capabilities.

Text editing inside a freeform region should not compete with pan/selection gestures.
Selecting a handwritten equation and resizing it changes vector geometry, not its
recognized meaning. Recognition must preview the result and let the user correct
it. “Create task” retains a source relation to the selected drawing/page region;
rejected recognition leaves all ink unchanged. Shape cleanup is an explicit
accepted transformation with undo.

## Data, recovery and large drawings

A drawing owns strokes with local IDs, bounds, points and style. Individual samples
are not global objects or history records. A page references drawing/content objects
and owns placement. Pressure/tilt absence is represented explicitly, not invented
as measured hardware input. Preserve original samples when generating simplified
paths/previews needed for performance.

Ink annotation stores enough source identity, page/region and transform information
to remain aligned after viewport zoom/rotation. Replacing/reordering a PDF is a
re-anchoring problem, not permission to silently draw marks on another page.
When a source is missing, preserve annotations and show an unresolved background.
Partial save/disk-full retains recoverable local work under the storage contract.

## Acceptance scenarios

- INK-03/10: draw using stylus and mouse fixtures, save/reopen/export, then edit the
  resulting strokes at higher zoom without flattening or losing style.
- INK-04/05: lasso several strokes, move/erase and undo; unrelated strokes remain.
- INK-08: zoom, rotate and resize a PDF/image view; marks align to the same source region.
- INK-09: recognize “conflict handling” into a task, correct text, accept and undo;
  the original drawing remains available throughout.
- INK-11: simulate lost pointer/cancel and a large stroke workload without one
  persistence transaction or widget per sample.

## Delivery

Start with pen/highlighter, stroke erase, vector save/reload and page presets.
Add lasso/layers and annotation adapters, then evaluate segment erasing and
recognition independently. No OCR/AI service is required to draw or read ink.
