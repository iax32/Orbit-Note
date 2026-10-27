# Everyday workflow polish

Owner-approved 2026-10-27. Extends EDT-03/04/07, NAV-10/11, ORG,
CAN, LNK, PORT-05/06 and HIST through existing local boundaries.

| Workflow | Delivered behavior |
|---|---|
| Paste feedback | Rich/Source text and Canvas placement pastes offer guarded Undo. Rich single-block HTML paste can be replaced with the captured plain representation. Ctrl+Shift+V remains the explicit plain-paste path. Feedback cannot undo later edits or another owner. |
| PDF to notes | Orbit PDF context-menu Copy and Ctrl/Cmd+C preserve ordinary system clipboard text and remember the last bounded source in memory. Matching paste into a note offers original line breaks, cleaned paragraphs or a page-linked quote. Cancel inserts nothing and returns focus before validating insertion. |
| Return navigation | Up to 50 primary-pane visits retain separate note selection/scroll/view state, Canvas camera and PDF page/zoom. Precise links within one note create distinct visits. Back/Forward skip unavailable or trashed objects and cannot cross Vault openings. |
| Moving | Folder drop targets name the destination without shifting the tree. Successful drops and individual/batch object moves offer Undo. Guards reject later-edited/moved objects. Canvas/file/task ownership uses the logical folder rather than the metadata file's directory. |
| References | Existing hover previews also open on long press. Narrow/enlarged-text previews scroll and wrap their actions. Heading/block links show the referenced passage or an actionable missing-section message, folder and live/read-only/Trash status. |
| Saving and sync | Local save status remains separate from actual Drive/shared status. Failed saving offers retry; existing recovery banners retain details. The sync control opens Sync & sharing. Displaying status does not initialize a Google adapter for a local-only Vault. |
| Diagram tracing | Hover or single-select a connection to emphasize its path, markers, multiplicities and endpoints. No route mutation, rerouting or bundled lines; export remains unaffected. |
| Drawing tools | Last selected tool, pen style/width/color and eraser radius are saved per board in local session camera configuration. Invalid/future values fall back safely. No document edit or sync protocol change. |
| Search return | Query, filters, page, selected result, preview and scroll survive leaving/reopening Search in this controller. Cached results refresh without clearing the return point; scope/Vault changes invalidate incompatible state. |
| Rename | Shows owner path, incoming reference count and up to five source paths. Duplicate names produce a nonblocking warning; stable references remain canonical. Existing stale/read-only metadata guards remain. |
| Publishing | Generated page/notice summary beside export actions; existing missing-resource/fidelity warnings remain. Successful export optionally remembers settings in the note, including the editor-design toggle. Cancel/failed file export does not remember settings. Compact/keyboard layouts scroll the action area. |
| Focus | PDF paste, Rename and publishing restore origin focus. Existing nearest-overlay Escape and pane focus behavior remain; a canceled popup must not redirect subsequent typing. |
| Deletion | Canvas removal explicitly describes placements and retained originals, with guarded Undo. Original object Trash/history semantics remain separate. |
| Large projects | Navigation/search retain state; existing failed-save forms and draft recovery remain. Weak snapshot caching avoids repeated whole-note statistics scans on view/presence changes, without caching stale counts after edits. |

PDF provenance choices apply only to the last explicit in-app copy up to 1 MiB,
when its plain text still matches. No source is guessed for external PDF apps or
unrelated clipboard text; larger copies still paste normally. Cleanup is opt-in,
preserves blank paragraphs, indentation, fences and display math, and runs off the
UI isolate above 32 KiB. It cannot reconstruct arbitrary multi-column PDF reading
order. Normal clipboard transfer remains portable without Orbit metadata.

Export settings use the existing guarded v1 publication comment; unknown fields
remain preserved. Choosing another PDF theme does not rewrite authored colors.
Saved settings use existing Vault persistence/replication. Search return points,
navigation visits and camera/tool preferences are private view state, not new
universal objects or cloud credentials.

Validation and physical-device limitations: [delivery evidence](../tasks/workflow-polish-2026-10-27.md).

## Steady workspace refinements

Owner-approved follow-up, 2026-10-27. Existing features and identities remain.

