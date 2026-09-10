# User journeys and cross-feature acceptance

Status: future acceptance scenarios derived from the source conversation. These
are integration targets to use as relevant milestones arrive, not M0 tasks.
Example content is illustrative and need not be preloaded into a user's workspace.

## J01 — Capture an idea before it disappears

**Situation:** a user has an unfinished idea and no network connection.

1. Invoke in-app quick capture, or later a permissioned global/share-sheet entry.
2. Enter text or add a URL/file; the destination visibly defaults to Inbox in a
   known workspace. Organization fields are optional.
3. Save. Receive truthful local save status. Dismiss the capture surface only
   after commitment or after choosing to keep/recover an unsaved draft.
4. Reopen Orbit Note and find the item. Add a project, collection or task meaning
   without making an unrelated second copy of its content.

**Acceptance:** interruption/disk failure preserves the original input; repeated
delivery of a share action does not silently duplicate a committed capture.
Completing triage removes Inbox membership/status, not the object.

**Specs:** [capture](../features/capture-and-inbox.md),
[organization](../features/objects-and-organization.md).

## J02 — Study a lecture across typed and handwritten content

**Situation:** a student opens University → Algorithms → Lecture 1 on a tablet.

1. Create a freeform page with a dotted or lined background; click/tap to type an
   explanation of graph theory and draw a diagram next to it.
2. Attach the lecture PDF and add an ink annotation and a passage highlight.
3. Link the highlight to the Graph Theory concept, retaining page/region provenance.
4. Lasso a handwritten reminder and request “Create task.” Review recognition,
   choose the project/deadline and keep a link to the original stroke region.
5. Find the task in planning and return to its exact source in the lecture.

**Acceptance:** handwriting remains editable after reopen/export; PDF annotations
stay aligned through zoom/rotation; unsupported recognition falls back to manual
typing rather than losing the selected ink. Task creation is reversible.

**Specs:** [ink](../features/freeform-and-ink.md),
[research files](../features/attachments-and-research.md),
[tasks](../features/tasks-calendar-and-planning.md).

## J03 — Plan one project in several views

**Situation:** a builder organizes a Language Learning App project.

1. Set project status, priority and deadline; write a design document.
2. Place the existing project and related notes on an infinite board. Add a
   “Backend” frame and connect the project to SQLite with a typed “uses” relation.
3. Open a Projects table and Active Projects Kanban view; both reference the
   existing project. Changing status in either updates the object.
4. Embed the active-tasks view on the board and keep independent placement size.
5. Remove one project card, then reopen the project through search.

**Acceptance:** no content duplication, no accidental object deletion from removing
a card, live view updates, and a semantic relation visible in the graph. An unlabelled
decorative arrow remains decoration unless the user explicitly gives it meaning.

**Specs:** [boards](../features/spatial-boards.md),
[views](../features/collections-and-views.md),
[links/graph](../features/search-links-and-graph.md).

## J04 — Resume meaningful work after a break

**Situation:** a user returns after a week away from a research project.

1. Home shows the last saved project session and unresolved continuation note.
2. “Continue” opens its Space, relevant notes, board and task view with a fallback
   for any unavailable object or plugin.
3. The context inspector shows related files, decisions, assumptions and recent
   recorded activity. It can explain which recorded source produced each item.
4. The user reviews a resurfaced source, dismisses an irrelevant suggestion,
   completes one task and writes a new continuation note before ending the session.

**Acceptance:** no background surveillance is required, missing views do not block
restoration, durations distinguish active/idle time where measured, and an AI summary
is labelled separately from recorded events.

**Specs:** [Home and sessions](../features/home-and-work-sessions.md),
[decisions/provenance](../features/decisions-and-provenance.md).

## J05 — Let AI organize safely

**Situation:** Inbox has loosely related notes, an apparent duplicate and a vague title.

1. Select the intended scope and provider; inspect any remote transmission choice.
2. Request organization. The proposal lists rename, link, membership, concept
   creation and optional merge/archive changes with supporting sources.
3. Accept a subset. If a note changed after proposal generation, review the stale
   action again; do not overwrite the intervening edit.
4. Inspect the applied history group and undo it. If subsequent edits overlap,
   review a compensating change instead of blindly replacing current content.

**Acceptance:** rejecting a proposal changes no knowledge; failed/partial actions
have explicit status; the original content remains recoverable; excluding a source
from remote AI actually excludes it from the request.

**Specs:** [AI](../features/ai-and-knowledge-health.md),
[history](../features/history-and-recovery.md).

## J06 — Make the interface personal, then recover it

**Situation:** a power user wants different Writing, Research and Planning layouts.

1. Arrange tabs/splits and inspectors, choose density/fonts/theme and save each layout.
2. Assign a layout/dashboard/context filter to a Space without moving content.
3. Customize navigation and shortcuts; resolve a conflict with a visible choice.
4. Import a layout referencing a missing plugin. See a recoverable placeholder.
5. Hide most UI, enter Zen mode and invoke Reset current layout through the
   always-available recovery route.

**Acceptance:** reset changes layout only, keeps content intact, restores visible
navigation, and works without the missing plugin. Unplugging a monitor cannot strand
a floating window permanently off-screen.

**Specs:** [navigation](../features/shell-and-navigation.md),
[customization](../features/customization-and-spaces.md).

## J07 — Work offline on two devices, then reconcile

**Situation:** a user enables optional sync and edits the same note on two offline devices.

1. Both save locally without waiting for sign-in/network availability.
2. Reconnect; show pending transfer, then a conflict when both edited a shared base.
3. Compare both versions and choose/merge explicitly. Retain recoverable history.
4. Delete a different object while another device is offline. On return, it sees
   deletion intent rather than resurrecting a stale copy automatically.

**Acceptance:** retries/duplicate deliveries are idempotent, disconnecting sync
does not remove local content, and attachment transfer failure is visible separately
from note save success. Shared-workspace permission loss has a defined product policy
before collaboration ships.

**Spec:** [sync/collaboration](../features/sync-and-collaboration.md).

## J08 — Bring knowledge in and take it back out

**Situation:** a user imports an existing Markdown folder or supported app export.

1. Preview counts, unsupported formats, duplicate identities and naming collisions.
2. Import into a chosen workspace with originals preserved and a clear result report.
3. Use imported notes/files and add a board, ink and typed relationships.
4. Export a complete workspace. Open Markdown in another editor and inspect the
   documented structural files with a generic JSON tool.
5. Restore into a fresh workspace and rebuild SQLite indexes from durable sources.

**Acceptance:** record count and reference integrity survive the supported round-trip;
unsupported rich content is preserved as original/fallback with a warning in the
report, not silently discarded. Credentials/device secrets are excluded from exports.

**Spec:** [portability](../features/import-export-and-portability.md).
