# Current task — PDF review workspace, 2026-09-14

Owner request: add useful Acrobat-inspired work tools while preserving Orbit's
local-first knowledge model. Scope: FILE-04/05/11/12/13; Google remains paused.
Required references: [PDF/research spec](../features/attachments-and-research.md),
[implemented formats](../architecture/implemented-formats.md), ADRs 0013/0014/0015,
and the existing application save/recovery contract. Preserve prior editor work.

Implemented batch:

- Page comments, including scans/diagrams with no selectable text, create linkable
  notes and visible page markers. A failed create keeps the typed comment for retry.
- Edit review notes from the reader; change markup color/type and resolve/reopen.
  The editor explicitly edits the same note's Markdown body, with normal save/history.
  Concurrent edits/source changes reject stale dialogs; failed saves retain drafts.
- Review panel filters text, open/resolved, markup type and current page; sorts by
  page or newest. Filters survive closing/reopening the panel in the same session.
- Copy/export the filtered review as Markdown or save it as an ordinary linked note
  beside the PDF. Summary links use UUIDs for both annotations and source pages;
  stale source versions are labelled. Large summaries are bounded; source is retained.
- Hide/show review markup without deleting notes. Unknown properties/region fields,
  source checksums and original PDF bytes remain intact. No package/schema migration.

Validation resumed 2026-09-15 after the prior usage-limit interruption. The moved
Flutter SDK was located in the local backup and the ignored build helper repaired;
Flutter remains 3.44.8 / Dart 3.12.2, with no dependency upgrade.
`dart format lib test tool` and the no-change format check passed (218 files).
`flutter analyze` reported no issues (22.6s). All **569 tests passed** (60s),
including seven new review regressions for persistence, stale/failure safety,
filtering, editing, source-linked summaries and page-comment retry. The existing
real-PDF rendering/form/comfort and Rich editor regressions also pass. Ten targeted
reader/review tests passed with desktop screenshot capture on 2026-09-14; the
result was inspected. Logs: `.local/pdf-review-*.log`; visual artifact:
`work/ui/pdf-highlights.png`.

`flutter build windows --release` succeeded (60.3s). Executable:
`build/windows/x64/runner/Release/orbit_note.exe`. A five-second startup smoke check
confirmed the rebuilt process remained running and responding; that test instance
was then closed. Evidence: `.local/pdf-review-windows-build.log` and
`.local/pdf-review-smoke.json`. `git diff --check` passed. No full native interactive
review session, physical phone test or OS Save As dialog test was performed.

Boundaries: Orbit review metadata is not written into the original PDF. This batch
does not implement annotated-PDF export, OCR, redaction, signatures, arbitrary PDF
text editing, or native comment import. Page markers use a bounded automatic grid,
not free placement/dragging. Real-phone and OS Save As dialog acceptance is pending.

Next suggested task: export a separate standards-compatible annotated PDF with
round-trip tests in an independent reader, preserving originals and version guards.

# Previous task — Restore the math catalog and stabilize direct editing, 2026-09-14

Owner correction: the reduced palette and unstable editing were not acceptable.
"GeoGebra-like" meant typing into equations naturally, not introducing a solver
or a different product UI. Keep the original searchable LaTeX table, support
editing values in place, and keep the equation visible. Google remains paused.
Required references remain the editing specification, ADR 0011 and agent workflow
linked in the previous pass below. Preserve all unrelated work.

Implemented correction:

- The original **1,473-entry** searchable/category-filtered table is shared by the
  direct editor and Advanced editor. Symbols & templates opens it next to the
  equation; it stays open while inserting entries or editing values. New equations
  open it immediately. Escape/Close dismiss it without deleting the equation.
- The equation and controls keep their positions when fields focus or the table
  opens. The table anchors above/below the equation without covering it and follows
  document scrolling. Fields no longer acquire separate input-box decorations.
- Symbol insertion restores the actual caret instead of jumping to the end.
  Registry-backed standalone symbols (including arrows) remain editable glyphs.
  Exact command matching avoids misclassifying `\leftarrow` as a scalable delimiter.
- Backspace in an empty fraction half retains the other half; empty root degrees
  and script/limit arguments remove only that structure. Nonempty values are kept.
- Ctrl/Cmd+A selects the whole equation; copy/cut/paste/delete and replacement
  typing operate on that selection. Cut waits for successful clipboard copy;
  clipboard failure leaves the equation intact. Stale asynchronous clipboard work
  cannot overwrite a changed equation. Empty equations retain an editable slot.

Same source-span projection, Markdown durability and shared undo; no new package,
storage format, schema, migration or ADR. Arbitrary partial selection spanning
several equation parts remains unfinished. Complex TeX/matrices retain the existing
Advanced/grid editor and safe renderer fallback; this is not full Word parity.

Validation (2026-09-14): `dart format lib test tool` and no-change format check
passed (216 files); `flutter analyze` reported no issues (6.9s); all **562 tests
passed** (41s), including eight new correction regressions. Coverage includes the
full table remaining open/clear of the equation, insertion caret, arrow glyphs,
empty-argument preservation, whole selection/delete/cut/paste and clipboard-failure
safety. Existing Markdown round-trip, shared undo and narrow-layout tests pass.
The captured desktop catalog view was visually inspected. `git diff --check` passed.

`flutter build windows --release` succeeded (48.7s). Executable:
`build/windows/x64/runner/Release/orbit_note.exe`. The rebuilt process stayed alive
and responding for a five-second startup smoke check, then was closed. Clipboard
behavior was checked through Flutter's mocked platform channel, not a manual native
copy/paste session. Real-phone typing and native interactive acceptance remain
unverified. Logs: `.local/math-correction-*.log` and `.local/math-correction-smoke.json`;
screenshot: `work/ui/math-catalog-rich.png`. These are ignored local artifacts.

Next suggested task (do not start automatically): source-preserving partial
selection across equation structures, including Shift+arrow and replacement undo.

# Previous pass — Direct rich math editing, 2026-09-14

Owner direction: pause Google work; make equations editable directly in Rich
Notes, with a Word/GeoGebra-style input experience. Preserve all existing cloud
and unrelated work. Scope: EDT-03/04/06/09/12/15. Required references:
[editing specification](../features/markdown-and-editing.md),
[source-preserving projection](../adr/0011-source-preserving-rich-markdown.md),
and [workflow](../development/agent-workflow.md).

Delivered and validated:

- One editable expression replaces the duplicated renderer/slot forms. Fractions,
  nested fractions, roots/degrees, powers/subscripts and operator limits edit in place.
- `/`, `^`, `_` create structures at the caret/selection; Tab/Shift+Tab and arrows
  navigate slots. Common symbols insert at the remembered caret. New inline/block
  equations immediately focus a selectable placeholder, without opening Studio.
- Exact source spans feed the existing note callback and shared history. Unbraced
  arguments gain braces only on edit; command spellings and unrelated Markdown stay
  intact. Empty inline equations retain an editable placeholder. Newly edited inline
  boundary whitespace is trimmed to retain Markdown's equation delimiter grammar.
- Complex environments/scalable delimiters retain the existing renderer, grid
  editor where supported, and Advanced equation editor/full symbol catalog.

No new dependencies, storage schema, migration, remote service or ADR. This is a
bounded projection refinement, not full Word or GeoGebra parity. Cross-structure
native selection/deletion, exact mathematical typesetting in every editable slot,
and direct editing of arbitrary TeX/matrix environments remain limitations. There
is no symbolic solver/plotter; ordinary equation values are editable offline.

Next suggested task (do not start automatically): keyboard selection/removal across
equation structures with source-preserving undo and direct matrix cell editing.

Validation (2026-09-14): `dart format lib test tool` and the no-change format check
passed (215 files); `flutter analyze` reported no issues (7.4s); all **554 tests
passed** (44s), including 21 added math tests. They cover nested/source-span edits,
command boundary safety, empty inline slots, rapid events/IME, keyboard navigation,
symbol menu focus, direct insertion, cross-mode undo and Markdown reopen. Existing
render-only test assertions now check the editable component in Rich and retain
the original renderer assertions in Read. Desktop/narrow viewport visual checks
passed, including larger text; a rendered screenshot was inspected locally.

`flutter build windows --release` succeeded (50.8s). Executable:
`build/windows/x64/runner/Release/orbit_note.exe`. Its process stayed running and
responding for the five-second startup smoke check, then was closed. Native pen,
real-phone typing and a full interactive Windows acceptance session were not
performed. Logs: `.local/direct-math-*.log` and `.local/direct-math-smoke.json`;
visual evidence: `work/ui/rich-lecture.png`. These are local ignored artifacts.

# Paused by owner — Google account and Drive milestone, 2026-09-13

Owner prompt: attachment `5fdf20f6-ee67-477c-b3f7-99c8fd9e3794/pasted-text.txt`.
Continue the existing provider-neutral engine; Windows and Android first.
Account authorization, secure restoration, quota UI, root preparation and Vault
discovery are implemented. **The overall milestone is still incomplete**: Drive
conditional publication, Vault binding/upload/download and automatic sync remain.
See [audit, delivery map and validation](../planning/google-account-milestone-2026-09-13.md)
and [developer setup](../development/google-drive-sync-setup.md).
Do not advertise cloud synchronization or set conditional-publication capability
until the transfer safety contract is proven. Preserve earlier work below.

2026-09-14 account-isolation follow-up: bind full Drive operations and listed
Vaults to the initiating Google account, revalidate selected folder ownership,
and serialize device-local root preparation. Six new failure/concurrency tests
cover these boundaries. Registration remains unfinished: the owner declined use
of their personal email as public support contact and the pending policy
acceptance. Do not infer permission from a generic request to continue.

2026-09-14 release follow-up: Windows/Android release jobs now validate and embed
platform Google app configuration. A missing client ID fails a requested Google
account preview build; local-only remains an explicit mode. Release notes explain
that Vault transfers remain unfinished. Public support address clarification is
pending; no Google registration, policy consent or personal contact was submitted.

