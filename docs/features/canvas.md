# Live document references on Canvas

Template consumption (2026-10-09): a board stores `canvasPresetApplied: true`
after its first editable emission. An emptied preset board therefore stays empty
when reopened. Delete/Backspace still removes only unlocked placements, supports
undo, and never trashes referenced tasks or notes. Unknown scene fields survive.

From a Markdown note's copy menu, choose **Place current block on Canvas…**.
The ordinary prose block receives a lazy stable anchor; the chosen board receives
one object-reference placement. Updates read the canonical note. Missing source
blocks show a readable failure state; source opening and placement deletion retain
the object's identity and history.

Right-click a selected Canvas element and choose **Copy Canvas element reference**.
Paste the WikiLink into a note to reopen the same board element with camera focus.
Existing selection-to-note export remains an explicit copying operation.

The existing derived uniform grid serves viewport/hit/selection queries and
incremental geometry changes. Large-bound multiplication is guarded against
overflow. No spatial index is serialized, and no unsupported FPS claim is made.

See [references](../architecture/references.md) and
[tests/diagnostics](../tasks/architecture-composition-2026-09-30.md).

## Imported drawing style resilience — 2026-10-12

Canvas text font sizes resolve to finite positive rendering values; invalid values
fall back, and finite values are bounded. Section line widths likewise resolve to
finite non-negative widths. The original fields remain in the scene data for
compatibility/recovery; rendering does not rewrite the user's stored source.
Clipboard batches with duplicate or unsupported placement IDs refuse atomically,
without partially replacing selection or modifying existing undo history. See
[desktop clipboard boundaries](desktop-interactions.md).

## Stacking-history stress audit — 2026-10-13

Bring to front reserves a unique stacking order. New placements can no longer
share that order and change their visual ordering when a delete is undone. Seeded
stress checks mix insertion, movement, removal, reorder, cancellation, undo/redo,
spatial queries and JSON reopen while retaining unknown scene data. This is
correctness evidence, not a hardware frame-rate or memory-capacity benchmark.

## Cross-surface object bridges — 2026-10-13

Canvas object insertion uses the same searchable preview picker as live note
cards. Selected object cards expose Object connections in the context menu.
Use elsewhere places an ordinary shared-object card with its own placement UUID,
exact referenceTarget and preview presentation. Normal history/save owns scene
changes; removing a placement leaves the source object intact. Live note cards
and section embeds paste as shared cards instead of flattened text. Precise
page/section/element fragments survive transfers back into Markdown. Source/scene
changes while choosing a target reject the stale insertion.
