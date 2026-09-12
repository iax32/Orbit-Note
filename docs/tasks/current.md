# Current task — M6 local-first Google Drive / WebDAV sync

Owner-requested milestone, 2026-09-12. Status: pre-implementation audit and design.
No production sync implementation is delivered. Preserve all local/PDF/polish work.
The received brief stops at `ARCHIVED CONTENT`; its remaining requirements have
been requested. Resolve that missing tail before finalizing archive/deletion policy.

Required starting points: [audit](../planning/sync-audit-2026-09-12.md),
[design](../architecture/sync-design.md), [ADR-0016](../adr/0016-provider-neutral-sync.md),
[Google setup](../development/google-drive-sync-setup.md).

Next implementation stage: local Vault coordination, durable deletion intent and
recovery, explicit canonical inventory, separate durable sync state. Then build
the engine, Drive auth/provider/UI and WebDAV in that order with failure tests.
No cloud writes, credentials or new dependencies were introduced during the audit.
Audit baseline validation: flutter analyze clean; all 237 tests passed; Windows
release build passed (7.1 seconds). Logs: `.local/sync-audit-tests.log` and
`.local/sync-audit-build.log`. New documentation links, example JSON and
`git diff --check` passed. No Dart/platform source changed in this audit phase;
real cloud/provider/device tests have not been performed.

## Previous completed task — Task/List UX, Movable Note Blocks, Folder Deletion & Vault Files

Status: delivered and validated, 2026-09-11.

This focused implementation task delivered two primary functional and UX improvements
along with requested vault lifecycle features without redesigning the app or duplicating
universal architectures:

1. **Task / List UX (Notion-inspired polish and speed)**:
   - Clean, whitespace-driven task rows with animated checkbox completion, strikethrough, and muted finished states.
   - Saved view tabs: `To Do` (active only), `Today`, `Upcoming`, `Done` (completed items), and `Board` (3-column Kanban: To Do, In Progress, Done).
   - In-view live search, sort options (Title, Due date, Priority), filter by priority/project, and customizable property visibility toggles (due date, priority, project chips).
   - Friendly relative due date labels (`Today`, `Tomorrow`, `Yesterday`, `MMM d`) with overdue highlights for overdue incomplete tasks.
   - Compact priority picker pill and inline date picker popups.
   - Fast `+ New task` inline row at the bottom with sequential entry on `Enter` and `Esc` to dismiss.

2. **Movable Note Blocks and Paragraphs in Rich Markdown Editor**:
   - Contextual Notion-style `[ + ] [ ⋮⋮ ]` handle beside every content block (including ordinary text paragraphs, headings, list items, quotes, code, tables, equations, callouts, images).
   - `+` button opens a quick-insert menu to add any block type below.
   - `⋮⋮` handle supports smooth drag-and-drop reordering with a compact floating drag preview pill, 35% opacity on the dragging block, and a vibrant 2.5px primary accent drop indicator line showing insertion above or below.
   - Context menu on click with accessible touch/keyboard actions: Move up, Move down, Duplicate, Copy Markdown, Turn into (Heading 1-3, Bullet, Numbered, Checklist, Quote, Text), Create Task from block, and Delete.
   - Exact Markdown source preservation: proper separation rules (`\n\n` between prose/headings, compact `\n` between lists/quotes), pinned index 0 frontmatter protection, and document history undo/redo (`Ctrl+Z` / `Ctrl+Y`) integration.

3. **Folder Management, Permanent Deletion & Vault File Visibility**:
   - Folder deletion: `deleteFolder(folder)` trashes contained notes (`deletedAt` set), deletes directory from disk/storage, and cleans up workspace folder trees.
   - Permanent deletion: `deletePermanently(id)` removes file from storage and purges object from memory and index.
   - "Empty Trash" button in Trash view purges all trashed items with confirmation.
   - Vault files & PDFs visibility: Optional "Show files & PDFs" toggle in the notes explorer header (default off to prevent clutter), rendering files with file/PDF icons and open handlers.

## Validation