# Previous task — Runtime hardening, 2026-09-13

Owner prompt: verify and repair TaskDetail, universal folder operations, connector
endpoints, editor state/source preservation and navigation/search edge cases.
See [audit and evidence](../planning/runtime-audit-2026-09-13.md).
Delivered: 463 tests passed, analyzer clean, 189 files format-clean, Windows release
built in 45.8 seconds and passed a five-second process startup smoke check.
Cloud implementation is explicitly excluded from this task. Preserve all earlier
work below. Suggested next task: browser-safe transactional folder commands;
do not start it without a new task instruction.

# Previous task — M6 local-first cloud sync

Continue [the cloud implementation task](cloud-sync.md). The full owner prompt is
now available. Safety/reconciliation foundations and the native repository replica
adapter are implemented; Google Drive, auth and cloud UI remain unfinished. Preserve the
completed feature work below. See [cloud status](../features/cloud-sync.md).

# Current task — Universal Object Properties, Typed Metadata Editor, Relations Explorer & Release v0.2.2 (ORG-02, ORG-03, ORG-08)

Status: delivered and validated, 2026-09-13.

Delivered Universal Object typed properties management, interactive in-place metadata editing, Add Property modal with live validation (number, date, url, boolean, tags), and a comprehensive Relations & References Explorer (inbound backlinks, outbound wiki-link references, and contextual siblings) inside the Context Inspector (**ORG-02, ORG-03, ORG-08**), along with release packaging and version bump to `v0.2.2` under the core Orbit Note invariant: "ONE STABLE UNIVERSAL OBJECT IDENTITY".

### Delivered Capabilities
1. **WorkspaceController Relations & Property Mutations (`lib/app/workspace_controller.dart`)**:
   - `outboundLinks(String id)`: parses wiki-links from the object's body, resolves candidates through `linkTargets` and `linkBindings`, and returns target `UniversalObject`s.
   - `relatedObjects(String id)`: context discovery finding objects sharing the same `project`, same `folder`, or common `tags`, capped at 10 items.
   - `updateProperty(String id, String key, dynamic value)`: immutable property updates via `edit(id, properties: {...})` and automatic local save debounce.
   - `removeProperty(String id, String key)`: removes user property while preserving schema integrity.
2. **Context Inspector & Typed Metadata Editor (`lib/features/workspace/object_inspector.dart`)**:
   - Identity & Header: Type icon, uppercase type badge, object title, UUID row with "Copy UUID" clipboard button, and formatted Created & Updated timestamps.
   - In-place Typed Property Editors:
     - Checkbox/Boolean: direct Switch toggle with instant feedback.
     - Number: numerical badge opening dialog with `num.tryParse` live validation.
     - Date: date badge opening Flutter date picker and formatting `YYYY-MM-DD`.
     - Tags: wrap of removable chips with `#tag` styling plus `+ Tag` chip to add new tags.
     - URL: clickable link with `Icons.open_in_new` launching URL via `url_launcher`, with edit button and url scheme validation.
     - Text / Other: string display with edit dialog.
     - Delete Property action: quick button on every property row.
   - Add Property Modal:
     - Name input with non-empty and collision validation against existing properties.
     - Type dropdown: Text, Number, Checkbox, Date, Tags, URL.
     - Dynamic value input tailored to selected type with live validation.
   - Relations & References Section:
     - Segmented tabs: `Backlinks (count)`, `Outbound (count)`, `Related (count)`.
     - Displays referencing and referenced objects via `ObjectRow`, with one-tap navigation `c.openObject(id)`.
     - Graceful empty states for each relation tab.
   - Actions: Rename Object button and Move to Trash button.
3. **Workspace Shell Integration (`lib/features/workspace/workspace_shell.dart`)**:
   - Replaced old minimal inspector with `ObjectInspector(controller: c, onRename: renameObject)`.
   - Expanded inspector sidebar width to 300px for optimal layout and breathing room.
4. **Validation Evidence**:
   - 522/522 tests passing across entire suite (`test/object_inspector_properties_test.dart` added covering all unit and widget behaviors).
   - 0 warnings in `flutter analyze`.
   - 100% format-clean across all 205 dart files.

# Previous task — Work & Study Focus Sessions with Honest Tracking, Local Summaries & Release v0.2.1 (CTX-04, CTX-05, CTX-06, CTX-07, CTX-11, CTX-12)

Status: delivered and validated, 2026-09-13.

Delivered dedicated Work, Study, and Reading Focus Sessions with honest active-time tracking, activity recording (notes opened/created, tasks completed), pause/resume recording controls, user-written continuation notes, local session summaries on Home, and Command Palette shortcuts (**CTX-04, CTX-05, CTX-06, CTX-07, CTX-11, CTX-12**), along with desktop packaging and version bump to `v0.2.1` under the core Orbit Note invariant: "CREATE ONCE. REFERENCE ANYWHERE."

### Delivered Capabilities
1. **Pure Dart Work Session Domain Model (`lib/domain/work_session.dart`)**:
   - `WorkSessionRecord`: models bounded sessions with `id`, `title`, `category` (`work`, `study`, `reading`, `general`), `startedAt`, `endedAt`, `isPaused`, `totalPausedDuration`, `notesOpened`, `notesCreated`, `tasksCompleted`, and `continuationNote`.
   - Honest elapsed active duration: computes active time minus accumulated paused intervals, **never claiming unrecorded focus time**.
   - Paused recording invariant (CTX-07): when a session is paused or ended, actions (`recordOpen`, `recordCreate`, `recordTaskCompleted`) strictly omit tracking.
   - Robust JSON roundtripping (`toJson`, `fromJson`) with defensive fallbacks.
2. **Session Lifecycle & Auto-Tracking in WorkspaceController (`lib/app/workspace_controller.dart`)**:
   - `startWorkSession({String? title, String category})`: initializes active session and syncs to session state.
   - `pauseWorkSession()` & `resumeWorkSession()`: pauses and resumes active interval, tracking pause timestamps and accumulating paused duration.
   - `setWorkSessionContinuationNote(String note)`: updates user continuation note.
   - `endWorkSession({String? continuationNote})`: closes active session, stores in `completedWorkSessions` (capped to 30), and persists layout.
   - Hooks:
     - `openObject`: tracks notes opened during active recording.
     - `create`: tracks objects created during active recording.
     - `edit`: detects task completion (`properties['completed'] == true`) and tracks task completions.
   - Guaranteed single initialization guard preventing concurrent microtask re-entry.
3. **Home Dashboard Focus Session Card (`lib/features/workspace/workspace_views.dart`)**:
   - `HomeView`: now a `ConsumerWidget` automatically reacting to controller state updates.
   - `_FocusSessionCard`:
     - **Active state**: displays category badge, status badge (`ACTIVE FOCUS` in emerald or `PAUSED` in amber), title, live tabular digital timer formatted as `MM:SS` or `H:MM:SS`, subtitle "Active time (paused excluded)", action buttons (Pause/Resume, Note, End session), stat badges for notes opened, created, and tasks completed, and italic continuation note preview.
     - **Idle state**: displays "FOCUS & WORK SESSIONS" header, "Start Focus Session" button with category selection dialog, and recent session summary displaying past active time, notes referenced, tasks completed, and continuation note reflection.
     - **Dialogs**: Start session dialog with category segmented button, continuation note editor dialog, and end session confirmation dialog summarizing session achievements.
4. **Command Palette Integration (`lib/features/workspace/command_palette.dart`)**:
   - Made `CommandPalette` a `ConsumerStatefulWidget` watching `workspaceProvider`.
   - Displays "Start focus session" when idle.
   - Displays "Pause focus session: <Title>" / "Resume focus session: <Title>" and "End focus session: <Title>" when active.
   - Guards `Navigator.pop` with `Navigator.canPop(context)` for test robustness.
5. **Release & Packaging**:
   - Bumped `pubspec.yaml` version to `0.2.1+12`.
   - Windows Release build compiled and packaged to `OrbitNote-Windows-x64.zip` (24,889,468 bytes).
   - Zero changes to cloud sync (`lib/application/sync/`, `lib/infrastructure/sync/`).

### Validation Evidence
- Dedicated unit and widget test suite in `test/work_session_test.dart` (5/5 passing tests).
- All continue writing, editor, and workspace UI test suites passing.
- Full repository test suite: **516/516 tests passed cleanly (0 failures)**.
- `dart format lib test` & `dart format --output=none --set-exit-if-changed lib test`: 100% formatted across all 203 files.
- `flutter analyze`: 0 issues found across entire codebase.
- Windows Release binary compiled in 65.8s with pinned Windows SDK 10.0.26100.0 (`build\windows\x64\runner\Release\orbit_note.exe`).
- Deployed executable to `C:\Users\iax\Desktop\Orbit Note Windows App` and created standalone distribution archive `C:\Users\iax\Desktop\OrbitNote-Windows-x64.zip`.

---

# Previous task — Continue Writing, Where Was I? & Note View State Restoration Hardening (EDT-15, CTX-10)

Status: delivered and validated, 2026-09-13.

Delivered note view state restoration hardening across note switches (`didUpdateWidget`) with safe clamping that never modifies document content, the `CONTINUE WRITING` hero resumption card in `HomeView`, the `Where was I:` recent navigation trail in `HomeView`, and `Continue writing` / `Continue reading` quick continuation shortcuts in `CommandPalette` (`Ctrl+P`) under the core Orbit Note invariant: "CREATE ONCE. REFERENCE ANYWHERE."

