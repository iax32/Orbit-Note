# Desktop interaction quality

## Canvas transfer and gesture reliability — 2026-10-18

Canvas cut, paste, image loads, reference pickers, context-menu actions and
prepared file-drop placements reject stale boards/scenes and read-only
transitions. Leaving and returning does not revive an old action; a newer
clipboard request takes precedence. Missing ordinary dragged sources refuse a
broken placement. Captured file imports still use the repository's existing
ownership and recovery checks; removing a placement never deletes its object.

Cancelled drags restore geometry and prior selection. A second finger rolls
back provisional element movement before navigation, and cancelled two-finger
navigation restores its starting camera. Read-only changes cancel provisional
geometry; unguarded editors also cancel on external scene changes. Guarded
workspace editors keep a competing gesture for recoverable draft review while
preserving shared data. Copy/cut/paste/delete/duplicate cannot accidentally
commit that geometry as part of another operation's undo entry. Undo/redo during
an active pointer gesture first cancels that gesture.

Delayed text/image paste retains the original world position even while panning.
Empty-space context Paste centers supported Markdown content at the chosen spot.
Invalid image results preserve selection and report failure. Ink transfers change
the placement origin once, retaining local samples, pressure/time/extension data.
Align/distribute follows the same rule; its menu wraps at narrow widths and
large text. Selection status remains within the viewport and wraps as needed.
Unsupported labelled drawings preserve the entire clipboard payload in Rich and
Source instead of silently reducing a selection to labels or partial content.
This preserves data; it does not add automatic rendering for unsupported drawings.

Headless pointer/keyboard/clipboard-adapter checks, 390-pixel/200% text layout and
native saved/reopened JSON cover this subset. Physical/external-application
clipboard and touch/stylus acceptance remain unverified; no desktop-control
testing is used. [Actual task evidence](../tasks/canvas-transfer-quality-2026-10-17.md).

## Browser paragraph-list paste — 2026-10-15

Rich browser paste keeps a list item's leading paragraph/div wrapper on the same
bullet. Imported `<li><p>…</p></li>` no longer becomes an empty editable bullet
plus an unrelated paragraph. Formatting, Unicode, links/code and normal paste undo
remain intact. Intentional empty list items, separate prose paragraphs and authored
Markdown/plain paste are retained; existing notes are not silently rewritten.
Headless keyboard/clipboard fixtures cover conversion and Rich block presentation.

## Table and connector reliability audit — 2026-10-15

Table grid copy quotes CSV/TSV delimiter, quote and empty cell values; blank rows
retain their positions. Unquoted tabs identify TSV ahead of commas. Paste uses
one captured plain-text fallback. Single-line native caret paste retains prose
commas/quotes inside its cell; explicit Paste cells still imports CSV, and native
HTML/tabs/multiple rows still import grids. Rectangular keyboard/menu paste starts
at the range's upper-left corner and refuses a changed range, edit or note owner.
Cell/range cut waits for successful clipboard writes before deletion, retains
composition, refuses stale completions (including note-switch-and-return) and
uses the ordinary document undo boundary. Native menu actions share the guards.

Canvas duplicate remaps copied connector endpoints to copied placements; endpoints
outside the copied set stay attached to their existing placements. When an attached
placement is outside the copied set, clipboard copy stores visible endpoint
positions so the detached paste retains its shape. Fully connected copies keep
their authored fallback coordinates. Invalid/unfamiliar connector field types use
safe rendering/hit-test defaults without rewriting JSON. Original placement data
remains untouched for cut validation and history; successful duplicate/paste
operations still undo together.
These are headless native-action/adapter and geometry tests; real hardware/external
application clipboard acceptance is not claimed. No source schema migration.

Status: planned. Source: S10 in the [source map](../product/conversation-extraction.md).
These are delivery requirements of the relevant feature, not optional polish and
not permission to implement all of them in M0. See the [backlog](../planning/feature-backlog.md).

## Requirements

| ID | Observable behavior |
|---|---|
| DES-01 | Ctrl+C/X/V works in the focused editor, object list and Canvas. Offer plain-text fallback for unsupported rich clipboard data; table copy publishes HTML plus plain text where the host supports it; preserve supported links, lists and images without executing pasted HTML. |
| DES-02 | Paste screenshots from Windows Snipping Tool and images from browsers/apps; import owned attachment bytes and insert a document embed or Canvas placement according to focus. |
| DES-03 | File Explorer/browser drops distinguish files, images, URLs and text. Show the insertion target and copy/link semantics before completion; cancelled or failed imports leave no broken embed. |
| DES-04 | Image handles resize with aspect ratio preserved by default. Replace, open original and Show in Explorer are available where supported. Removing an embed never silently deletes the shared attachment. |
| DES-05 | Move/copy, multi-select, range selection, Ctrl+A and context menus operate on the focused surface; copy gives new identities only when explicitly duplicating objects. |
| DES-06 | Undo/redo, autosave, crash recovery and subtle save/offline/sync status accompany every durable editing surface; pending and failed writes are distinguishable. |
| DES-07 | Mouse, touchpad, keyboard zoom and stylus input coexist without accidental drawing during navigation. High-DPI and multi-monitor changes retain usable coordinates, text and reachable windows. |
| DES-08 | Keyboard focus, accessible names, text scaling and reduced motion are supported. Tabs, reorder, reopen, splits, shortcuts, fullscreen and session restoration follow the shell/context specs. |
| DES-09 | Later image cropping retains original bytes and recoverable crop metadata; export states whether it includes the original or a rendered derivative. |

