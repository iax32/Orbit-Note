# Desktop interaction quality

Status: planned. Source: S10 in the [source map](../product/conversation-extraction.md).
These are delivery requirements of the relevant feature, not optional polish and
not permission to implement all of them in M0. See the [backlog](../planning/feature-backlog.md).

## Requirements

| ID | Observable behavior |
|---|---|
| DES-01 | Ctrl+C/X/V works in the focused editor, object list and Canvas. Offer plain-text fallback for unsupported rich clipboard data; preserve supported links, lists and images without executing pasted HTML. |
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