### Delivered Capabilities
1. **Note View State Restoration Hardening (`lib/features/notes/note_editor.dart`)**:
   - Hardened `didUpdateWidget` during note switching (`oldWidget.noteId != widget.noteId`):
     - Restores `_mode` (`rich`, `write`, `split`, `read`) from `widget.initialViewState['mode']`.
     - Restores `_splitRatio` clamped safely to `[0.2, 0.8]`.
     - Restores `_richState` heading collapse map and caret position from `widget.initialViewState['rich']`.
     - Restores `_body.selection` with `baseOffset` and `extentOffset` strictly clamped to `[0, _body.text.length]`.
     - Automatically falls back to clamped offsets if an external edit or sync change shortens a note, **never mutating document contents** to match stale view state.
     - Restores `_sourceScroll` and `_previewScroll` with post-frame layout-aware bounds clamping.
2. **`CONTINUE WRITING` Hero Card (`lib/features/workspace/workspace_views.dart`)**:
   - Queries the most recent note in the user's active session.
   - Extracts word count and active/saved mode badges (`Rich`, `Write`, `Split`, `Read`).
   - Generates a clean preview snippet stripped of Markdown heading, list, and formatting artifacts.
   - Provides a prominent `Resume writing` action button (`onPressed: () => c.openObject(recentNote.id)`).
   - De-duplicates against `Continue session` cards to prevent redundant elements.
3. **`Where was I:` Recent Navigation Trail (`lib/features/workspace/workspace_views.dart`)**:
   - Renders a horizontal breadcrumb trail of recently active objects with type-aware icons and titles.
   - Enables one-click resumption of recent work directly from the Home dashboard.
4. **Command Palette Quick Continuation (`lib/features/workspace/command_palette.dart`)**:
   - Public `CommandPalette` widget.
   - Provides `Continue writing: <Title>` and `Continue reading: <Title>` shortcuts when recent items are available, jumping straight into the note editor.
5. **Cloud Sync Guardrail**:
   - All cloud sync modules (`lib/application/sync/`, `lib/infrastructure/sync/`) remain completely untouched.

### Validation Evidence
- Dedicated unit and widget test suite in `test/continue_writing_test.dart` (4/4 passing tests).
- All related note editor and navigation test suites passing (20/20 tests across `notes_navigation_test.dart`, `note_find_replace_stats_test.dart`, `notes_editor_test.dart`, `note_editor_stats_test.dart`).
- Full repository test suite: **509/509 tests passed cleanly (0 failures)**.
- `dart format lib test` & `dart format --output=none --set-exit-if-changed lib test`: 100% formatted across all 201 files.
- `flutter analyze`: 0 issues found across entire codebase.
- Windows Release build compiled in 47.6s with pinned Windows SDK 10.0.26100.0 (`build\windows\x64\runner\Release\orbit_note.exe`).
- Deployed executable to `C:\Users\iax\Desktop\Orbit Note Windows App` and updated archive `C:\Users\iax\Desktop\OrbitNote-Windows-x64.zip` (24,872,804 bytes).

---

# Previous task — Selection-Scoped Find & Replace & Labelled Metrics (EDT-13)

Status: delivered and validated, 2026-09-13.

Delivered selection-scoped local find & replace, bidirectional match navigation with live match index indicator (`(X of Y)`), case sensitivity (`Aa`) and whole-word (`\bW\b`) search filters, scoped replacement engine (`Replace all in selection` strictly preserving text outside), and real-time scope-labelled document metrics with reading time estimates (`Selection: ... · Document: ...`) under the core Orbit Note invariant: "CREATE ONCE. REFERENCE ANYWHERE."

### Delivered Capabilities
1. **Selection-Scoped Search Engine (`lib/features/notes/note_editor.dart`)**:
   - `FindScope.document` vs `FindScope.selection`: restricts search boundaries, match counting, navigation, and single/all replacements strictly to the active selection range when enabled.
   - `_scopeStart` and `_scopeEnd`: preserves initial selection range even as find navigation moves the editor caret.
   - Smart Open Seeding: opening find with a short phrase selected seeds search query; multi-line selection activates `FindScope.selection` automatically.
   - Selection Scope Toggle: dedicated toolbar button (`Icons.select_all_rounded`, tooltip `'Find in selection · Alt+S'`) and dismissible scope badge (`In Selection`).
2. **Bidirectional Match Navigation & Filters (`lib/features/notes/note_editor.dart`)**:
   - Live Match Counter: displays `$_findCount ${_findCount == 1 ? 'match' : 'matches'}` and indexed indicator `($_currentMatchIndex of $_findCount)`.
   - Bidirectional Navigation: Previous Match (`Icons.arrow_upward_rounded`, `Shift+Enter`) and Next Match (`Icons.arrow_downward_rounded`, `Enter`).
   - Match Case Toggle: `Aa` button (`Alt+C`), filtering between case-sensitive and case-insensitive matching.
   - Whole Word Toggle: `\bW\b` button (`Alt+W`), filtering whole word tokens via word boundaries.
3. **Scoped Replacement Engine (`lib/features/notes/note_editor.dart`)**:
   - Single Replace: replaces active match and advances to next match within scope.
   - Replace All: replaces all occurrences in note (document scope) or strictly within `[_scopeStart, _scopeEnd]` (selection scope), preserving all text outside untouched.
   - Literal Replacement String Safety: uses `replaceAllMapped` to preserve exact literals (e.g. `$fruit`) without regex group backreference errors.
4. **Scope-Labelled Document Metrics & Reading Time (`lib/features/notes/note_editor.dart`)**:
   - Unselected State: `$words words · $chars characters · ~$readMinutes min read`.
   - Selected State: `Selection: $selWords of $words words ($selChars chars, $selReadTime) · Document: $words words ($chars characters, ~$readMinutes min read)`.
   - Real-time Selection Listener: `_recordSelection` ensures metrics update live on cursor movement and text selection without requiring document text mutation.
   - Reading Time Estimates: calculated based on standard 200 words-per-minute rate with `< 1 min read` for short fragments.
5. **Cloud Sync Guardrail**:
   - All cloud sync modules (`lib/application/sync/`, `lib/infrastructure/sync/`) remain completely untouched.

### Validation Evidence
- Dedicated unit and widget test suite in `test/note_find_replace_stats_test.dart` (9/9 passing tests).
- All related note editor and navigation test suites passing (31/31 tests).
- Full repository test suite: **505/505 tests passed cleanly (0 failures)**.
- `dart format lib test` & `dart format --output=none --set-exit-if-changed lib test`: 100% formatted across all 200 files.
- `flutter analyze`: 0 issues found across entire codebase.
- Windows Release build compiled in 62.6s with pinned Windows SDK 10.0.26100.0 (`build\windows\x64\runner\Release\orbit_note.exe`).
- Deployed executable to `C:\Users\iax\Desktop\Orbit Note Windows App` and updated archive `C:\Users\iax\Desktop\OrbitNote-Windows-x64.zip` (24,868,430 bytes).

---

# Previous task — Footnotes & Underline Formatting (EDT-12)

Status: delivered and validated, 2026-09-13.

Delivered portable Markdown Underline formatting (`<u>text</u>` and `<ins>text</ins>`), GitHub-Flavored Markdown Footnotes (`[^1]` inline reference badge and `[^1]: Definition` block), Underline format toolbar button (`Icons.format_underlined_rounded`), keyboard shortcut (`Ctrl+U`), auto-incrementing footnote insertion, rich text visual projection, and preview / read mode jump navigation with backlink return (`↩`) under the core Orbit Note invariant: "CREATE ONCE. REFERENCE ANYWHERE."

### Delivered Capabilities
1. **Portable Underline Formatting (`lib/features/notes/rich/note_underline.dart`)**:
   - `UnderlineInlineSyntax`: parses `<u>...</u>` HTML Markdown tags into `'u'` AST element nodes.
   - `InsInlineSyntax`: parses `<ins>...</ins>` HTML Markdown tags into `'u'` AST element nodes.
   - `UnderlineElementBuilder`: renders `'u'` elements with `TextDecoration.underline`, seamlessly combining with parent text decorations (such as strikethrough).
2. **Pure Dart Markdown Document Model (`lib/features/notes/rich/markdown_document.dart`)**:
   - Registered `<u>...</u>` and `<ins>...</ins>` in `InlineProjection._parse`, assigning `'underline'` style mark and tracking wrapper delimiters for ADR-0011 source-preserving editing.
   - Registered `<mark>...</mark>` in `InlineProjection._parse` assigning `'highlight'` mark.
   - Registered `[^...]` in `InlineProjection._parse` assigning `'footnote'` style mark.
   - Preserves footnote definitions (`[^1]: ...`) as literal raw blocks with lossless disk roundtripping.
3. **Rich Markdown Editor Integration (`lib/features/notes/rich/rich_markdown_editor.dart`)**:
   - `NoteFormatAction.underline`: wraps current selection with `<u>...</u>`.
   - `_StyledController.buildTextSpan`: live visual rendering of `underline` (combining with `strike` via `TextDecoration.combine`), and distinct superscript badge styling for footnote references in primary theme accent.
   - Keyboard shortcut: `Ctrl+U` toggles underline in rich text blocks.
   - Slash commands: `/underline` and `/footnote`.
   - `insertFootnote()`: automatically scans the document for existing footnote numbers, inserts next index `[^N]` at caret, and appends `\n\n[^N]: ` at document end.
4. **Note Format Toolbar & Editor Ergonomics (`note_format_toolbar.dart`, `note_editor.dart`)**:
   - Top format toolbar includes Underline button (`Icons.format_underlined_rounded`) with tooltip `'Underline · Ctrl+U'`.
   - Quick insert popup menu includes `'Underline'` and `'Footnote'`.
   - `Ctrl+U` keyboard shortcut supported across both Source (`_sourceKey`) and Rich (`CallbackShortcuts`) editor modes.
   - Footnote jump navigation: clicking footnote reference `¹` smoothly animates preview scroll to bottom definition; clicking `↩` backlink returns to top.
   - Nested Callouts: `MarkdownBody` in `CalloutBlock` now renders underlines inside callout cards.