- Unit and widget tests added in:
  - `test/folder_delete_test.dart`: tests folder trashing and deletion on disk, permanent deletion, empty trash, and session state persistence.
  - `test/task_ux_test.dart`: tests friendly due date calculations, overdue checks, animated task rows, view tabs filtering, inline sequential task creation, and Kanban board view.
  - `test/movable_blocks_test.dart`: tests movable block extraction, frontmatter pinning, drag handle and context menu interactions, move up/down paragraph reordering, markdown separation preservation, duplication, create task from block, and full undo/redo restoration.

## Next recommended task

- PDF reader continuous page view and precise highlight-region navigation.

## PDF work continuation — 2026-09-11

The owner resumed the PDF forms/phone-reading work. AcroForm text/checkbox overlays,
persisted field drafts, filled-copy import and adjustable narrow-screen text reading
are implemented. Preserve the Task/block/folder work above. This continuation also
repairs its compile/test API mismatches. Final validation is complete; detailed
PDF boundaries are in attachments-and-research.md and ADR-0015.

PDF continuation validation: all 206 tests pass; analyzer clean; zero-change format
check passes for 129 Dart files. Windows release build passed (59.3 seconds).
Evidence: .local/pdf-work-tests-final.log and .local/pdf-work-build.log.

Integration repairs preserve the new Task/block/folder work: controller-backed
Task tests and creation properties, overflow-safe block menus, focus after block
moves for keyboard undo, and non-destructive folder removal. Folder deletion moves
owned notes out before trashing them, rejects unrecognized files, and native removal
only removes an empty directory. Multi-note deletion is sequential and may stop
partway on a recoverable move/save failure; no all-or-nothing folder transaction is
claimed. Nested empty-folder cleanup remains limited by empty-directory removal.

## Notion & Milanote Product-Polish Implementation Pass — 2026-09-12

Delivered a comprehensive product-polish pass across Rich Notes, Universal Canvas, and Tasks:

1. **Collapsible Headings & Content**:
   - Fold/collapse sections beneath headings directly from the block handle chevron.
   - Non-destructive: visual filter does not modify markdown files; collapsed states stored in editor session state.
