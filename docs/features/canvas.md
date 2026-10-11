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