5. **Cloud Sync Guardrail**:
   - All cloud sync modules (`lib/application/sync/`, `lib/infrastructure/sync/`) preserved completely untouched.

### Validation Evidence
- Dedicated unit and widget test suite in `test/note_footnotes_underline_test.dart` (11/11 passing tests).
- All callout and note test suites passing (60/60 tests).
- Full repository test suite: **474/474 tests passed cleanly (0 failures)**.
- `dart format lib test` & `dart format --output=none --set-exit-if-changed lib test`: 100% formatted across all 188 files.
- `flutter analyze`: 0 issues found across entire codebase.
- Windows Release build compiled in 42.1s with pinned Windows SDK 10.0.26100.0 (`build\windows\x64\runner\Release\orbit_note.exe`).
- Deployed executable to `C:\Users\iax\Desktop\Orbit Note Windows App` and updated archive `C:\Users\iax\Desktop\OrbitNote-Windows-x64.zip`.

---

# Previous task — Callout Side-Color Styling (EDT-12) & Markdown Yellow Highlighting (EDT-02)

Status: delivered and validated, 2026-09-13.

Delivered GitHub/Obsidian-style callout side-color styling (vivid Blue for `NOTE`, prominent Purple for `IMPORTANT`, emerald for `TIP`, amber for `WARNING`, rose for `CAUTION`), Markdown yellow text highlighting (`==highlighted text==` / `<mark>text</mark>`), interactive format toolbar controls, keyboard shortcut (`Ctrl+Shift+H`), rich visual inline rendering, and read/preview markdown rendering under the core Orbit Note invariant: "CREATE ONCE. REFERENCE ANYWHERE."

### Delivered Capabilities
1. **Prominent Callout Side-Color Styling (`lib/features/notes/rich/callout_block.dart`)**:
   - `CalloutType.note`: updated to vibrant Azure Blue (`Color(0xFF0284C7)`).
   - `CalloutType.important`: prominent vivid Purple (`Color(0xFFA855F7)`).
   - `CalloutType.tip` (Emerald `0xFF10B981`), `warning` (Warm amber `0xFFF59E0B`), `caution` (Rose `0xFFE57582`).
   - 4px vertical accent bar on the left edge with matching colored icon and category title.
   - Preserves academic numbering (`ParsedCallout.headerDisplay`) for university course notes.
2. **Markdown Read & Preview Callout Engine (`CalloutBlockSyntax`, `CalloutElementBuilder`)**:
   - `CalloutBlockSyntax`: Pure Markdown block syntax parsing standard `> [!TYPE]` callouts. Supports multiline bodies and prevents absorbing consecutive callouts.
   - `CalloutElementBuilder`: Renders stylized callout card container with 4px left accent bar, colored header, and nested `MarkdownBody` supporting nested formatting, inline code, and text highlights.
3. **Markdown Yellow Text Highlighting (`==text==` / `<mark>text</mark>`)**:
   - `lib/features/notes/rich/note_highlight.dart`:
     - `HighlightInlineSyntax`: matches `==([^=\n]+)==` and outputs `mark` AST element.
     - `MarkTagInlineSyntax`: matches `<mark>([^<\n]+)</mark>` for standard HTML markdown tags.
     - `HighlightElementBuilder`: Renders `<mark>` elements with soft yellow badge backgrounds (`0xFFFEF08A` in light mode, `0xFFEAB308` with alpha 0.35 in dark mode) and high-contrast text (`0xFF713F12` in light mode, `0xFFFDE047` in dark mode).
4. **Pure Dart Markdown Document Model (`lib/features/notes/rich/markdown_document.dart`)**:
   - Registered `('==', 'highlight')` in `InlineProjection._parse`.
   - Tracks highlight boundaries and styles alongside bold, italic, and code without mutating raw source markdown on disk.
5. **Rich Markdown Editor Integration (`lib/features/notes/rich/rich_markdown_editor.dart`)**:
   - `NoteFormatAction.highlight`: executes `wrap('==')` on text selection.
   - `_RichTextController.buildTextSpan`: live visual highlighting of `==...==` spans while typing in rich mode.
   - Keyboard shortcut: `Ctrl+Shift+H` toggles highlight in rich text blocks.
   - Slash command: `/highlight` wraps or inserts highlighted text.
6. **Note Format Toolbar & Editor Ergonomics (`note_format_toolbar.dart`, `note_editor.dart`)**:
   - Top format toolbar includes Highlight button (`Icons.highlight_rounded`) with tooltip `'Highlight · Ctrl+Shift+H'`.
   - Quick insert popup menu includes `'Highlight'`.
   - Source editor handles `Ctrl+Shift+H` across both `_sourceKey` and `CallbackShortcuts`.
7. **Cloud Sync Guardrail**:
   - All cloud sync and `lib/application/sync/` / `lib/infrastructure/sync/` files preserved completely untouched.

### Validation Evidence
- Unit and widget test suite in `test/note_callouts_highlight_test.dart` (10/10 passing tests).
- All callout and note test suites passing (49/49 tests across `callout_block_test.dart`, `university_study_workflow_test.dart`, `note_callouts_highlight_test.dart`, `notes_editing_test.dart`, `notes_editor_test.dart`, `notes_hover_test.dart`, `notes_navigation_test.dart`, `note_editor_stats_test.dart`).
- Full repository test suite: **446/446 tests passed cleanly (0 failures)**.
- `dart format lib test` & `dart format --output=none --set-exit-if-changed lib test`: 100% formatted across all 183 files.
- `flutter analyze`: 0 issues found across entire codebase.
- Windows Release build compiled in 56.2s with pinned Windows SDK 10.0.26100.0 (`build\windows\x64\runner\Release\orbit_note.exe`).
- Deployed executable to `C:\Users\iax\Desktop\Orbit Note Windows App` and updated archive `C:\Users\iax\Desktop\OrbitNote-Windows-x64.zip`.

---

# Current task — Canvas Element Grouping & Ungrouping (CAN-04, CAN-05)

Status: delivered and validated, 2026-09-13.

Delivered first-class Canvas element grouping and ungrouping (`group` / `ungroup`) with atomic reversible undo/redo, locked-member parent transform protection, visual group boundary and pill badge rendering, keyboard shortcuts (`Ctrl+G`, `Ctrl+Shift+G`), context menu actions, and Layer Manager integration under the core Orbit Note invariant: "CREATE ONCE. REFERENCE ANYWHERE."

### Delivered Capabilities
1. **Pure Dart Groups Domain Engine (`lib/canvas/groups.dart`)**:
   - Zero Flutter dependencies: fully decoupled domain module for placement spatial organization.
   - `getGroupMembers(scene, groupId)`: queries all active renderable elements in a group.
   - `getAllGroupIds(scene)`: finds all unique active group IDs across the canvas.
   - `calculateGroupBounds(scene, groupId)`: computes accurate union bounding box enclosing all members.
   - `isGroupLocked(scene, groupId)`: checks if any member in the group is locked.
   - `groupElements(scene, ids, ...)`: generates updated elements with a shared unique `groupId` (requiring $\ge 2$ elements).
   - `ungroupElements(scene, ids)`: clears `groupId` from all members of target groups.
   - `duplicateGroupElements(scene, groupId, idGenerator, ...)`: clones group members with fresh IDs and binds them under a fresh shared `groupId`.
   - `isEntireGroupSelected(scene, groupId, selection)`: verifies selection containment.
2. **First-Class Group Identity on CanvasElement (`lib/canvas/scene.dart`)**:
   - Added `groupId` getter to `CanvasElement`.
   - Guaranteed clean JSON roundtripping and persistence without modifying referenced knowledge objects.
3. **Visual Group Boundary & Badge Painting (`lib/features/canvas/canvas_painter.dart`)**:
   - When any element of a group is selected, painter renders a subtle dashed bounding outline enclosing the group's union bounds.
   - Renders a stylish "GROUP" pill badge at the top-left of the group boundary.
   - Added `_drawDashedRect` with proper zoom-adaptive dash and gap metrics.
4. **Interactive Selection & Drag Coordination (`lib/features/canvas/canvas_editor.dart`)**:
   - Single-clicking an element belonging to a group automatically expands selection to include all members of the group.
   - Shift-clicking toggles selection of the entire group.
   - Moving any element of an unlocked group translates all group members together in a single atomic undoable transaction.
5. **Locked Member Protection Guard (`lib/features/canvas/canvas_editor.dart`)**:
   - Strict implementation of the invariant in `docs/features/spatial-boards.md` line 107: *"locked members prevent parent transforms"*.
   - If any member of a group is locked, dragging the group is aborted and displays the user notice: `'Unlock the group’s items before moving it.'`.
6. **Keyboard Shortcuts & Menu Controls (`lib/features/canvas/canvas_editor.dart`)**:
   - `Ctrl+G` (or `Cmd+G` on macOS): Groups $\ge 2$ selected elements with notification feedback.
   - `Ctrl+Shift+G` (or `Cmd+Shift+G` on macOS): Ungroups selected groups with notification feedback.
   - Top Toolbar: Added Group / Ungroup popup menu button (`Icons.workspaces_outlined`).
   - Context Menu: Added dedicated `GROUPING` section with "Group (Ctrl+G)" and "Ungroup (Ctrl+Shift+G)".
7. **Duplication, Deletion, and Layer Manager Integration (`lib/features/canvas/canvas_editor.dart`)**:
   - `_duplicate`: Duplicating grouped elements generates new element IDs and a fresh shared `groupId`.
   - `_delete`: Deleting a group removes all its members with full atomic undo/redo restoration.
   - Layer Manager dialog (`_showElementList`): Displays a highlighted `[Group]` tag next to grouped items.
8. **Cloud Sync Guardrail**:
   - All cloud sync modules (`lib/application/sync/`, `lib/infrastructure/sync/`) preserved completely untouched.