2. **Turn Block Into...**:
   - Added Callout (`> [!NOTE]`) and Code block (```` ``` ````) to Turn Into menu alongside Headings 1-3, Bullet, Numbered, Checklist, Quote, and Paragraph.
3. **Page / Object Icons**:
   - Optional emoji icon header on notes with instant preset picker (`📝`, `💡`, `🚀`, etc.) and removal.
   - Preserved in `UniversalObject.properties['icon']` (YAML frontmatter / JSON).
   - Displayed in explorer, tabs, and object rows.
4. **Optional Page Covers**:
   - Preset gradient covers (`gradient:violet`, `gradient:sunset`, `gradient:ocean`, `gradient:forest`, `gradient:amber`, `gradient:graphite`) with change/remove controls.
   - Preserved in `UniversalObject.properties['cover']`.
5. **Copy Link to Block**:
   - "Copy link to block" added to block handle context menu (`orbit://note#<slug>`).
6. **Smart URL Paste**:
   - Auto-detects URL in clipboard and wraps selected text into `[text](url)`.
7. **Canvas Section / Divider**:
   - Milanote-style `'section'` element with uppercase title, horizontal divider line, and direct text editing.
8. **Canvas Color Swatch**:
   - `'swatch'` card element with top color fill and bottom hex label; one-click "Copy HEX code" to clipboard.
9. **Canvas Lock / Unlock**:
   - Protect elements from accidental moves/resizes; lock badge displayed; unlockable via selection.
10. **Canvas Navigation Controls**:
    - Zoom out, 100% reset, Zoom in, Fit all content, and Fit selection (`filter_center_focus`).
11. **Nested Canvas Visual Identity**:
    - 'CANVAS BOARD' badge and board icon for nested canvas object references.
12. **Canvas Presentation Mode**:
    - Clean distraction-free view hiding toolbar with floating 'Exit presentation' chip; retains pan/zoom/nav.
13. **Canvas Breadcrumbs**:
    - Top breadcrumb navigation path for nested canvases with click-to-navigate ancestor links.
14. **Manual Task Order & View Duplication**:
    - Manual task sorting with `ReorderableListView` drag-and-drop.
    - "Duplicate current view" button to duplicate task view tabs with custom filter, sort, and property states.
15. **Slash Command Recents**:
    - Tracks recent slash commands and presents a "RECENT" section at the top of the slash menu.

## Obsidian-Style Bottom-Left Vault Switching & Help — 2026-09-12

Delivered Obsidian-style vault switcher and navigation controls at the bottom-left of the explorer sidebar matching Obsidian's signature layout:

1. **Bottom-Left Footer Bar**:
   - Pinned at the bottom of the explorer sidebar (`_buildVaultSwitcherFooter`) with a subtle top divider border (`colors.divider`).
   - Left side: Up/down unfold chevron icon (`Icons.unfold_more` `↕`) and current vault name (`c.repository.name`) with tooltip showing object count and switch prompt. Clicking opens the vault switcher dialog.
   - Right side: Quick-access Help button (`Icons.help_outline`) and Settings button (`Icons.settings_outlined`).
   - Responsive: Rendered both in docked desktop sidebar and mobile drawer explorer.
2. **Help & Shortcuts Dialog**:
   - Clean `OrbitDialog` displaying essential keyboard shortcuts (`Ctrl+P`, `Ctrl+B`, `Ctrl+Tab`, `Ctrl+Shift+T`), canvas gestures, and Markdown/callout shortcuts.
3. **Structured Vault Switcher Modal**:
   - Refined `Your Vaults` dialog with clear section dividers and headers:
     - `ACTIONS`: New Vault and Open Folder as Vault.
     - `YOUR VAULTS`: List of recent local vaults with active checkmark badge.
     - `MANAGE CURRENT VAULT`: Rename current vault and Close vault.
4. **Header Clean-Up**:
   - Avoids duplicate vault switcher buttons when the explorer sidebar is open, while keeping the fallback button when the sidebar is collapsed.

## Desktop Tab Ergonomics, Live Note Statistics, Canvas Duplicate & Alignment — 2026-09-12

Delivered a focused Gemini-safe quality-of-life ergonomics batch:

1. **Desktop Tab Ergonomics**:
   - Middle mouse click on a tab closes that specific tab immediately.
   - Right-click context menu on tabs with:
     - `Close Tab`
     - `Close Other Tabs`
     - `Close Tabs to the Right`
     - `Copy Reference` (`[[Title]]`)
     - `Reveal in File Explorer`
   - Dirty-draft protection respected during multi-tab closures (`c.flush(id)` before closing).
   - Active split panes respected when closing secondary tabs.
   - Enlarged close icon hit target (28x28px with 4px internal padding) for comfortable desktop mouse targeting.

2. **Live Note Statistics**:
   - Real-time word, character, and estimated reading time statistics (`X words · Y characters · Z min read`) in the bottom status bar when a note is active.
   - Updates live as the user types without triggering full shell rebuilds.
   - Automatically hidden when the active object is a canvas, task board, PDF, or file.

3. **Reveal in File Explorer**:
   - Native OS file explorer integration: opens folder with target file highlighted via `openAttachment(..., reveal: true)` (`explorer.exe /select,"<path>"` on Windows).
   - Available on notes, folders, attachments, and files in the sidebar explorer actions menu and tab context menu.

4. **Canvas Quick Duplicate (`Ctrl+D`)**:
   - Instant duplicate of selected element(s) offset by `+20, +20` world units.
   - Places the newly duplicated element(s) in active selection.
   - References the same underlying universal object (note/task) without creating duplicate notes.
   - Encapsulated in a single undo transaction (`_history.begin()` / `_commit()`).

5. **Canvas Multi-Selection Alignment**:
   - Align 2 or more selected elements horizontally or vertically:
     - `Align Left`, `Horizontal Center`, `Align Right`
     - `Align Top`, `Vertical Middle`, `Align Bottom`
   - Accessible via both the canvas top toolbar alignment menu and the canvas right-click context menu.
   - Maintains exact element dimensions, shifting only coordinates.
   - Skips locked elements and bundles alignment into a single undo step.

6. **Empty-Canvas Context Menu**:
   - Compact right-click context menu on empty canvas space:
     - `Add Text` (placed at click location)
     - `Add Sticky` (placed at click location)
     - `Add Section` (placed at click location)
     - `Add Color Swatch` (placed at click location)
     - `Paste`
     - `Fit All`
     - `Fit Selection` (when elements are selected)
     - `100% Zoom`
   - Accurately converts screen click coordinates to world coordinates according to current camera zoom and pan.

### Validation Evidence
- Unit and widget tests added in `test/product_polish_test.dart` and passing:
  - Tab close actions (`closeOtherTabs`, `closeTabsToTheRight`), draft preservation, middle-click, and context menu.
  - Live note statistics display and dynamic recalculation during body edits.
  - Canvas empty-space right click, element insertion, and multi-selection alignment.
- Full test suite: 221 tests passed (0 failures).
- Zero analyzer warnings (`flutter analyze`: "No issues found!").
- Formatting check passed (`dart format --output=none --set-exit-if-changed lib test`).
- Windows release build compiled cleanly: `build\windows\x64\runner\Release\orbit_note.exe`.
- Deployed binary to `C:\Users\iax\Desktop\Orbit Note Windows App` and generated archive `C:\Users\iax\Desktop\OrbitNote-Windows-x64.zip`.

## Second Productivity & Polish Batch — 2026-09-12

Delivered the second focused Gemini-safe quality-of-life batch:

1. **Pinned Tabs & Reordering Ergonomics**:
   - Tab context menu includes `Pin Tab` and `Unpin Tab` actions.
   - Pinned tabs are partitioned to the leftmost side of the tab strip with a subtle vertical divider.
   - Pinned tabs show a subtle pin icon (`push_pin_rounded`, 11px) with title text.
   - Preserved during bulk closing operations (`Close Other Tabs`, `Close Tabs to the Right`).
   - Drag-to-reorder respects partition boundary clamping (unpinned tabs cannot be dragged into pinned region, and pinned tabs stay within pinned range).

2. **Reopen Closed Tab (`Ctrl+Shift+T`)**:
   - `reopenClosedTab()` reopens the most recently closed tab from a bounded 20-entry session stack (`session.closedTabs`).
   - Accessible via keyboard shortcut `Ctrl+Shift+T`, tab strip context menu, and command palette.
   - Skips deleted or missing objects gracefully.

3. **Universal Search Context Snippets**:
   - `extractSearchSnippet()` extracts context around matched search queries across note bodies, canvas elements (both data and JSON bodies), and properties.
   - Markdown noise stripped via `cleanMarkdownNoise()` so raw syntax (`#`, `**`, `[[`, `]]`, `` ` ``) is removed.
   - Matches are highlighted in the search popup and command palette with bold styling and subtle tag indicators (`Canvas element`, `Property: ...`).

4. **Notes Explorer Multi-Selection & Tree Keyboard Navigation**:
   - Multi-selection support: standard click to select single note, `Ctrl`/`Cmd`+click to toggle items, `Shift`+click for range selection, and `Ctrl+A` to select all visible notes in the tree.
   - Full keyboard navigation: `Up`/`Down` arrows to navigate entries with automatic scrolling, `Enter` to open notes or toggle folder expansion, `Right`/`Left` arrows to expand/collapse folders, `Space` to toggle selection.
   - Floating batch actions bar at the bottom with count indicator, `Move to folder`, `Copy references`, and `Move to Trash` (with confirmation showing exact count).

5. **Canvas Distribute Evenly**:
   - Distribute 3 or more selected canvas elements horizontally (`distributeH`) or vertically (`distributeV`).
   - Computes equal spacing between elements based on bounding boxes while preserving leftmost/rightmost or topmost/bottommost anchors.
   - Respects element locks, operates as a single undo/redo transaction, and is accessible from the canvas alignment toolbar menu and context menu.

6. **Canvas Minimap**:
   - Floating 160x110 minimap card positioned in the bottom-right corner above the zoom controls.
   - Implemented via `CanvasMinimapPainter` depicting element bounds and viewport rectangle.
   - Clicking or dragging inside the minimap centers the canvas camera to the clicked location.
   - Minimap toggle button (`map_outlined`) in the zoom control bar; automatically hidden in presentation mode.

7. **Canvas Alignment / Snap Guides**:
   - Visual dashed guidelines rendered temporarily during element movement when edges or centers align with candidate elements within a 6-pixel threshold.
   - Transient visual guides and coordinate snapping; pressing `Alt` bypasses snapping.
   - Zero JSON schema persistence (strictly runtime visual helper).

8. **Daily Note ("Open Today's Note")**:
   - Command palette and Home quick action to open today's daily note.
   - Creates or navigates to an ordinary note titled with `YYYY-MM-DD`, formatted with a clean `# Weekday, Month D, YYYY` header, and marked with a `dailyDate` property.
   - Idempotent: reopens the existing note if one already exists for today.

9. **Navigation History (Back / Forward)**:
   - Browser-style navigation stack tracking opened objects with `navigateBack()` and `navigateForward()`.
   - Shortcuts `Alt+Left` and `Alt+Right` and top-bar back/forward chevron buttons.
   - Deduplicates consecutive history entries and maintains a bounded 50-entry stack.

10. **Home Local Dashboard V1**:
    - Enhanced home dashboard using existing local models without remote dependencies:
      - Quick Actions: `Open Today's Note`, `New Note`, `New Canvas`, `Search`.
      - Today's Tasks: Displays due today and overdue tasks with direct checkbox completion.
      - Upcoming Events & Deadlines: Lists upcoming calendar items and deadline tasks.
      - Recent Objects: 4-column cards showing recently viewed notes, canvases, and files.
      - Continue Reading: Highlights last read PDF with page progress and one-click resumption.

### Validation Evidence (Batch 2)
- Unit and widget tests in `test/product_polish_batch2_test.dart` (16 passing tests) covering:
  - Tab pinning, unpinning, repartitioning, drag clamping, and preservation during bulk closures.
  - Reopen closed tab stack behavior and deleted object handling.
  - Navigation history forward/backward traversal.
  - Search snippet extraction across note bodies, canvas text, and properties.
  - Daily note idempotency, dated title, and header format.
  - Canvas horizontal and vertical equal-gap distribution math.
  - Canvas minimap painter bounds calculation and guide line equality.
  - Home dashboard task categorization (today, overdue, upcoming).
- Full test suite: **237 tests passed (0 failures)**.
- Static analysis: **0 issues found** (`flutter analyze`).
- Code formatting: zero-change format check passed (`dart format --output=none --set-exit-if-changed lib test`).
- Windows release executable compiled: `build\windows\x64\runner\Release\orbit_note.exe`.
- Deployed executable and assets to `C:\Users\iax\Desktop\Orbit Note Windows App` and generated archive `C:\Users\iax\Desktop\OrbitNote-Windows-x64.zip`.


## Visual PDF reading continuation — 2026-09-12

Owner requested images/tables in comfort mode and additional PDF reading tools.
Implemented a live-page visual comfort mode with conservative blank-side-margin
fitting; text-only reading remains optional. Added full-page/width/content fitting,
zoom presets and focused-reader keyboard shortcuts. Preserves existing PDF forms,
research tools and unrelated work. No architecture/storage change.

Targeted regressions pass for an image/table fixture, blank/edge pixel bounds,
mode switching, zoom and fitting shortcuts, native form taps and filled-copy readback.
The phone-sized screenshot was inspected with image and table visible. Validation:
237 tests passed; flutter analyze clean; formatting and zero-change check passed
for lib/test/tool (133 files). Windows release build passed in 42.4 seconds:
`build/windows/x64/runner/Release/orbit_note.exe`. Logs are
`.local/pdf-visual-reading-tests.log` and `.local/pdf-visual-reading-build.log`.
No physical phone validation or interactive Windows smoke launch was performed.
Next: physical phone acceptance,
then precise highlight-region navigation; full Acrobat parity is not claimed.

## Productivity, Project Management & University Workflows Pass — 2026-09-12

Delivered a comprehensive productivity, project management, and university workflow pass based strictly on Orbit's core invariant: **"CREATE ONCE. VIEW ANYWHERE."**

1. **Unified Folder & Project System**:
   - Folders in the unified Explorer tree now contain Notes (`orbit.note`), Canvases (`orbit.canvas`), Saved Views (`orbit.view`), Attachments (`orbit.file`), and subfolders.
   - Drag-and-drop support: drag Notes, Canvases, Saved Views, or Files directly into folders with instant path update.
   - Rich Folder Context Menu with actions:
     - `New Note`
     - `New Canvas`
     - `New Task List`
     - `New Board` (defaults to university preset)
     - `New Calendar`
     - `New Timeline`
     - `New folder` / `New subfolder`
     - `Rename folder`
     - `Move folder…`
     - `Reveal in File Explorer`
     - `Archive folder`
     - `Delete folder`
   - Non-destructive Folder Archiving: `isArchivedFolder(folder)`, `archiveFolder(folder)`, `restoreFolder(folder)` with collapsible "Archived" section in explorer sidebar; leaves underlying files intact.

2. **Saved Views (`orbit.view`)**:
   - Universal Object storing view configuration (`viewType`: `tasks`, `board`, `calendar`, `timeline`; `folder`, `scope`, `preset`) that scopes and views underlying Universal Objects without data duplication.
   - `SavedViewHost` widget with:
     - Icon and editable title bar.
     - Folder scope chip.
     - View switcher tabs (`List`, `Board`, `Calendar`, `Timeline`).
     - Kanban preset dropdown selector (`Universal`, `Software`, `Game Dev`, `University`).
     - Real-time Course / Project progress bar (`X / Y complete · Z%`).
     - Duplicate view (duplicates view configuration only, zero task duplication) and Trash view.

3. **Kanban Board Enhancements**:
   - Customizable presets via `KanbanPreset`:
     - **Universal**: Backlog, To Do, In Progress, Done
     - **Software Dev**: Backlog, Ready, In Dev, In Review, Done
     - **Game Dev**: Concept, Asset Production, In Dev, Testing, Done
     - **University Course**: Syllabus / Topics, Assignments, Exam Prep, Review, Done
   - Smooth drag-and-drop (`Draggable` / `DragTarget`) between columns updating task status and completion dynamically.
   - Inline sequential quick add (`+ Add task`) per column with instant focus.
   - Rich card metadata badges: estimate chip, category chip, subtle priority chip, blocker warning chip (`🔒 Blocked`), and subtask checklist completion ratio (`X / Y subtasks`).
   - Side task preview peek panel (`_peekTaskId`) for immediate in-place inspection and editing.
   - Full `TaskDetail` editing: added form fields for `status`, `estimate`, `category`, and `blockedBy`.

4. **Timeline View (`TimelineView`)**:
   - Chronological month/year timeline aggregating `orbit.event` and dated `orbit.task` Universal Objects.
   - Scoped filtering by folder or course/project.
   - In-view live search and interactive task completion toggle.

5. **Scoped Calendar View**:
   - `CalendarView` accepts `folderFilter` and `scope` to scope events and due tasks strictly to the active folder/project/course.

### Validation Evidence
- Comprehensive unit and widget test suite in `test/workflow_project_management_test.dart` (7/7 passing tests):
  - Invariant verification: single task shared across List, Board, Calendar, and Timeline without cloning data.
  - Non-destructive folder archiving and restoration.
  - Saved view creation and configuration duplication without task cloning.
  - `moveObjectToFolder` updates location for notes, canvases, and views.
  - Kanban presets validation (`universal`, `software`, `gamedev`, `university`).
  - `SavedViewHost` header, switcher, and viewType transitions.
  - `SavedViewHost` course progress calculation and percentage display.
- Full test suite: **255/255 tests passed (0 failures)** across all test files in the repository.
- Static analysis: **0 issues found** (`flutter analyze`).
- Code formatting: 139 files checked with 0 changes (`dart format --output=none --set-exit-if-changed lib test`).
- Windows 64-bit release build compiled: `build\windows\x64\runner\Release\orbit_note.exe`.
- Deployed executable and assets to `C:\Users\iax\Desktop\Orbit Note Windows App` and generated archive `C:\Users\iax\Desktop\OrbitNote-Windows-x64.zip`.
- Android release APK compiled via OpenJDK 17 and Android SDK Platform 34: `build\app\outputs\flutter-apk\app-release.apk` (93.8MB) and copied to `C:\Users\iax\Desktop\OrbitNote-release.apk`.