## Workflow and boundaries

Copy a screenshot, focus a note, paste, resize, then place the same attachment on
a Canvas. Remove the note embed: the Canvas image must still work. Attachment
garbage collection requires reference accounting and a recoverable cleanup step.
Use platform adapters for clipboard, file dialogs and external-file actions;
browser builds must offer an appropriate alternative to Show in Explorer.

## Acceptance and failures

Test paste from Snipping Tool/browser, mixed-format clipboard, unsupported format,
large image, cancelled drop, read-only workspace and failed disk write on Windows.
Verify selection scope before Ctrl+A/Delete and undo after object movement.
Reopen on a single monitor after closing on a second: windows remain reachable.
Native clipboard and pointer checks complement widget tests; simulated paste alone
does not establish desktop interoperability. Related contracts:
[attachments](attachments-and-research.md), [history](history-and-recovery.md),
[shell](shell-and-navigation.md), [continuity](home-and-work-sessions.md).

## Incremental desktop acceptance

The current batch adds pane-aware tab cycling/closing and middle-click tab close, plus Notes-tree drag/drop via existing safe move commands. Native window geometry persistence remains unimplemented. See [batch evidence](../planning/audit-polish-batch.md).

## Note / Canvas clipboard transfers — 2026-10-10

Clicking a rich-note image selects its block immediately for Ctrl+C/X/V and
Delete; Open original remains available in the toolbar/menu. Its menu includes Copy image, Cut image
and Remove embed. Rich block/cross-document and Markdown Source selections resolve
complete image-block paths against the owning note before copying, so Canvas and
other notes can reuse the same Vault attachment. Successful cuts use normal note
history; failed writes or intervening source/selection edits retain the source.

Canvas recognizes complete image blocks, image-and-text sections (separate image
and prose placements), and standalone universal object links. Other Markdown stays
literal text, including image examples inside code fences. Paste creates fresh
placement IDs, retaining matching attachment/object identity. Canvas clipboard
images, object links and text become Markdown when pasted into Rich or Source;
unrepresentable drawings retain their literal payload. Canvas-to-Canvas paste
remaps group/column/endpoint identities, shifts placement origins and connector
endpoints, and retains local ink samples and their metadata.
Cut removes placements only, with clipboard-failure and changed-selection guards.
Transfers share the owning surface's undo; no shared attachment is deleted.

This subset covers same-Vault references. Cross-Vault attachment byte transfer,
inline image extraction and arbitrary drawing-to-Markdown conversion are not
claimed. Automated regression evidence is in the current task; native external-app
clipboard acceptance remains separate from simulated keyboard/clipboard tests.

## Clipboard safety audit — 2026-10-12

Rich prose and Markdown Source keyboard/native-menu cuts await clipboard success
before deleting. Failure retains the text, and deletion refuses changed owners,
source/selection or editing revisions. Switching away and back does not revive a
pending operation. Native editable actions delegate to the same guarded handlers;
ordinary document history still owns undo. Plain document-range paste bypasses
Orbit Canvas interpretation just like plain single-field paste.

Canvas text/scene paste captures scene identity/revision, selection and request
order; changed scenes or newer requests invalidate older results. Canvas clipboard
batches are prepared before mutations: invalid, unsupported, non-map and duplicate
placement IDs refuse the whole batch with feedback, retaining selection and undo.
Successful batches still remap placement/group/column/connector identities, retain
canonical object references and produce one undoable edit. Empty batches do nothing.
Image loading catches failures and refuses changed boards/read-only scenes before
placing the result. An already imported attachment is not silently deleted.

These are synthetic clipboard/keyboard failure-boundary checks; real external-app
clipboard ownership and native menus on hardware remain unverified. Other
specialized editing controls retain their own clipboard paths.

## Import/drop ownership stress audit — 2026-10-13

File pickers, image decoding and ordinary file drops retain the originating Vault
identity and controller generation across asynchronous reads/imports. A changed
or closed Vault refuses late capture instead of importing/opening into its new
context. Repository attachment imports independently capture their Vault generation
before queueing and own a bounded byte snapshot, so caller buffer mutation cannot
change the hashed/saved source. A same-Vault tab change retains the captured drop
target; note links are relative to that note's current owning path. Deleted,
read-only and unsupported board targets refuse late placements. Failed Canvas
file reads report failure and let other files in the batch continue. Image decoder
resources are disposed even on failure. Completed imports can remain discoverable
without a placement; the app does not purge shared attachments automatically.

Reuse of a canonical attachment preserves explicit project/course/context ownership.
Creative reference capture also retains its original capture-board provenance and
folder where present. Sharing a source across boards references that object; it
does not implicitly move the original source between projects.