### Validation Evidence
- Comprehensive unit and widget test suite in `test/canvas_groups_test.dart` (13/13 passing tests).
- All canvas test suites: 96/96 passing tests across 7 suites.
- Full repository test suite: **436/436 tests passed cleanly (0 failures)**.
- `dart format lib test` & `dart format --output=none --set-exit-if-changed lib test`: 100% formatted across all 181 files.
- `flutter analyze`: 0 issues found across entire codebase.
- Windows Release build compiled in 69.5s with pinned Windows SDK 10.0.26100.0 (`build\windows\x64\runner\Release\orbit_note.exe`).
- Deployed executable to `C:\Users\iax\Desktop\Orbit Note Windows App` and updated archive `C:\Users\iax\Desktop\OrbitNote-Windows-x64.zip`.

---

# Current task — Canvas Export Engine (CAN-14, PORT-05, INK-10) & Paper Presets (INK-07)

Status: delivered and validated, 2026-09-13.

Delivered high-fidelity Canvas vector SVG export, multi-scale raster PNG export, JSON snapshot backup, cross-platform file saving and clipboard integration, along with Engineering Graph and Cornell Notes paper presets under the core Orbit Note invariant: "CREATE ONCE. REFERENCE ANYWHERE."

### Delivered Capabilities
1. **Pure Dart Vector SVG Generator (`lib/canvas/canvas_svg.dart`)**:
   - Zero Flutter dependencies: safe for headless servers, tests, CLI, and web workers.
   - Comprehensive renderer supporting all 16 element types: sticky notes, cards, containers, sections, swatches, columns, shapes (rectangles, rounded rects, pills, diamonds, ellipses, triangles, stars, octagons, cylinders, clouds), connectors (straight, cubic bezier spline, orthogonal Manhattan routing, arrow/dot/diamond markers, center text badges), ink strokes, broad translucent highlighter strokes, link badges, and images.
   - Preserves exact visual typography, colors, borders, drop shadows, and coordinate framing with customizable margin padding and background fills.
2. **Multi-Scale Raster PNG Export (`lib/features/canvas/canvas_painter.dart`)**:
   - Implemented `renderCanvasToPng(CanvasScene, bounds, ...)` using Flutter's native `ui.PictureRecorder` and `ui.Canvas`.
   - Supports 1x, 2x, and 3x device pixel ratio scale factors for crisp high-DPI presentations and prints.
   - Offers optional transparent background mode or matching paper background rendering.
   - Supports exporting either the entire canvas content or a targeted element subset.
3. **Cross-Platform Binary Export (`lib/platform/export_file.dart`, `export_file_native.dart`, `export_file_web.dart`)**:
   - Implemented `exportBinaryFile(Uint8List bytes, String fileName, {String? mimeType})`.
   - On Desktop (Windows/macOS/Linux), seamlessly detects default Downloads directory or workspace folder to write bytes safely.
   - On Web, initiates browser anchor blob downloads.
4. **Interactive Export Dialog & Context Menu Actions (`lib/features/canvas/canvas_editor.dart`)**:
   - Added Export button to canvas top toolbar (`Icons.file_download_outlined`).
   - Added `Export Selection...` and `Export Canvas...` actions to right-click context menus.
   - In-dialog controls: Scope toggle (Full Canvas vs Selection), Format toggle (PNG, SVG, JSON), Scale selector (1x, 2x, 3x for PNG), Transparent background toggle, Live dimensions and file name preview.
   - Actions: "Copy to Clipboard" (instant SVG or JSON text clipboard) and "Save File" (writes PNG, SVG, or JSON file with automatic notification banner).
5. **Engineering Graph & Cornell Notes Background Presets (INK-07) (`lib/features/canvas/canvas_painter.dart`, `lib/features/canvas/canvas_editor.dart`)**:
   - Added `graph`: Engineering graph paper with minor grid every 8px and prominent major grid every 32px.
   - Added `cornell`: Cornell Notes layout featuring ruled horizontal lines, vertical cue/recall divider at `x = 200`, horizontal summary divider at `y = 700`, and distinct labeled sections ("CUES / QUESTIONS", "NOTES", "SUMMARY").
   - Integrated into paper style menu alongside plain, dots, and ruled.
6. **Cloud Sync Guardrail**:
   - All cloud sync and `lib/application/sync/` / `lib/infrastructure/sync/` files preserved completely untouched.

### Validation Evidence
- Unit and widget test suite in `test/canvas_export_backgrounds_test.dart` (11/11 passing tests).
- Canvas test suites: 67/67 passing tests across 6 suites.
- Full repository test suite: **423/423 tests passed cleanly (0 failures)**.
- `dart format lib test` & `dart format --output=none --set-exit-if-changed lib test`: 100% formatted across all 179 files.
- `flutter analyze`: 0 issues found across entire codebase.
- Windows Release build compiled in 64.2s with pinned Windows SDK 10.0.26100.0 (`build\windows\x64\runner\Release\orbit_note.exe`).
- Deployed executable to `C:\Users\iax\Desktop\Orbit Note Windows App` and updated archive `C:\Users\iax\Desktop\OrbitNote-Windows-x64.zip`.

---

# Current task — Canvas Layer Manager & Stacking Order (CAN-08) & Freeform Highlighter (INK-03)

Status: delivered and validated, 2026-09-13.

Delivered canvas stacking order operations (`bringToFront`, `sendToBack`, `bringForward`, `sendBackward`), atomic undo/redo support via `CanvasHistory.reorder`, freeform highlighter drawing tool with broad translucent strokes, selection toolbar and context menu stacking controls, keyboard shortcuts (`Y`, `[`, `]`, `Shift+[`, `Shift+]`), and an interactive Layer Manager dialog with live visibility toggle, lock toggle, and reordering controls.

### Delivered Capabilities
1. **CanvasScene Stacking Order Operations (`lib/canvas/scene.dart`)**:
   - Implemented `orderOf(String id)` and `elementsInOrder` sorted by z-index.
   - Implemented `bringToFront(id)` (assigns incremented highest order) and `sendToBack(id)` (assigns decremented lowest order below all items).
   - Implemented `bringForward(id)` and `sendBackward(id)` (swaps z-order with immediate neighbor in the stack).
   - Ensured `toJson()` outputs elements sorted by stacking order, ensuring persistence across file saves and roundtrips.
2. **Atomic Reversible Undo/Redo (`lib/canvas/scene.dart`)**:
   - Implemented `CanvasHistory.reorder(Iterable<String> ids, void Function() mutate)` which captures pre-mutation element orders and commits a single reversible delta.
   - Full undo/redo restores exact z-ordering seamlessly.
3. **Freeform Highlighter Tool (`lib/canvas/scene.dart`, `lib/features/canvas/canvas_painter.dart`, `lib/features/canvas/canvas_editor.dart`)**:
   - Added `_Tool.highlighter` with shortcut `Y` and top toolbar button with `Icons.brush_outlined`.
   - Highlighter strokes use broad width (22.0px), semi-transparent alpha (`accent.withValues(alpha: 0.38)`), and rounded caps/joins.
   - Highlighter ink is persisted with `element.data['isHighlighter'] == true`.
   - Highlighter hit-testing and erase tolerance accounts for broad 22px stroke.
4. **Canvas Layer Manager & Stacking UI (`lib/features/canvas/canvas_editor.dart`)**:
   - Upgraded `_showElementList` into an interactive **Layers & Stacking Order** dialog (`Icons.layers_outlined`).
   - Displays elements from Front (top) to Back (bottom) with element type icons, color accents, and z-index indicators.
   - In-dialog controls: Up/Down arrow buttons (Bring Forward / Send Backward), Lock toggle (`Icons.lock`), Visibility toggle (`Icons.visibility`), and Focus on canvas button.
   - Dialog batch actions: "Bring to Front", "Send to Back", "Show All", "Unlock All".
   - Top action bar popup menu: `Bring to Front` (`Shift+]`), `Bring Forward` (`]`), `Send Backward` (`[`), `Send to Back` (`Shift+[`).
   - Right-click element context menu: Added `LAYER ORDER` section with Bring to Front, Bring Forward, Send Backward, Send to Back.
5. **Quality & Cloud Safety**:
   - Zero modifications to `lib/application/sync/` or `lib/infrastructure/sync/`.
   - All tests passing (including 11 new tests in `test/canvas_layers_highlighter_test.dart`).
   - `flutter analyze`: 0 issues found.
   - `dart format`: 100% formatted across repository.
   - Windows release binary compiled and deployed to `C:\Users\iax\Desktop\Orbit Note Windows App` and `OrbitNote-Windows-x64.zip`.

---

# Current task — Canvas Arrow & Connector Enhancements (CAN-04, CAN-05, CAN-07)

Status: delivered and validated, 2026-09-13.

Delivered comprehensive connector and arrow enhancements for linking sticky notes, cards, containers, and research items on Canvas with customizable stroke styles (solid, dashed, dotted), start/end markers (none, arrow, dot, diamond), routing engines (straight, cubic bezier spline, orthogonal Manhattan stepping), dynamic snap anchors, midpoint label editing, and connected element tracking under the core invariant: "CREATE ONCE. REFERENCE ANYWHERE."

### Delivered Capabilities
1. **Registered First-Class `'connector'` Element Type (`lib/canvas/scene.dart`)**:
   - Added `'connector'` to `canvasElementTypes`, instantly activating all dormant preset diagrams (Call Flow, Architecture, Game Loop, Process Tree, AI State Machine).
   - Added `startId`, `endId`, `strokeStyle`, `startMarker`, `endMarker`, `routing`, `startAnchor`, `endAnchor` getters to `CanvasElement`.
   - Updated `_effectiveBounds(element)` to accurately wrap the resolved spline/orthogonal geometry with 16px padding.
   - Updated `CanvasScene.remove(id)` to safely re-index connectors attached to deleted elements without leaving stale spatial index bounds.
   - Fixed `CanvasScene.contentBounds` to use `_effectiveBounds` so connectors in templates don't anchor content bounds to (0, 0).