| Area | Behavior |
|---|---|
| Loading | Local Markdown images reserve the same loading/decoding/retry slot, using imported PNG/JPEG/GIF dimensions when available and a bounded fallback otherwise. Complete images remain contained. PDF geometry retains existing virtualization. |
| Dragging | Explorer drags scroll at the edge, including at a stationary pointer. Moving selected Canvas items pans at the edge with one normal undoable move; drawing/resizing/endpoint editing retain their gestures. Release, cancellation, read-only and owner changes stop the timer. |
| Duplicates | Single imports offer reuse, independent copy or cancel for identical content in the destination scope. Copies have separate identity/history and share verified ordinary bytes. Multi-file import reviews names/destination with one explicit reuse policy. |
| Forms | Reference details, figure captions/sources and PDF review comments offer **Keep draft and close**. Reopening restores unapplied input and flags a changed source. Editor/save acceptance cleans up the old draft. Explicit discard removes it. Failed persistence keeps input open and retryable; concurrent retained edits cannot overwrite each other. |
| Unavailable actions | Shared Orbit controls expose an unavailable-context explanation in tooltips and semantics, with specific reasons supported. Canvas Undo/Redo distinguish empty history and read-only state. |
| Bulk review | Explorer multi-move and Trash review titles, source folders, count and destination. Move rechecks the reviewed versions. Trash retains normal guarded recovery. Existing replacement previews remain. |
| Recovery | Kept forms explain that they remain unapplied; changed originals require review. Recovery files lists kept forms for review, copying, opening the original or confirmed discard, including drafts whose original is unavailable. Nothing automatically overwrites an original. |
| Selection | Split views mark the active pane with a thin foreground border and accessible primary/secondary/active/read-only descriptions, without reserving more Canvas space. Existing cross-pane focus guards remain. |
| Export names | Publishing has an editable filename and optional date. Suggestions preserve Unicode and remove illegal characters, trailing dots/spaces and reserved Windows basenames. The OS save dialog chooses the destination and confirms replacement. Native exports stage complete bytes beside it; cancellation, write failure or detected destination changes preserve the previous file. |
| Long work | Multi-file import shows current file/count and cancels between safe steps; completion reports the imported count. Publishing preparation has phase feedback and cancel/retry; file writes have progress/cancel. Late canceled preparation cannot publish output. Existing indexing cancellation remains. |

Kept forms are device-local workspace settings, not canonical objects or portable
cloud preferences. They require an explicit keep action, are bounded to 25 records
and 96 KiB per form, and exclude account/password fields. Unrecognized versions
remain preserved. This does not claim crash recovery for every unsaved dialog.
Browser downloads use browser destination/overwrite behavior. Cancellation finishes
the current safe step instead of interrupting a committed command. Older images
without dimensions can have empty space inside the stable fallback slot.

Validation: [steady workspace evidence](../tasks/steady-workspace-2026-10-27.md).

## Quiet details

Owner-approved twelve-area follow-up, 2026-10-27:

| Detail | Implemented behavior |
|---|---|
| Reading position | Rich blocks compensate for an already-laid-out block growing above the viewport. User scrolling, resizing, navigation and owner changes take priority. Existing stable image slots and PDF page geometry remain. |
| Selection after actions | Batch moves retain selected object identities instead of clearing them. Rename/sort continue to reference IDs, not row indexes. Trash still removes deleted selections. |
| Canvas spacing | Nearest aligned neighbors can show two measured equal-gap guides while moving. Existing edge/center alignment wins when both apply. Alt bypass and one-command Undo remain. Guides do not alter exported diagrams. |
| Activation | An inactive split Canvas consumes its first drawing/drag press for activation. The next gesture edits normally. Wheel navigation still works on its first event; text fields and modal focus restoration keep their existing input path. Tab-strip activation remains separate from document input. |
| Touch targets | Selection/resize/endpoint hit areas grow for touch and pen without enlarging handles or strokes. Existing pen drawing and palm/multitouch guards remain. |
| Document preferences | PDF page mode, markup/notes visibility, paper tone, comfort/text-only reading and highlight color are remembered per document in local view settings. Existing note view/collapse and Canvas tool preferences remain. Only changed known options are written; unknown future settings survive. |
| Search refresh | Keeps the canonical selected location through an index refresh, including changed title/checksum/source offset. Closest compatible location is used if exact ephemeral offsets changed; explicit query/filter/page/user-selection changes take precedence. |
| Table transfer | Default rectangular copy supplies TSV text plus HTML where supported, preserving cell line breaks. CSV/HTML remain; explicit Markdown copy includes the corresponding column headers. Source Markdown and clipboard failure/Undo guards remain. |
| Full names | Explorer rows expose complete names and folders through hover/long-press tooltips, including archived folders. Visible rows remain compact. |
| PDF markings | Thin marks have a bounded screen-space hit allowance. Overlapping marks open an explicit chooser with quote/style/comment. Existing text selection, forms mode, read-only and source-version checks remain; exact single-hit queries retain their fast path. |
| Closed tabs | Tab overflow adds **Reopen closed tab group** for Close others / Close to right. Up to ten local groups retain order and pane targets, using existing per-document position/selection/view records. Already-open tabs stay intact; deleted originals are skipped. Single-tab reopening remains. |
| Local errors | Failed Canvas images show a message at their placement and expose Retry unavailable images. Retry changes no document content. Native decode resources are released on failures, and replaced files cannot inherit an older failed decode. Existing local image/PDF/export retry surfaces remain. |

Native PDFium fixtures and test clipboard transport validate application behavior;
physical tablet/pen and Excel/Word clipboard acceptance remain separate. The scroll
anchor is not a universal document reflow engine, and it never overrides an explicit
scroll. Recovery groups contain view references, not object bodies. These changes
require no migration, account or new package.

Evidence: [quiet details](../tasks/quiet-details-2026-10-27.md).
