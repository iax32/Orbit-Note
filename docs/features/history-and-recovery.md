# Universal history, undo and recovery

Status: planned incrementally from M1; long-term selective reversal/branches exploratory.
Sources: S03, S04, S08, S09 in the [source map](../product/conversation-extraction.md).
Architecture: [durability/save contract](../architecture/storage-formats.md).

## Purpose and workflow

Users should be able to trust editing and organization, especially when an AI or
automation proposes many changes. A history entry should describe a meaningful
operation—moved six cards, changed project status, renamed a note, accepted an AI
organization batch—and provide appropriate undo/restore rather than only text-editor undo.

## Requirements

| ID | Observable behavior |
|---|---|
| HIST-01 | Supported content mutations retain enough before/after information for undo or recovery; navigation/selection changes need not become durable content history. |
| HIST-02 | Group continuous input into meaningful operations, such as one stroke or drag, and expose sensible undo/redo descriptions. |
| HIST-03 | Trash/tombstones and restore are distinct from permanent deletion; removing a view/placement/membership is distinct from trashing an object. |
| HIST-04 | Object revisions and history can be inspected and compared; restoring an old version preserves awareness of current/later edits. |
| HIST-05 | AI/import/automation batches record actor, intent, affected objects and success/partial-failure status, with reviewed recovery where appropriate. |
| HIST-06 | Workspace snapshots can compare/restore available content and structure with an explicit preview and a pre-restore recovery path. |
| HIST-07 | Retention, compaction and permanent cleanup are visible policies; users are not promised unlimited undo where required history no longer exists. |
| HIST-08 | Exploratory branches let users test reorganization separately and compare/merge later; a snapshot/duplicate is not advertised as full branching without merge semantics. |
| HIST-09 | Crash recovery can complete or reconcile committed work without relying solely on a disposable SQLite index. |

## Undo semantics

An immediate undo can restore the immediately preceding operation when preconditions
still hold. “Undo the AI cleanup from three days ago” is different: later user
edits may overlap it. The proposed behavior is to build a compensating change set,
show conflicts and preserve both histories instead of blindly writing old bytes.
An inverse command must validate the current revision just like a normal command.

Semantic operations may span content and structure. Renaming a note can require
reference reconciliation; a relation plus connector creation may span records.
Before such operations ship, their transactional/recovery behavior must satisfy
the existing multi-file journal design gate. SQLite transactions do not make
separate files magically atomic.

External side effects (for example a plugin API request) may not be reversible.
The application must identify the boundary rather than falsely promise an undo
can unsend/revoke something on a third-party system. Prefer preview and explicit
authorization for such capabilities; local reversible edits remain the default.

## Acceptance scenarios

- HIST-01/02: drag several cards in one gesture, undo and redo once; all selected
  geometry changes together and unrelated object content stays intact.
- HIST-03: remove a board card, trash its object separately, then restore; validate
  the difference and retained unresolved-reference behavior.
- HIST-05/09: fail a batch between durable writes; restart and recover a consistent,
  explainable outcome with no silent loss of accepted content.
- HIST-04/06: attempt restoring a prior version after subsequent edits; preview
  impact and retain a way back to the pre-restore state.
- HIST-07: expire retained history and show what can still be restored accurately.

## Delivery

### Current dialog accessibility

Revision history stacks its list and comparison view in narrow windows or with
enlarged text. Snapshot labels, titles, and controls wrap; revision and document
viewports remain bounded and scrollable. Dialog headings scroll with content
while Close and confirmation actions stay outside that scroll surface. Snapshot
label entry supports keyboard insets without reducing system text scaling.
Recovery-file review keeps full paths accessible and exports immutable copies.
Backup import review exposes all validation notices before asking for a parent
folder, preserving the separate-workspace import and retained-journal policy.

Start with single-object save/recovery and meaningful local undo. Add durable
grouped history when multi-object mutations require it. Full workspace time travel,
historical board rendering, selective reversal and branches need separate design
and storage budgets. They must not be claimed by a basic undo stack.

## Competing pane drafts — 2026-10-13

Note body and Canvas scene publications compare against the last content that
the originating pane observed. A conflicting edit keeps the shared content and
retains the competing draft rather than overwriting it. Notes show Review drafts;
the workspace warning button and command palette keep the review accessible
after its pane is closed. Review compares shared and retained content, saves a
separate ordinary note/Canvas, or explicitly discards the retained draft. Saving
a copy keeps source identity references and metadata; it never rewrites the
original. Failed recovery, or a newer edit arriving during recovery, retains the
unresolved draft. Canvas comparisons currently show serialized scene details.

Unresolved conflicts block normal exit/Vault switching via flushAll. Retained
conflicts are session-local, not a crash-durable journal or collaborative merge
algorithm. Hard process termination can still lose a retained conflict; save its
copy before closing. Title/property edits use their existing mutation paths.
Parallel saves retain the latest body/title/properties; no-op edit callbacks
avoid creating unnecessary dirty state/revisions. Queued object/folder creation
rejects changed Vault ownership, and creation freezes caller maps before waiting.

## Bulk lifecycle quality — 2026-10-19

Queued organization and lifecycle commands retain their originating Vault/opening.
Bulk moves and copies freeze their selections; duplicate copies skip trashed and
read-only objects. Empty Trash excludes items added after the command begins and
blocks on unsaved/conflicting work. If permanent cleanup partially succeeds, the
UI removes only durably deleted identities, retains survivors and reports failure.
Existing per-owner deletion and native folder journals still govern recovery;
this is not atomic grouped deletion or durable grouped Undo. Confirmation dialogs
reject retired Vaults/reviewed objects, and Explorer bulk Trash counts successful
commands while retaining failed selections. Guarded planning Undo retains later
edits and can retry a failed storage write.