2. **Pure Dart Connector Math & Anchor Engines (`lib/canvas/connectors.dart`, `lib/canvas/geometry.dart`)**:
   - `ConnectorAnchor` (`auto`, `top`, `bottom`, `left`, `right`): `getElementAnchors(bounds)` and `findClosestAnchor(bounds, target)`.
   - `ConnectorStyle` (`solid`, `dashed`, `dotted`), `ConnectorMarker` (`none`, `arrow`, `dot`, `diamond`), `ConnectorRouting` (`straight`, `curved`, `orthogonal`).
   - `resolveConnectorEndpoints(connector, scene)`: dynamically resolves perimeter docking points, generates cubic bezier control points for curved routing, and stepped 90-degree points for orthogonal routing.
   - `distanceToSegment(p, a, b)`: pure Euclidean distance calculation from point to line segment.
   - `hitTestConnector(connector, scene, point)`: tests cubic bezier spline segments (16 subdivisions), orthogonal stepped legs, straight segments, and text label pill bounding boxes.
3. **Interactive Snap Anchors & Vector Rendering (`lib/features/canvas/canvas_painter.dart`)**:
   - Live snap anchor rings: renders 4 perimeter snap anchors on both start and hovered target elements during connector creation with primary accent center dots and white contrast rings.
   - Vector rendering: supports solid, dashed, and circular dotted styles (`StrokeCap.round`, custom metric extraction), start/end markers (`arrow`, `dot`, `diamond`), and center pill text tags.
4. **Editor Gestures & Controls (`lib/features/canvas/canvas_editor.dart`)**:
   - In `_down`: snaps start point to nearest card anchor and tracks `_connectingStartId`.
   - In `_move`: snaps target endpoint to closest candidate anchor, sets `_connectingEndId`, and dynamically updates connected connectors when moving cards.
   - Connected edge following: moving linked cards automatically recomputes and stretches connectors in a single undoable transaction.
   - Inline text editing: double-clicking a connector or selecting "Open / edit" opens a floating text pill at `endpoints.midpoint`; pressing Enter finishes editing.
   - Minimap polish: skips connectors so arbitrary bounding boxes don't clutter the minimap.
   - Top toolbar dropdowns: Stroke Style, Routing, Start Marker, End Marker, Start Anchor, End Anchor, Reverse Direction.
   - Context menu controls: Solid/Dashed/Dotted, Straight/Curved/Orthogonal, Arrow/Dot/Diamond/None for start and end, Auto Anchor resets, and Direction Reversal.
5. **Cloud Sync Guardrail**:
   - All cloud sync and `lib/application/sync/` / `lib/infrastructure/sync/` files preserved completely untouched.

### Validation Evidence
- Unit test suite in `test/canvas_connectors_test.dart` (14/14 passing tests).
- All canvas-related test suites pass (32/32 tests: `canvas_connectors_test.dart`, `canvas_auto_arrange_test.dart`, `canvas_notes_explorer_test.dart`, `runtime_audit_fixes_test.dart`).
- Full repository test suite: **397/397 tests passed cleanly (0 failures)**.
- `dart format lib test` & `dart format --output=none --set-exit-if-changed lib test`: 100% formatted across all 176 files.
- `flutter analyze`: 0 issues found across entire codebase.
- Windows Release build compiled in 62.2s with pinned Windows SDK 10.0.26100.0 (`build\windows\x64\runner\Release\orbit_note.exe`).
- Deployed executable to `C:\Users\iax\Desktop\Orbit Note Windows App` and updated archive `C:\Users\iax\Desktop\OrbitNote-Windows-x64.zip`.

---

# Current task — Canvas Auto-Arrange Layouts (CAN-10) & Research/PDF Cards Split-View Co-Browsing (CAN-15, FILE-13)

Status: delivered and validated, 2026-09-13.

Delivered automatic reversible spatial layout engines (Grid, Horizontal Stack, Vertical Stack, Radial Circle / Mind Map) and first-class PDF highlight / document cards on Canvas with double-click split-view co-browsing under the core invariant: "CREATE ONCE. REFERENCE ANYWHERE."

### Delivered Capabilities
1. **Canvas Auto-Arrange Layout Engines (`lib/canvas/arrangement.dart`)**:
   - Implemented pure, Flutter SDK-independent spatial layout algorithms in `arrangeCanvas`:
     - **Grid Layout (`CanvasArrangement.grid`)**: Balanced column/row packing computed via `math.max(2, math.sqrt(n).ceil())` with uniform 24.0px gutters.
     - **Horizontal Stack (`CanvasArrangement.stackH`)**: Aligns selected elements into a single horizontal row preserving initial `bounds.left` and centering vertically.
     - **Vertical Stack (`CanvasArrangement.stackV`)**: Packs selected elements vertically into a column preserving initial `bounds.top` and centering horizontally.
     - **Radial Circle / Mind Map (`CanvasArrangement.radial`)**: Identifies root/center element and distributes dependent elements uniformly in an elliptical orbit (`dx = radiusX * cos(angle)`, `dy = radiusY * sin(angle)`).
   - Human-readable labels added for all 12 arrangement options (`Arrange in grid`, `Stack horizontally`, `Stack vertically`, `Arrange in radial circle`, `Align left`, `Center horizontally`, etc.).
   - Locked elements are strictly skipped and preserve their exact world coordinates.
   - Single undoable transaction: wrapped in `_history.put(...)` and committed atomically.
2. **First-Class PDF Highlight & Document Cards on Canvas (`CAN-15`, `FILE-13`)**:
   - `CanvasObjectReference` holds `pdfSource` metadata (`documentId`, `page`, `quote`, `color`).
   - `CanvasPainter` renders PDF highlight cards with dynamic `PDF HIGHLIGHT · P. <page>` headers, quote formatting (`“...”`), and accent color strips matching annotation styles.
   - Attachments and PDF document cards render with `PDF DOCUMENT` or `ATTACHMENT` badges and subtitle metadata.
   - Tasks placed on canvas render with `TASK` or `TASK (DONE)` badges and state indications.
3. **Split-View Co-Browsing (`WorkspaceShell`)**:
   - Opening an object reference or PDF highlight from canvas checks active canvas destination:
     - Sets `secondaryId = fileId` and retains `activeId = canvasId` side-by-side in split pane.
     - Canvas stays interactive on the left while the full PDF document or linked note opens on the right.
4. **Context Menu & Toolbar Integration**:
   - Added `AUTO-ARRANGE` section to selected elements context menu and top arrangement dropdown.
   - "Place object" dialog in empty canvas context menu with rich search filtering by title, type, and highlight quote.
5. **Cloud Sync Guardrail**:
   - All cloud sync and `lib/application/sync/` / `lib/infrastructure/sync/` files preserved completely untouched.

### Validation Evidence
- Unit test suite in `test/canvas_auto_arrange_test.dart` (8/8 passing tests).
- Canvas explorer and rich text test suites (`test/canvas_notes_explorer_test.dart`, `test/canvas_rich_text_test.dart`).
- Full repository test suite: **387/387 tests passed cleanly (0 failures)**.
- `dart format lib test` & `dart format --output=none --set-exit-if-changed lib test`: 100% formatted across all 174 files.
- `flutter analyze`: 0 issues found across entire codebase.

---

# Current task — PDF Workflow: Continuous Page View, Precise Highlight Navigation, Multi-Style Annotations & Note Deep-Links

Status: delivered and validated, 2026-09-13.

Delivered comprehensive enhancements to the PDF reading and research workflow under the core invariant "CREATE ONCE. REFERENCE ANYWHERE.":

### Delivered Capabilities
1. **Precise Highlight-Region Navigation & Accent Pulse Ring**:
   - Implemented `boundsForPage(int pageNumber)` on `PdfAnnotation` (in `lib/domain/pdf_annotation.dart`), computing the exact normalized bounding box union across multiple text selection fragments on the target page using pure, Flutter-independent `CanvasBounds`.
   - In `OrbitPdfReader._goToAnnotation`: dynamically calculates viewport centering and zoom factor with comfortable context padding (80px horizontal, 120px vertical) and smoothly navigates directly to the highlight region.
   - `_setActiveHighlight`: triggers a 4-second transient glowing accent focus ring (`_activeHighlightId`) around the target highlight with auto-decay, never mutating durable storage.
2. **Interactive On-Page Highlights & Detail Dialog**:
   - `_buildAnnotationOverlays`: interactive touch/hover overlay layer rendered above pages with hover tooltips.
   - Clicking an on-page highlight opens `_showHighlightDetail` dialog with the quote, comment, color/style badge, "Copy quote", and direct "Open highlight note and comments" button.
3. **Multi-Style & Multi-Color Annotations**:
   - Three rendering styles supported on-page in `_paintAnnotations`:
     - `Highlight`: Soft translucent colored background box (`alpha: 75`).
     - `Underline`: 2.5px baseline stroke with rounded caps.
     - `Strikeout`: 2.0px strikethrough stroke centered vertically.
   - 5-color palette (`Yellow`: `0xffeab308`, `Green`: `0xff22c55e`, `Blue`: `0xff3b82f6`, `Purple`: `0xff8b7cf6`, `Coral`: `0xffef4444`) selectable via toolbar popup menu and context menu.
4. **Continuous, Single-Page, and Two-Page Facing Spreads**:
   - Added `PdfPageMode`: `continuous` (vertical scrolling), `single` (horizontal single page flow), and `twoPage` (facing book spread).
   - Implemented `_layoutPages`: custom layout calculator computing exact coordinate placements for each page mode.
   - Toolbar popup menu for seamless switching with dynamic layout recreation via value keying.
5. **Highlight Summary Export**:
   - Added "Copy all highlights as Markdown" button in the highlights panel (`_copyAllHighlights`), generating structured markdown quotes and page citations sorted by page number via `PdfAnnotation.summaryMarkdown`.
6. **Note & Deep-Link Integration**:
   - `NoteEditor`: Contextual banner (`pdf-source-banner`) showing "PDF Source: <Title> · Page <N>" with a "View in PDF" button.
   - `WorkspaceShell`: Clicking "View in PDF" opens the source PDF side-by-side in secondary split view and navigates directly to the page.
7. **Cloud Sync Guardrail**:
   - All cloud sync and `lib/application/sync/` / `lib/infrastructure/sync/` files preserved completely untouched.

### Validation Evidence
- Dedicated unit and widget test suite in `test/pdf_workflow_enhancements_test.dart` (8/8 passing tests).
- PDF reader test suite in `test/pdf_reader_test.dart` (5/5 passing tests).
- Full repository test suite: **379/379 tests passed cleanly (0 failures)**.
- `dart format lib test` & `dart format --output=none --set-exit-if-changed lib test`: 100% formatted across all 173 files.
- `flutter analyze`: 0 issues found across entire codebase.
- Windows Release build compiled in 64.9s with pinned Windows SDK 10.0.26100.0 (`build\windows\x64\runner\Release\orbit_note.exe`).
- Deployed executable to `C:\Users\iax\Desktop\Orbit Note Windows App` and created archive `C:\Users\iax\Desktop\OrbitNote-Windows-x64.zip`.

---

# Current task — Canvas Sticky Notes & Cards: Interactive Checklists, Tasklists & Headings

Status: delivered and validated, 2026-09-13.

Delivered rich Markdown, interactive task checklists, and hierarchical headings inside canvas sticky notes, cards, and text elements, along with single-click canvas toggles, smart Enter key handling, quick format toolbar, and context menu actions under the core invariant: "CREATE ONCE. REFERENCE ANYWHERE."

### Delivered Capabilities
1. **Rich Canvas Markdown Line Parser & Vector Renderer (`CanvasRichText`)**:
   - Implemented in `lib/features/canvas/canvas_rich_text.dart`:
     - **Checklists**: Parses `- [ ]`, `* [ ]`, `[ ]`, `- [x]`, `* [x]`, `[x]`, `- [X]`, `[X]`. Unchecked items render crisp rounded checkbox outlines; checked items render filled accent boxes with white vector checkmarks and muted strikethrough text.
     - **Headings**: `# Heading 1` (18.5px bold), `## Heading 2` (16.5px semibold), `### Heading 3` (15px semibold).
     - **Lists & Indentation**: Bullet points (`- `, `* `), numbered lists (`1. `), and nested indentation (preserving up to 4+ spaces).
     - **Vector Rendering**: High-performance canvas vector rendering in `CanvasRichText.draw` inside `bounds.deflate(16)` for sticky notes, and when rich formatting is present on cards and text elements.
2. **Single-Click Interactive Checkbox Toggle**:
   - In `CanvasEditor._up`: single-click tap on a canvas checkbox toggles checked/unchecked state directly on the canvas without entering text edit mode.
   - Preserves jitter-free coordinate restoration and commits changes as undoable/redoable transactions in canvas history (`Ctrl+Z` / `Ctrl+Y`).
   - World-coordinate hit testing in `CanvasRichText.hitTestCheckbox`.
3. **Editing Ergonomics in Canvas Text Overlay**:
   - **Smart Enter Key Handling**: Pressing Enter on a checklist line auto-prefixes the next line with `- [ ] `; pressing Enter on an empty checklist item clears the prefix. Also handles bullet and numbered lists.
   - **Quick Format Toolbar**: Floating action bar positioned above the text editing overlay with quick chips: `Task` (`- [ ] `), `H1` (`# `), `H2` (`## `), `H3` (`### `), `List` (`- `), and `Done`.
   - **Tap Isolation**: Wrapped toolbar and text field in `TapRegion(groupId: 'canvas-text-editing')` to prevent clicking toolbar buttons from triggering `TextField.onTapOutside` dismissals.
4. **Context Menu & Toolbar Actions**:
   - Added `Add Checklist` to canvas empty-space right-click menu and toolbar Add menu (`_addChecklist`), creating a starter checklist sticky note (`# Tasks\n- [ ] Task 1\n- [ ] Task 2\n- [ ] Task 3`).
5. **Cloud Sync Guardrail**:
   - All cloud sync and `lib/application/sync/` / `lib/infrastructure/sync/` files preserved completely untouched.

### Validation Evidence
- Unit and widget test suite in `test/canvas_rich_text_test.dart` (18/18 tests passing).
- Full repository test suite: **371/371 tests passed cleanly (0 failures)**.
- `dart format lib test` & `dart format --output=none --set-exit-if-changed lib test`: 100% formatted across all 172 files.
- `flutter analyze`: 0 issues found across entire codebase.
- Windows Release build compiled in 63.3s with pinned Windows SDK 10.0.26100.0 (`build\windows\x64\runner\Release\orbit_note.exe`).
- Deployed executable to `C:\Users\iax\Desktop\Orbit Note Windows App` and created archive `C:\Users\iax\Desktop\OrbitNote-Windows-x64.zip`.

---

# Current task — Canvas in Notes Explorer Navigation & Template Cards Fix

Status: delivered and validated, 2026-09-12.

Focused ergonomics and bug-fix pass resolving canvas folder navigation in Notes Explorer and canvas card template rendering under the core invariant "CREATE ONCE. REFERENCE ANYWHERE.":

### Delivered Capabilities
1. **Notes Explorer Destination Retention (OneNote-Style Experience)**:
   - When browsing inside Notes Explorer (`session.destination == OrbitDestination.notes`), opening or creating any canvas (such as `akmath/exercises/canvas`), note, task, or view keeps the sidebar on the Notes Folder Explorer (`OrbitDestination.notes`).
   - Objects with a folder property (e.g. `folder: 'akmath/exercises'`) opened from Home or search automatically open with `session.destination == OrbitDestination.notes` and uncollapse the parent directory in the tree.
   - Preserves dedicated Canvas rail gallery navigation (`OrbitDestination.canvas`) when browsing flat canvases.
2. **Canvas Template & Standalone Card Support**:
   - Fixed `'UNRESOLVED REFERENCE'` and `'Missing object'` on cards instantiated by all 9 canvas presets (`Narrative Board`, `Game Architecture`, `Call Flow`, `Object Relationships`, `Structure Memory Layout`, `Binary / PE Layout`, `Protocol Flow`, `Process Tree`, `Rendering Pipeline`).
   - Cards without an `objectId` or with non-empty text now render as valid first-class `CARD` elements with custom theme accent colors, titles, and subtitles.
   - Compact cards (height <= 95px) render with tailored typography avoiding text overflow.
   - Truly broken object references without text gracefully display `UNRESOLVED REFERENCE` in error styling.
3. **Canvas Card Interaction & Context Menu**:
   - Standalone cards and template cards can now be double-clicked or opened via right-click to edit their title and body text inline with the live text field overlay.
   - Added `Add Card` to the empty canvas right-click context menu alongside `Add Sticky`, `Add Text`, `Add Section`, and `Add Color Swatch`.
   - Canvas elements inspector (`_showElementList`) displays proper card titles instead of `Missing object`.
4. **Cloud Sync Guardrail**:
   - All cloud sync and `lib/application/sync/` files preserved completely untouched for Astra.

### Validation Evidence
- Unit & widget test suite in `test/canvas_notes_explorer_test.dart` (5/5 passing tests).
- Full repository test suite: **320/320 tests passed cleanly (0 failures)**.
- `dart format lib test` & `dart format --output=none --set-exit-if-changed lib test`: 100% formatted.
- `flutter analyze`: 0 issues found across entire codebase.
- Windows Release build compiled in 31.9s with pinned Windows SDK 10.0.26100.0 (`build\windows\x64\runner\Release\orbit_note.exe`).
- Deployed executable to `C:\Users\iax\Desktop\Orbit Note Windows App` and created archive `C:\Users\iax\Desktop\OrbitNote-Windows-x64.zip`.

---

# Current task — Reverse Engineering, Binary Analysis & Security Research Workflow Pass

Status: delivered and validated, 2026-09-12.

Focused workflow pass making Orbit Note extraordinarily useful for organizing legitimate native binary analysis, game internals research, authorized game security research, Windows internals research, file-format research, protocol analysis, debugging, malware analysis in controlled environments, incident-response research, exploit/root-cause analysis notes, anti-cheat architecture research, vulnerability research, and executable/document triage under the core invariant: "CREATE ONCE. REFERENCE ANYWHERE."

### Delivered Capabilities
1. **Zero New Databases / Single Universal Object Invariant**:
   - Every function, structure, finding, hypothesis, IOC, analysis session, sample metadata, and diagram is a canonical `orbit.note`, `orbit.task`, `orbit.canvas`, or `orbit.view`.
   - References are stored via universal object IDs (`objectId`) and bidirectional wiki links (`[[Target]]`), preventing duplicated storage or sync fragmentation.
2. **Project Scaffolding & 23 Specialized Research Note Templates**:
   - 3 Scaffolding Commands: `createReverseEngineeringProject`, `createGameInternalsProject`, `createMalwareAnalysisProject`.
   - 23 Canonical Research Templates in `WorkspaceController`:
     - Function Note (`createFunctionDoc`)
     - Structure / Layout Note (`createStructureDoc`)
     - Finding Note (`createFindingDoc`)
     - Hypothesis Note (`createHypothesisDoc`)
     - Generic Analysis Session (`createAnalysisSessionDoc`)
     - Static Analysis Session (`createStaticAnalysisSessionDoc`)
     - Dynamic Analysis Session (`createDynamicAnalysisSessionDoc`)
     - Binary Sample / Artifact (`createBinarySampleDoc`)
     - Experiment / Verification Note (`createExperimentDoc`)
     - Protocol Analysis Note (`createProtocolAnalysisDoc`)
     - Packet Structure Note (`createPacketStructureDoc`)
     - PE / Binary Analysis Note (`createPeAnalysisDoc`)
     - File Format / Container Note (`createFileFormatDoc`)
     - Game System / Subsystem Note (`createGameSystemDoc`)
     - Game Class / VTable Note (`createGameClassDoc`)
     - Transform / Coordinate Space Note (`createTransformCoordinateDoc`)
     - Defensive Malware Triage Note (`createMalwareTriageDoc`)
     - Behavior / Execution Observation (`createBehaviorObservationDoc`)
     - Indicator of Compromise (`createIocDoc`)
     - Detection Rule / Signature (`createDetectionRuleDoc`)
     - Version Comparison / Patch Diff (`createVersionComparisonDoc`)
     - Investigation Case Note (`createInvestigationCaseDoc`)
     - Analysis Environment Note (`createAnalysisEnvironmentDoc`)
3. **Domain Utilities & Importers**:
   - `formatAddress` (standardizes hex notation with `0x`) and `formatModuleOffset` (`module+0xoffset`).
   - `calculateAttachmentSha256` & MD5 hash calculation and local caching.
   - `importFunctionsFromCsv` and `importFunctionsFromJson` for bulk importing reverse-engineered symbol catalogs into canonical notes.
   - Exact Address / RVA search ranking (priority 0) in `searchRank`.
4. **Specialized Views & Dashboard**:
   - `AnalysisDashboardView` (`viewType: 're_dashboard'`): Target metadata header, analysis metrics summary, hypothesis progression tracker, blocker watchdog, recent findings/sessions/structures/canvases, and quick creation action buttons.
   - `FunctionTableView` (`viewType: 'functions'`): Interactive function catalog with columns for Function name, Address, Module, Purpose, Confidence, and Status; status filter chips, "Copy Address", "Copy Module+Offset", and CSV/JSON bulk import dialog.
   - `IocTableView` (`viewType: 'iocs'`): Indicators table with indicator type chips (File Hash, Domain, IP, URL, File Path, Registry, Mutex, Process Name), copy indicator button, confidence filter, and inline indicator creation.
   - `KanbanPreset.hypotheses` (`untested`, `testing`, `confirmed`, `disproven`) and `KanbanPreset.functions` (`unknown`, `investigating`, `partial`, `confirmed`).
   - `SavedViewHost` contextual tabs switcher for RE workspaces (`re_dashboard`, `functions`, `iocs`).
   - `HomeView` Active RE & Security Project card with quick jump and watchdog alerts.
5. **Canvas Visual Presets & Enriched Drag-and-Drop**:
   - 7 Architectural & Flow Presets: `Call Flow`, `Object Relationships`, `Structure Memory Layout`, `Binary / PE Layout`, `Protocol Flow`, `Process Tree`, `Rendering Pipeline`.
   - Enriched visual cards when dropping Function notes (accent border, address, module, confidence, purpose), Structure notes (`struct`, byte size), Indicator notes (indicator type badge, value), and Hypothesis notes (hypothesis status).
6. **Code Block Ergonomics**:
   - Hex / byte copy actions ("Copy Bytes") for `hex` and `bytes` code blocks.
   - Disassembly copy actions ("Copy Disassembly") for `asm`, `disasm`, `x86`, `x64`, `arm`.
   - Clean language badges for `yara`, `sigma`, `asm`, `hex`.
7. **Command Palette & Explorer Shortcuts**:
   - Fast RE project scaffolding and note creation commands in `CommandPalette` and folder context menus.

### Validation Evidence
- `dart format lib test` & `dart format --output=none --set-exit-if-changed lib test`: 100% formatted.
- `flutter analyze`: 0 issues found across entire codebase.
- `flutter test --no-pub`: 314 tests passed (including all 13 dedicated RE workflow unit tests in `test/reverse_engineering_workflow_test.dart`).
- Windows Release Build: Verified clean compilation with pinned Windows SDK 10.0.26100.0.

---

# Previous task — Game Development Productivity and Production Workflow Pass

Status: delivered and validated, 2026-09-12.

Focused workflow pass making Orbit Note extraordinarily effective for organizing real-world game development projects across design, engineering, art, audio, and production under the invariant: "CREATE ONCE. VIEW ANYWHERE."

### Delivered Capabilities
1. **Game Development Disciplines, Severity & Agile 6-Stage Kanban**:
   - Built-in 18 game development disciplines (`gameDevDisciplines`: Game Design, Level Design, Systems Design, Narrative Design, Gameplay Programming, Engine Programming, Graphics Programming, Tools Programming, 2D Art, 3D Art, Animation, VFX, Technical Art, UI/UX, Sound Design, Music, QA & Testing, Production).
   - 4 industry-standard bug severities (`bugSeverities`: `blocker`, `critical`, `major`, `minor`).
   - 6-Stage Kanban Pipeline: `KanbanPreset.gamedev` (`backlog`, `planned`, `in-progress`, `review`, `testing`, `done`) and `KanbanPreset.bugs` (`new`, `confirmed`, `in-progress`, `verify`, `done`).
   - Story point estimation dropdown (`1`, `2`, `3`, `5`, `8`, `13`, `XS`, `S`, `M`, `L`, `XL`), estimate sorting (`sortOption == 'estimate'`), and badges.
   - Task detail editor with inline fields for Discipline, Milestone, Estimate, Severity, Build / Target Version, Platform, and Blocker dependency tracking.
2. **Project Scaffolding & 12 Specialized Design Document Templates**:
   - `createGameProject(projectName, ...)` in `WorkspaceController`: scaffolds structured folders (`Design`, `Art`, `Programming`, `Audio`, `Narrative`, `Levels`, `Production`, `Playtests`, `Reference`), starter GDD note, core mechanics spec note, visual canvases (`Core Loop`, `Art Direction & Moodboard`, `Game Roadmap`), and 7 scoped views (`Dashboard`, `Board`, `Backlog`, `Current Focus`, `Bugs`, `Milestones`, `Roadmap`).
   - 12 Specialized Templates:
     - `createGameDesignDocument`: Full GDD architecture.
     - `createFeatureSpec`: Feature systems & technical specs.
     - `createMechanicDesignDoc`: Input rules, juice/feedback, edge cases, failure conditions.
     - `createEnemyDesignDoc`: HP, movement speed, attack tells, AI state transitions, drops.
     - `createCharacterDesignDoc`: Turnaround, silhouette, personality, voice, abilities.
     - `createItemDesignDoc`: Category, rarity, stats, crafting recipe, balance.
     - `createAudioDesignDoc`: Audio cue tracker table (SFX, Music, Ambient, Voice), priority, format.
     - `createQuestDesignDoc`: Objectives, multi-stage flow, fail conditions.
     - `createReleaseChecklist`: Build QA, Store assets, Disaster recovery.
     - `createWeeklyReview`: Accomplished, blockers, velocity/burnup, goals, risks.
     - `createRiskAssessmentDoc`: Description, impact/likelihood, mitigation, triggers.
     - `createDecisionDoc`: Architecture Decision Record (ADR).
   - `createTaskFromFinding`: Converts playtest finding directly into universal task with bidirectional link `[[finding]]`.
   - `duplicateGameProjectStructure`: Clones full folder hierarchy and scoped view definitions for new sequels/milestones without copying completed historical tasks.
   - Contextual folder menu options for game folders, courses, and root.
3. **Canvas Game Dev Presets**:
   - Extended presets: `Game Roadmap`, `Core Loop`, `Level Design & Flow`, `AI State Machine`, `Art Direction & Moodboard`, `Playtest Feedback Board`, `Narrative & Quest Board`, and `Game Architecture & Systems`.
   - Auto-population on canvas creation via `canvasPreset` property.
4. **Game Dashboard & Milestone Progress Views**:
   - `GameDashboardView` (`viewType: 'game_dashboard'`): Production dashboard featuring project metadata header, task completion & story points metrics, blocker watchdog, bug tracker status, interactive discipline breakdown progress bars, open tasks list, and recent game design materials.
   - `MilestoneView` (`viewType: 'milestones'`): Scoped milestone overview grouping tasks by target release milestone with live progress metrics, estimate points sum, discipline breakdown, and quick inline task creation.
   - `Current Focus` tab in task views and Home screen Game Project summary card with blocker watchdog, open bugs, and jump actions.
5. **Contextual Saved View Host Tabs**:
   - Tab switcher dynamically presents scoped view types based on workspace preset: Course views show `Exercises` and `Overview`; Game Dev views show `Dashboard` and `Milestones`; generic views show standard `List`, `Board`, `Calendar`, and `Timeline`.

### Validation Evidence
- `dart format lib test` & `dart format --output=none --set-exit-if-changed lib test`: 100% clean formatting.
- `flutter analyze`: 0 issues found.
- `flutter test --no-pub`: All tests passed across full test suite.
- Windows Release Build: Verified clean compilation with pinned Windows SDK 10.0.26100.0.

---

# Cloud sync task status (Astra)
Preserved unchanged. See [cloud status](../features/cloud-sync.md) and [cloud-sync.md](cloud-sync.md).

---

# Previous task — University, Mathematics, and Visual Study Workflow Pass

Status: delivered and validated, 2026-09-12.

Focused workflow pass empowering students with structured course environments, rich LaTeX/math ergonomics, multi-style visual canvases, and an integrated exercise practice system adhering strictly to "CREATE ONCE. VIEW ANYWHERE."

# Previous task — M6 local-first Google Drive / WebDAV sync

Owner-requested milestone, 2026-09-12. Status: pre-implementation audit and design.
No production sync implementation is delivered. Preserve all local/PDF/polish work.
Historical audit entry: the full brief was subsequently received. Current progress
and remaining implementation are recorded in [cloud-sync.md](cloud-sync.md).

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

