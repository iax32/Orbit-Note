# Markdown and document editing

## Paragraph justification — 2026-10-26

The formatting toolbar adds Justify · Blocksatz beside left/center/right alignment.
It uses the existing single-paragraph/heading orbit:align comment with justify,
preserving source text, inline formatting, native selection, editing and undo.
Rich uses native TextAlign.justify; Read uses the renderer's corresponding justify
alignment. Source remains literal editable Markdown, including CRLF. Unsupported
structured blocks retain their own tools; code is not justified. Existing block
type conversion remains available separately through Format block.


## Math explanation paste — 2026-10-21

Normal Rich paste accepts mixed explanations with `\(...\)` inline and
`\[...\]` display equations, storing ordinary `$...$` / `$$` Markdown.
Browser KaTeX and MathML/MathJax TeX annotations, `data-latex` and legacy
`math/tex` source scripts import as editable equations rather than duplicated
visual/accessibility text. TeX spacing/entities remain intact. Display boundaries
do not add empty paragraphs; browser table/list equations use inline form to
remain within their original cells/items.

Code spans/fences, indented code, URLs and link destinations remain literal.
Ctrl/Cmd+Shift+V, Source and code-field paste preserve the plain clipboard source.
Existing dollar equations are retained; bare prose, currency and unsupported or
partial math are not guessed into equations. Table math decodes the same quoting
in Read, linked/column/callout/Study previews and publication exports; norm bars
retain authored backslashes and enclosing formatting/forward links remain intact. Unknown TeX remains editable with
the existing render fallback. Normal undo/redo and clipboard focus/revision guards
still apply. No API/account, external renderer or document migration is involved.
[Evidence and limits](../tasks/math-explanation-paste-2026-10-21.md).

## Everyday template library — 2026-10-20

New Note from Template and Insert Markdown Template share a searchable library
with Ideas, Journal, Outdoors, AI, Learning, Work, Writing, Life and Code categories.
Search terms combine across title, tags, description and content; categories
filter the results before selection. Narrow/enlarged layouts use one scrollable
browse/details surface so the list cannot collapse behind a large header.

26 added starters cover mind-map outlines and problem exploration; daily/weekly
journals and small moments; hiking, camping, nature observations, gardening and
astronomy; travel, home projects, meals, habits, hobbies and community events;
learning/assignment plans, project kickoff/retrospectives; AI prompt experiments,
evaluation plans, paper reading and dataset cards; and story worldbuilding.
New starters preview an editable title and local calendar date, then materialize
as ordinary Markdown with normal object identity, saving and history. Existing
creative brief/technical article setup remains available. AI templates are offline
records, not model execution or implicit upload permission. Journal starters do
not create a new automatic daily-note destination or a recurring task workflow.
[Checks and limits](../tasks/canvas-review-templates-2026-10-20.md).

## Structured split-pane editing — 2026-10-20

Reactivating a Rich note restores its active table cell or code field, retaining
both selection endpoints. External table text updates clamp both endpoints
without collapsing backwards selections or reversing rectangular anchors.
Source offset projection uses the appropriate leading/trailing boundary for a
backwards cell selection.

Deferred code cut/paste and table grid paste recheck focus ownership/revision,
document epoch and field contents. A changed owner cannot receive an earlier
clipboard operation. Code remains literal text and uses the shared document
history, including when pasted backticks require longer fences. Context-menu
clipboard actions use the same checks as keyboard actions.

Find can select/scroll to a Rich result without moving typing focus into the
document and scheduling a focus steal back to Find. Result selection is recorded
after structured fields are updated, so previous/next traversal remains exact.
Replacement input and the other split pane keep their own focus/history;
document Undo/Redo remains explicit while a search field owns focus. Same-note
conflicting structured drafts preserve the winning canonical source.
See [tests and evidence](../tasks/canvas-split-quality-2026-10-20.md).

## Editor transaction ownership — 2026-10-20

Document undo/redo belongs to its note and observed source. Reusing an editor
for another note or receiving an external source revision retires the previous
chain. Shared splice history validates the complete current source before replay
and restores both selection endpoints, including backwards UTF-16 selections.
The existing bounded history remains shared with code editors.

Find/Replace inputs retain their own text undo/redo. The Find panel also exposes
explicit document Undo/Redo controls, including for reviewed replacements in
Read mode. Read-only/view-only sources reject retained mutation callbacks.
Composition and history commands use the focused editor's ownership rather than
another split pane's input state.

Delayed Source cut/paste and writing tools check an editor revision as well as
source and owner: changing text and undoing back to an identical string cannot
authorize an earlier clipboard or review operation. Replacement review remains
paged and applies as one undoable edit; preview excerpts preserve surrogate pairs.

Repeated recovery requests for the same retained note/Canvas draft share one
pending copy operation. Different pane drafts and newer conflicting versions
remain separate; failures allow retry. Normal repository save/recovery and
portable originals remain authoritative. No storage or clipboard format changed.
See [regressions, checks and limits](../tasks/editor-transactions-quality-2026-10-20.md).

## Writing font and zoom clarity — 2026-10-18

Pixel notebook titles, headings, table headers and callout titles use Tiny5's
regular outlines. Its heavier variable weights expand edges off the original
pixel-cell grid; increasing the snapped font size alone did not correct that.
Heading sizes still provide hierarchy, and authored bold/italic markup remains
intact. Typography previews explicitly request the regular face.

Terminal writing designs now bundle genuine Space Mono regular, bold, italic and
bold-italic faces for offline use. Their headings request the available bold
weight. Book/serif headings retain bold and ordinary sans headings retain
semibold. Shared note fallback lists include symbol/emoji families.

Pixel sizing still composes app zoom, OS text scaling and display density for
pixel text. Nested non-pixel scopes restore the original continuous scaler;
code fields and rendered/editable equations use it instead of inheriting pixel
size steps. Text stays native editable/vector content; no bitmap font enlargement,
font-size preference rewrite, source mutation or viewport scaling is introduced.
The book's intentionally square lettering remains part of its design. Native
renderer/display rasterization is not replaced. See [checks and captures](../tasks/writing-font-quality-2026-10-18.md).

## Writing tools and publishing reliability — 2026-10-17

Footnote and heading forms validate before closing and retain rejected drafts,
including duplicate identifiers and changed/read-only source contexts. They use
the shared Orbit dialog layout with scrollable fields and accessible error text.
Article metadata and print settings ask before discarding unapplied form changes
through Cancel/Close, Escape, back or outside-click. Unchanged and successfully
applied forms close immediately. These temporary fields are not durable drafts;
apply them to the note for normal autosave/history.

Delayed writing commands capture the editor, repository, Vault opening generation,
note identity and format, then recheck source/writability/deletion. Matching text
or a reused ID cannot authorize applying an old tool after switching/reopening.
The writing sheet refreshes text after a build frame when necessary so changes
in the parent editor cannot rebuild a separate route during that frame.

Publishing blocks route dismissal while a file export is pending. Failed exports
keep the page preview and settings, with retryable feedback in the style panel.
Standalone/CMS HTML retains safe code-language classes and table alignment,
wraps long cell text, emits valid line-break/rule tags, and preserves title
anchors when removing a repeated leading document title. Other chapter titles
are retained. PDF and Word continue using their existing publication snapshot.

Behavior and transition coverage: `test/editor_quality_test.dart`; task evidence:
[editor/document-tool quality pass](../tasks/editor-quality-2026-10-17.md).

## Live Canvas diagram selections — 2026-10-16

Canvas's Shapes and diagrams menu exports selected UML classes to a new or
existing Markdown note, or copies the live block for paste at the caret.
The existing object-block grammar carries a precise `elements` fragment with
placement IDs. Rich and Read render a live vector selection using the shared
Canvas painter, with internal relationships, expansion/zoom, Open Canvas and
selectable class details. Editable Rich previews offer Edit diagram through
the same Canvas editor. Removing a note block preserves its source. Missing/
hidden sources remain explicit, with no whole-board fallback. Source changes
refresh Read embeds independently of cached prose without resetting scroll.

Export appends while retaining authored text, line endings and metadata. New
notes inherit source folder/project/course context. Stale snapshots and competing
editor drafts refuse writes; failed-save retry flushes the retained draft without
a second append. Source mode and external Markdown readers show the portable
source link. Published PDF/HTML/Word still warn that workspace previews are links
rather than self-contained diagram snapshots.

## Scroll progress chrome — 2026-10-15

Note editors no longer show a scroll/reading-progress stripe above the document.
Normal document scrolling, line/column status and saved reading/writing positions
remain available. Removing the stripe also removes its document-wide scroll-driven
rebuilds; there is no source or preference migration.

## Delayed insertion safety — 2026-10-15

Source equation/table/link dialogs share the attachment insertion boundary. They
retain the original note, controller/Vault and selection, reject document switches
(including switch-and-return), and recheck editable/deleted state on completion.
If the source or insertion position changes, completion offers explicit Insert
here rather than overwriting newer source; that action rechecks ownership and
permissions. Successful insertions use normal undo. Rich attachment completions
share the outer ownership/permission guard. Source clipboard transfers recheck
current read-only state before deletion/insertion.

Place current block on Canvas captures the original source/title and checks the
owning note, local and repository source before adding an anchor or live placement.
Later navigation cannot change which note it references. Equation Studio scrolls
its controls and bounds its independently scrollable symbol list, retaining Apply
and Cancel at narrow widths/enlarged text. Automated headless evidence does not
claim native desktop interoperability or hardware performance.

## More writing surfaces and pixel zoom — 2026-10-14

Writing surface adds Blueprint (blue drafting sheet/ruler/major grids), Field
journal (sage stitched cover and ruled paper), Typewriter (cream sheet/platen)
and Amber terminal (warm static phosphor/bezel). Ten designs now share the same
paper/photo/contrast/quiet controls, previews, Apply/Cancel/Reset and device-local
preferences. Selecting Blueprint or Field journal from plain paper supplies grid
or rules; explicitly selected non-plain paper is retained. Paper choices appear
before the larger design gallery so they remain easy to reach.

Pixel notebook uses display-aligned font sizing after app and OS text scaling:
Tiny5's 128-unit letter cells in its 1024-unit em render at integer display-pixel
sizes. Rounding changes the requested em size by at most four physical pixels;
successive small zoom changes can share a text size. Crisp pixel sizing can be
disabled for continuous text sizing. The scope covers note title/body and font
previews, leaving the app toolbar and other writing fonts at regular zoom. Native
text is laid out again; no image/viewport transform, font-size/source mutation,
new font or package. Font rasterization still depends on the platform renderer.

## Selection scroll ownership — 2026-10-14

Rich mouse selection can continue while using the wheel, including with the
pointer held still. Wheel input transfers focus before a lazy paragraph can be
recycled; after layout the visible endpoint updates while retaining the source
anchor. Wheel input pauses edge scrolling until the next drag movement. Releasing
or cancelling the pointer stops endpoint updates; subsequent reading scrolls
retain the selected range and copying does not reveal the original paragraph.

Paragraph caret-reveal requests are suppressed while document selection owns the
range, preventing the native drag recognizer from scrolling back to its old
paragraph. Ordinary caret movement, typing, paste and explicit navigation retain
their reveal behavior. Drag hit testing and link hover use global coordinates
exactly once; document selection updates also publish the current range to the
parent/view state. Existing portable Markdown clipboard and undo boundaries apply.
Headless short/lazy-note and complete-editor regressions cover forward/upward
selection, wheel reversal, copy/paste/undo, release/cancel and resumed editing.
Physical mouse/IME and hardware clipboard acceptance remain unverified.

## Long-note drag selection — 2026-10-12

Mouse text-selection drags auto-scroll within a 48-logical-pixel band at the top
or bottom of the Rich editor viewport. Speed increases toward the edge and is
bounded; holding the pointer still continues selection. The original source
anchor remains fixed while newly mounted paragraphs supply the visible endpoint.
Virtualized notes use the same selection model, without mounting the whole note.
Moving away from the band pauses scrolling; reversing direction extends/shrinks
from the same anchor. Scroll offsets clamp to document boundaries.

Release, pointer cancellation, focus loss, app deactivation, note/source/focused
section changes and disposal stop scrolling and invalidate pending endpoint
updates. Ordinary scrolling, touch gestures and structured editor drags retain
their existing owners. This adds mouse prose/heading/list selection auto-scroll;
embedded column editors do not yet delegate edge scrolling to their host. No
content, identity or persistent format changes. Synthetic widget tests exercise
selection and cleanup; physical mouse/IME acceptance remains unverified.

## Selection and clipboard reliability — 2026-10-12

Rich prose Shift-click extends the text range from the original caret; explicit
block handles and block-range commands remain available. Selection highlights
use rendered text boxes without reparenting native text fields or changing their
geometry. Right-click preserves the document range; unmodified navigation keys
collapse it to its boundary. Tables/code/media retain structured block feedback.

Keyboard and native-menu copy/cut/paste honor cross-paragraph ranges. Partial
inline endpoints are balanced to keep unselected formatting valid; document
range copy remains portable Markdown. Replacement uses the ordinary edit/undo
boundary. Delayed paste refuses changed notes, text, selection, focus or active
composition. Formatted inline paste restores the caret using visible text length.
Ctrl/Cmd+Shift+V pastes plain text; Source and code preserve literal clipboard
HTML, indentation and whitespace.

Rich and table paste use the existing native HTML adapter when Flutter provides
only plain text. Windows CF_HTML fragment offsets are UTF-8 byte offsets; malformed
headers fall back to fragment markers. HTML code blocks retain indentation and
blank lines, choose safe backtick fences and decode entities once. Unsupported
HTML/CSS formatting still uses the conservative Markdown conversion. This is not
complete Word fidelity or native continuous selection through every structured
widget. Hardware clipboard/IME acceptance remains unverified. Mouse edge drag auto-scroll
is covered in the newer delivery entry above.

## Citations and bibliography — 2026-10-11

Writing tools → Citations & bibliography manages manual sources with title,
author, year, publisher/journal, DOI, ISBN and HTTP(S) URL. Search sources, add or
edit metadata, insert a citation at the captured writing selection with an optional
page/section locator, and remove unused sources. Source editing and insertion
refresh any existing generated References; bibliography buttons create/refresh
compact author–year or numbered styles. Refresh after ordinary citation deletion.
Only cited sources appear once. Missing sources and duplicate IDs show warnings;
unknown records and fields remain recoverable, and stale/read-only writes refuse.

Rich projects readable labels with exact source boundaries; deleting the complete
label removes its wrapper. Read hides recognized metadata. Source mode retains
ordinary Markdown fallbacks and portable versioned comments. Insertion refuses
code, metadata, existing citations and generated References. PDF/HTML/Word
publishing refreshes an immutable snapshot automatically. This is an offline,
document-local implementation with compact conventions, not full APA/MLA/CSL,
online lookup or Zotero. Reusable source-library notes and reviewed BibTeX import/
export now extend this workspace: Create source library, Reuse library sources,
Import BibTeX, Export BibTeX and Open source library. Imported metadata is a local
snapshot with canonical library provenance; edits elsewhere do not silently update
citations. Conflicts and source selection are reviewed before applying one normal
note mutation. See FILE-10/14 in
[attachments](attachments-and-research.md) and [formats](../architecture/implemented-formats.md).

## Publishing — 2026-10-11

Publish document opens a styled, paginated PDF snapshot with A4/Letter, margins,
fonts, heading numbering, title/author/header, contents and page-number controls.
Canvas diagrams omit their long source URI/revision and text inventory by default.
Enable **Canvas source and text inventory** in publishing to include those details;
the option persists with document settings and applies consistently to PDF/HTML/Word.
The rendered diagram and original live reference remain intact.
Writing tools also inserts a recoverable page-break marker. PDF, standalone HTML
and editable Word export share the snapshot and retain local resource fallbacks.
See [publishing fidelity and limits](import-export-and-portability.md).

## Narrative writing templates — 2026-10-11

Six searchable templates extend the existing picker: Story Outline, Character
Arc, Worldbuilding Bible, Dialogue & Scene Script, Branching Quest & Choices,
and Game Narrative Design. They provide blank author fields, planning tables,
continuity/revision checks, dialogue identifiers, choice flags and narrative
playtest prompts. Search includes names, tags and body content. They create
ordinary Markdown notes; they do not automatically create tasks or folders.
Existing template identifiers and catalog order remain compatible.

Status: product requirements; implemented subsets and limits are recorded in
[CURRENT status](../planning/implementation-status.md). Stage: M1–M2 and later.
Sources: S01 and S07 in the [source map](../product/conversation-extraction.md).
Architecture: [open formats](../architecture/storage-formats.md).

## Purpose and workflow

Feedback refinement (2026-10-09): new preference defaults use a 1080 px writing
width; existing widths remain unchanged. The note toolbar offers focused, wide,
spacious and full-workspace width choices (up to 2000 px), also available in
Settings. HTML/CSS/C++/JavaScript starter templates contain ordinary fenced code.
Each code block can open an expanded draft editor with find, wrapping, indentation
and native text undo; Apply uses the owning note's save/history and rejects a
changed source. Syntax colors distinguish light and dark themes. No execution,
compiler, debugger or language-server service is included.

Creative Project Brief offers optional project name, outcome, audience, constraints,
deliverables and references before creating editable Markdown. Storyboard and
prototype/playtest templates add sequence, evidence and decision tables.

Offline English assistance now only flags known typos or close lowercase spelling
corrections, leaving unfamiliar names and technical vocabulary unmarked. It skips
tilde/backtick fences, unfinished fences and matching multi-backtick code spans.
Repeated-word checks do not depend on word-pair alignment or cross paragraphs.
Context corrections use half-open ranges and reject stale text/composition. This
is a limited local rule set, not comprehensive multilingual grammar correction.

Typography refinement (2026-10-03): Rich refreshes cached blocks when font family
or line spacing changes. Source/Read/Rich prose, aligned Read blocks, tables and
callouts use the selected font/size and body spacing. All six heading levels share
consistent sizing and natural serif bold weights. Code/math retain their fonts.
Font switches preserve selection and do not rewrite Markdown. See
[typography evidence](../tasks/font-comfort-2026-10-03.md) for validation and native
rendering limits.

A user writes an ordinary Markdown note, inserts links and a checklist, saves it,
and can continue in another text editor. Orbit Note can render richer linked content
without making the underlying document unreadable. The first editor should favor
reliable text input and save behavior over an ambitious custom block engine.

## Requirements

## Composition and connected blocks — 2026-10-11

Writing tools and Insert offer two/three equal columns, Image and text, Inline
drawing, Live object and Convert selection. Columns contain ordinary editable
Markdown, stack on narrow/enlarged layouts, and provide reverse/stack controls.
Nested columns and unfinished fences are refused. Source and Rich support inserting
image-and-text layouts through the existing attachment picker. Their captions,
source links and left/right sizing remain the existing media workflow.

Live objects reference one canonical task, saved collection, Canvas or other
workspace object. Task completion writes through normal commands. Collection cards
show the current query count and first eight members with original navigation.
Milestone tasks retain their status/due information. Inline drawing creates or
references a Canvas; Edit drawing opens the shared Canvas editor from the note,
with ordinary ink/shape/history behavior and stale-source protection. Previews use
the same painter and bounded attachment cache. Read offers previews/open-source;
removing a Rich embed leaves its source untouched. Missing/unsupported sources
retain explicit source links and recovery messages.

Replace all now opens a paginated before/after review with selectable matches.
Prose, tables, code and column contents use their existing source-aware projection;
layout markers/object IDs are excluded from Rich matching. Applying uses one note
undo operation and rejects a changed note/workspace. Source still searches literal
markup. Convert selection expands to complete prose/list blocks; structured or
unknown blocks are refused. Options are paragraphs, checklist, callout, one-column
table, or non-destructive linked cards on an existing Canvas. Table conversion
refuses pipe characters rather than damage labelled wiki links. Canvas placement
is sequential; a failed save preserves existing placements and reports recovery.

Columns are limited to 200,000 UTF-16 units/10,000 lines, without nested column
layouts. Exports stack columns and retain object source links with explicit
warnings; live collection contents/drawing previews are not publication snapshots.
No new database, object type, migration or second drawing engine is introduced.
See implemented-formats.md and current task for validation evidence.

### Requirements table

| ID | Observable behavior |
|---|---|
| EDT-01 | Create, open, edit and locally save Markdown text; reopening returns the committed text and stable object identity. |
| EDT-02 | Support headings, paragraphs, bold/italic, strikethrough, inline/fenced code with highlighting, quotes, horizontal rules, bullet/numbered/nested lists, checklists, links and images. Rich visual editing round-trips through the supported Markdown subset. |
| EDT-03 | Offer Rich, Source, Read and Split modes, with selection/caret behavior preserved where meaningful; the source-preserving projection follows ADR-0011. |
| EDT-04 | Editing respects keyboard composition/IME, Unicode, selection, copy/paste, undo/redo and accessibility; rich toolbars cannot be the only way to edit. |
| EDT-05 | Wiki-link completion, link navigation and attachment insertion integrate with workspace objects without copying their content. |
| EDT-06 | Properties/frontmatter remain user-owned. Preserve unfamiliar fields, unknown extension text and useful formatting through edits/import/export. |
| EDT-07 | Show unsaved, saved locally, save failed and external-conflict states accurately; prevent a delayed save from overwriting a newer edit. |
| EDT-08 | Later rich references can embed a board, drawing, file, saved query or plugin widget with readable fallback text and a way to open the source. |
| EDT-09 | Templates, slash commands and a configurable formatting toolbar create supported structures; unsupported blocks remain visible/recoverable instead of disappearing. |
| EDT-10 | Collapsible headings/list branches, outline mode and focus on one heading/section provide structured navigation without changing the document's stored meaning. |
| EDT-11 | Markdown tables offer spreadsheet-like cell navigation, selection and row/column editing; they remain document tables rather than silently becoming independent database objects. |
| EDT-12 | Underline where supported by an Orbit Markdown extension, callouts, captions, comments, footnotes and LaTeX/math need explicit grammar, rendering and portable fallback behavior. |
| EDT-13 | Local find/replace and word/character/read-time statistics operate on the intended document/selection with scope and estimated read-time labelled. |
| EDT-14 | Spelling and grammar assistance can use available platform/provider support; remote analysis requires separate consent and source text remains editable offline. |
| EDT-15 | Continue Writing restores the note's scroll/cursor/collapse state where resolvable; changed documents fall back to a valid position, never modifying content to match old view state. |

## Data and integration

One owning Markdown file/frontmatter contains the note's text and properties.
Placement geometry stays in the board. A document title and its first heading are
distinct according to the existing storage contract. Inline checkboxes initially
produce task occurrences anchored in the note; a task view writes back through
the same owner once stable anchors are implemented.

The chat's `{{view:...}}`, mentions, due-date emoji and relation syntax are examples,
not a selected dialect. Choose extension grammar and fallback behavior together
with fixtures and an ADR when architecture warrants it. Standard Markdown must
remain useful even where an extension is unavailable.

## States and edge cases

External edits while the note is open produce a reconcile/compare path; unresolved
conflicts preserve both texts. Renaming a file must retain its identity. Permission
loss/read-only sources keep selection/copy/reading usable. Huge notes need deliberate
loading/editing limits and evidence, not a hidden truncation. Sanitize rendered
HTML/links without rewriting the only source copy. Never execute code fences or
plugin-looking syntax merely by opening a note.

## Acceptance scenarios

- EDT-01/06: edit a fixture with unfamiliar frontmatter and extension blocks;
  round-trip without losing them and reopen its `.md` externally.
- EDT-04: type using composition input, undo a composed change, and verify selection
  and text correctness; exercise keyboard-only editing at larger text scale.
- EDT-07: change the file externally during a delayed save; preserve both versions.
- EDT-08: disable an embed's plugin and retain a visible reference/fallback.

## September 2026 product brief

The S10 brief adopts Markdown-first **rich visual editing** as the product goal.
Editor selection must prove source/visual round-trip, IME, clipboard and extension
preservation before it is chosen. The existing M1 minimal text-save slice remains
valid preparation, not the final editing experience. Block references and live
transclusion use LNK-10 and EDT-08; desktop clipboard/image mechanics use DES
requirements in [desktop interactions](desktop-interactions.md). User comments
inside documents must distinguish local annotations from shared comment threads.

## Delivery

Live linked sections (2026-10-10): **Linked section** in Insert/slash commands
searches other Markdown notes, previews a paragraph, list/checklist or heading
section, and inserts a live reference. A heading includes subordinate sections
until the next peer/ancestor. Source anchors use normal recoverable saves and
survive renames. Failed saves and changed picker/host text prevent stale insertion.
Rich and Read share selectable content, exact source navigation and missing,
ambiguous/cyclic source warnings. Rich offers removal and explicit detachment into
ordinary Markdown through existing undo/save. Read offers source navigation.
Removal does not delete source objects. An insertion-time quoted Markdown snapshot
provides a readable fallback in other editors and when the target cannot resolve.
Current workspace projection changes refresh embeds; external edits follow normal
reconciliation. Source references are read-only inside the embed; edit via Open source.
See [format](../architecture/implemented-formats.md#live-linked-note-sections--2026-10-10)
and [task evidence](../tasks/current.md) for bounds and validation.

Figure captions and sources (2026-10-10): **Caption and sources** on a Rich media
section edits a plain-text caption and up to 20 labelled links. Sources can select
an existing note by stable UUID, point to an attachment/page fragment or use HTTP(S).
Sources can be reordered/removed, and show as accessible link chips under the image
in Rich and Read. Missing note IDs are marked in Rich instead of fabricated targets.
Surrounding text, layout changes, image replacement and stacked conversion retain
the details. Caption dialogs reject a changed figure rather than applying stale data;
the owning note's existing save/history/undo remains authoritative. The ordinary
Markdown fallback keeps captions and links readable. Figure-source chips retain
their existing labelled links. The citation workspace above adds bibliographies
separately; automatic citation fetching and external metadata lookup remain absent.

Implemented 2026-10-10: **Image and text** in the toolbar/slash menu creates a
rounded image beside ordinary rich headings, lists and paragraphs. Existing images
offer **Add text beside image**. Layout controls select left/right and three sizes,
replace/remove the image, or return the section to ordinary stacked Markdown.
Narrow panes and enlarged text stack automatically; Read mode uses the same layout
and opens the original attachment. Comment markers retain a useful ordinary Markdown
fallback, source editing and existing note save/history/undo. Unsupported markers
remain preserved. See [format and limits](../architecture/implemented-formats.md#markdown-image-and-text-sections--2026-10-10)
and [task evidence](../tasks/current.md).

M1 delivers a minimal text-save loop. M2 adds dependable Markdown editing/preview
and links. Rich block editing, formulas and embedded widgets follow only after
their storage and interaction contracts are proven.

The owner's 2026-09-10 continuation prioritizes stabilizing the existing directly
editable Rich projection before unrelated features. [ADR-0011](../adr/0011-source-preserving-rich-markdown.md)
records its source ownership and grammar. Inline/block TeX includes common
university fractions, roots, sums, integrals, matrices, Greek letters, sets, logic
and indices; invalid/unsupported input must remain visible and editable. An
equation is edited locally without switching the entire note to Source. This
refines EDT-02/03/04/11/12/15 and does not add a second feature backlog.

## Incremental delivery (2026-09-10)

Rich formatting escape, block action menu and academic math-grid subset are tracked in the [audit polish report](../planning/audit-polish-batch.md). Cross-block text selection preserves exact Markdown ranges. Grid edits emit standard TeX; no document database is introduced.

## Delivered Notes interaction refinement — 2026-09-11

Desktop paragraph insertion and block-action menus appear on hover or keyboard
focus; touch and accessible-navigation modes keep controls visible. Hovering alone
never changes the source. Reduced gutter/control heights remove excess vertical
spacing, while the document remains centered. The formatting bar sizes to its
contents at the left and scrolls horizontally when the pane is narrow.

PDF attachments inserted now use stable file-object wiki references. Standalone
legacy Markdown PDF links retain their source and expose an Open PDF action in
Rich mode. PDF UUID page anchors survive Rich/Read navigation. Cross-block native
selection now supports exact copy, cut, delete, and replacement across rendered
blocks; drag reordering remains a separate block operation.

## Runtime stabilization — 2026-09-13

Block moves now retain leading blank lines and each block's existing trailing
spacers. A missing line ending or paragraph separator is added only at a newly
joined boundary when necessary to keep paragraphs editable. CRLF is retained.
The move remains one change in the existing shared undo history.

Heading collapse uses transient per-block IDs, independent of heading text and
duplicate-title order. IDs follow title edits and block moves. Device-local pane
state records IDs/positions with a document hash; it restores only against the
matching document, with one-time migration of older text-based collapse keys.
IDs never enter Markdown. Arbitrary external restructuring may reset collapse
state safely; this is not persistent authored block identity. Cross-block native
selection is handled by the Rich editor selection model.

## Direct rich math refinement — 2026-09-14

Rich inline/display equations now use one editable expression for the supported
subset, instead of a rendered duplicate above labelled input cards. Click directly
on a numerator/denominator, power/subscript, root/degree or sum/integral limit to
write a value. Nested fractions and roots are supported. New Inline equation and
Block equation commands insert and focus an empty slot without opening Studio.

Keyboard workflow:

- Type `/` after an operand or selected text to create a fraction; the denominator
  is selected for immediate typing. `^` and `_` similarly create power/index slots.
- Tab/Shift+Tab move between parts; Up/Down move between fraction halves or paired
  limits/scripts. Left/Right cross field boundaries. Composition stays with the IME.
- Symbols & templates opens the original searchable, category-filtered table of
  1,473 renderer/catalog entries beside the equation. It stays open during insertion
  and typing, without moving or covering the equation. The same table is available
  in Advanced. New equations open it automatically; Escape/Close dismisses it.
  Selecting a standalone symbol shows its glyph instead of command text and retains
  the insertion caret. The catalog covers the bundled renderer, not every possible
  third-party LaTeX package or user macro.
- Ctrl/Cmd+A selects the whole equation for copy/cut/paste/delete or replacement.
  Copy stores standard LaTeX. A failed clipboard cut/paste preserves the equation;
  late clipboard results cannot replace later edits. Backspace on an empty fraction
  half unwraps it while retaining the other half; empty root degrees and script/limit
  arguments remove only the affected structure. An empty equation remains editable.
- Ctrl+Z/Y and Ctrl+Shift+Z use the same note history as Source; macOS equivalents
  are wired. Copy LaTeX and the Advanced equation editor remain available.

The transient `MathEditDocument` projects source spans only; it is never a durable
document format. Edits preserve command variants, untouched whitespace, unknown
commands and surrounding Markdown/CRLF. Unbraced arguments are braced only when
edited. Joining a command to a letter adds a necessary delimiter. Empty inline
equations retain `\square` so they remain editable; newly edited inline boundary
whitespace is trimmed because `$ ... $` is not Orbit's inline equation grammar.
Merely opening/switching modes does not rewrite any source.

Matrices/aligned environments, scalable delimiters and malformed or oversized
expressions retain safe rendering/source fallback and the existing local advanced
editor; supported grids keep Edit grid. Editing arbitrary TeX structures, partial
selections spanning several equation parts and exact TeX typography in every
editable field are not complete. Whole-equation selection is supported as above.
Read mode continues using the existing TeX renderer. No CAS, plotting, remote
rendering, account requirement, dependency or storage migration is introduced.

Evidence and current validation are tracked in the [current task](../tasks/current.md).

## Calm document layout and alignment — 2026-09-16

The title, headings and prose share a consistent left edge. The compact formatting
bar follows the centered document column. Less common formatting is in More
formatting; narrow panes can scroll the bar horizontally. Block controls occupy a
fixed right gutter and appear when hovering that gutter or focusing its controls,
not when simply typing in prose. Touch and accessible-navigation modes keep them
available. Blank separators have no full-width insertion rule. Basic writing
commands appear first in the slash menu; longer menu rows stay within its bounds.

Align left/center/right applies to the active paragraph or heading. Alignment
survives editing, shared undo, mode changes and ordinary Markdown saving. Enter
continues the alignment into the new paragraph. Inline-math paragraphs align their
existing flow as a group. Other block types keep their existing dedicated layout
and explain that a paragraph/heading must be selected for this command.

Alignment uses an exact `<!-- orbit:align=center -->` (or `right`/`left`) comment
immediately before one paragraph or heading. Selecting left removes the marker.
Other Markdown readers can ignore the comment and still display the original
content. Unknown comments, unsupported alignment values and unrelated source
remain unchanged. This adds no separate document store or migration; Source mode
exposes the comment. See implemented formats for the empty-paragraph convention.

### Paragraph-control follow-up — 2026-09-17

At the owner's request, hover discovery now covers the whole paragraph, revealing
the right-gutter add, drag/menu and heading-collapse controls. Blank separators
show an insertion rule and plus on hover. Controls still disappear away from the
paragraph and retain keyboard/touch access. This supersedes the gutter-only hover
behavior above without restoring the heading indentation bug.

Focusing an existing trailing blank suppresses the redundant zero-byte terminal
editing field, preventing adjacent duplicate empty prompts. Original Markdown
blank lines are retained; the correction affects only the transient projection.

## Rich Markdown boundary repair — 2026-10-01

Backspace removes an empty prose paragraph and returns to the previous editing
surface. At the start of a list item, quote or heading it removes that structure
before merging; Delete at prose end joins the next prose block. Enter continues
quotes/lists and preserves balanced marks and existing line-ending conventions.
Linked prose anchors are retained, and a merge that would discard an independently
referenced identity is refused. Formatting preserves the selection; ambiguous
Markdown combinations offer a smaller-selection or Source fallback. Delayed paste
and link insertion never overwrite an intervening edit. See
[repair evidence](../tasks/markdown-editing-repair-2026-10-01.md) for validation gaps.

### CommonMark inline code spans — 2026-10-06

Rich projection recognizes code spans delimited by matching backtick runs of
any length. It folds CRLF/LF inside visible code to spaces and applies the
CommonMark edge-space rule using ASCII spaces only while retaining exact source
offsets for selection and editing. Unmatched delimiters and unsupported inline
extensions remain literal source text. Variable-run, whitespace-normalization,
nested-wrapper, and source-boundary fixtures are covered in the current task
evidence. A CRLF source ending maps to one visible normalized space while its
source range retains both code units, so replacing that visible position cannot
split the authored line ending; UTF-16 offsets remain stable around emoji and
other surrogate pairs. These mappings round-trip through reference-link label
edits without rewriting the authored reference identifier.

### CommonMark inline links — 2026-10-06

URI and email autolinks project their visible labels and preserve exact source
boundaries; email targets use a `mailto:` destination for link actions. Full
inline links decode Markdown escapes and HTML entities for link actions, support
escaped and balanced destination parentheses, parse optional quoted,
apostrophe, or parenthesized titles with one-line-ending spacing, and preserve
their authored source boundaries. Link labels accept escaped brackets and
matched nested bracket pairs; unmatched labels remain literal and nested inline
links are never projected as an outer link. Backslash escapes follow CommonMark:
only ASCII punctuation is escaped, while a backslash before an ordinary
character remains visible and cannot hide a bracket boundary. Full and collapsed reference links project
only the authored label, retain the reference
identifier and delimiters during edits, and expose their reference metadata to
the Rich link affordances. Unresolved references remain editable and
source-preserving. Caret mapping treats an escaped punctuation pair as one
visible character whose source range includes both the backslash and the
punctuation, so insertion, replacement, and deletion keep authored escapes
well-formed.
Escaped emphasis, strike, highlight, and code delimiters are excluded from
nested marker matching, so a visible punctuation character cannot accidentally
close a surrounding format span.
Link and reference-label scanners also skip balanced code spans, so brackets
inside code cannot terminate the surrounding label; unmatched code spans remain
literal source. An unmatched multi-backtick run is kept indivisible, preventing
its tail from being retried as a shorter delimiter. Backslash parity is applied
before delimiter matching: even runs can open code, odd runs escape the next
backtick, and backslashes inside balanced code remain literal. Edge-space
normalization remains stable inside nested emphasis and links, including
non-breaking spaces and UTF-16 caret ranges. A valid full reference link may
contain a projected child reference link; an outer inline link containing an
active child remains literal, so nested link syntax cannot create two active
inline destinations. When a Rich selection removes one side of a nested label,
the editor escapes only the unmatched bracket and keeps the visible text and
caret range stable.

### Whole-document reference definitions — 2026-10-06

Top-level reference definitions are indexed with Unicode case-folded,
whitespace-normalized labels. The normalizer follows CommonMark's rule: it
trims and collapses spaces, tabs, and line endings, while preserving other
Unicode whitespace such as non-breaking spaces. Rich blocks and Find/Replace share that map, so
full and collapsed reference links resolve to their declared destinations even
when the definition appears later in the note. Definitions inside fenced or
indented code are ignored; duplicate labels keep the first definition.
Shortcut reference links resolve only when a matching definition exists, so
ordinary bracketed prose remains literal.

Reference identifiers accept backslash-escaped square brackets while keeping
those backslashes in the authored source. Unescaped square brackets inside a
reference identifier remain literal, and unsupported reference chains cannot
be partially captured as shortcuts. Shortcut references — `[Guide]` — resolve only when a normalized definition for
`Guide` exists in the same document. Ordinary `[bracketed prose]` and inline
image syntax remain literal, while matched shortcuts retain their brackets and
source offsets during edits. Definition changes refresh shortcut destinations
through the same Rich/Find projection path. Reference definitions validate the
complete destination and optional title. Empty angle-bracket destinations,
balanced destinations, escaped delimiters, next-line destinations, and nonblank
multiline titles are supported. A complete definition remains one raw editing
block so Rich edits cannot split it into separate paragraphs; malformed trailing
text remains ordinary source. When a definition's destination and multiline
title use different LF/CRLF endings, the raw block retains those exact endings
through parse, reparse, and resolved reference-link edits; the normalized
definition index is checked against the lossless parser so lookup never needs to
rewrite authored source. Escaped square brackets in definition labels retain
their authored backslashes in the raw block and in full/shortcut reference-link
edits, including when the mixed-ending definition is reparsed; visible caret
round-trips never consume the escaped identifier.
Unicode full case folding is applied before label lookup, including multi-codepoint
folds such as `ß` to `ss`, compatibility letters such as Kelvin sign, long s,
and Greek final sigma. Those folds are tested with escaped labels and mixed
definition endings while authored spelling remains unchanged.
Duplicate definitions use the first valid normalized label and keep later
definitions as independent raw blocks. A resolved full reference edits only its
visible label and retains the authored identifier; an unresolved full reference
remains editable with its identifier and unresolved target. An unresolved
shortcut stays ordinary bracketed prose, so selecting only its visible contents
does not consume the surrounding brackets. These paths preserve source-visible
selection round-trips across mixed LF/CRLF source. Link-label replacement
normalizes unmatched `[`/`]` delimiters inside the edited wrapper without
rewriting balanced nested labels, code spans, or authored reference definitions.

### Structural editing safety — 2026-10-01

Duplicated prose does not copy the original's explicit block identity; references
remain attached to the original and the copy receives a new anchor when requested.
The block menu copies a precise reference through the same validated command as
the note toolbar, including for aligned prose. Conversion preserves alignment and
refuses to discard linked identities or unknown source. Code conversion chooses a
fence that cannot collide with its payload. Alignment preserves selections and
uses the document's line-ending convention. Delayed attachments offer Insert here
when the position changed, and errors/overlapping requests preserve the note.
See [audit evidence](../tasks/markdown-hidden-audit-2026-10-01.md) for test limits.

### Composition history — 2026-10-01

Rich and Source group a text composition into one shared document history entry.
Canceling the composition adds no entry and preserves existing redo. Document undo
and redo wait until composition ends. Rich history reads the final Markdown after
the input controller's change has been projected into source. Native evidence and
OS IME/keyboard acceptance limits are recorded in
[native checks](../tasks/markdown-native-acceptance-2026-10-01.md).

### List exit and selected block handles — 2026-10-01

Enter on an empty list item or quote leaves its separator intact and focuses the
paragraph after it. Typing creates independent prose, including at the end of a
note. Clicking a selected block's handle retains the range for menu/drag actions;
clicking prose returns to text editing. A menu opened for a selected range cannot
apply its action to a subsequently changed range. See
[regression evidence](../tasks/markdown-regressions-2026-10-01.md).

### Table and multiline clipboard reliability — 2026-10-01

Editing a cell preserves untouched table source and spacing; adding/deleting rows
retains surviving row spelling. Column-shape changes use standard Markdown table
encoding. Literal backslashes/pipes round-trip without exposing extra columns.
Deleted cells cannot reappear with old controller text; undo/redo restores the
visible cells as well as source.

Keyboard and context-menu Paste use the same behavior. Tables paste TSV/line rows
or replace a plain cell selection; the existing 1,000-row/50-column limit refuses
oversize input without truncating it. Multiline prose becomes separate editable
blocks where its Markdown requires them, including beside inline equations. It
uses the note's LF/CRLF convention and participates in shared undo. Clipboard
errors preserve content, and delayed responses cannot overwrite a changed target.
  Table cells can be selected as a rectangle with mouse drag, Shift-arrow, or
  Ctrl/Cmd+A, then copied as TSV or quoted CSV. Rich copy also publishes an HTML
  `<table>` payload with the TSV fallback. Windows writes both CF_HTML and
  CF_UNICODETEXT; Android uses `ClipData.newHtmlText`; iOS writes HTML and UTF-8
  text to one pasteboard item; Linux advertises GTK `text/html`; and web uses
  `navigator.clipboard.write` with HTML/plain Blob representations. Hosts without
  a rich bridge safely keep plain text copy, including rejected or interrupted
  rich writes. HTML paste from browsers and office apps uses the same
  conservative conversion path.
HTML tables from browsers and office apps use the same conservative conversion
path as ordinary rich paste. CSV parsing keeps quoted commas, tabs, escaped
quotes, and embedded newlines inside one cell; separator inference ignores
delimiters inside quotes. A multiline cell is stored with the editor's portable
`<br>` cell spelling so Markdown source remains one table row.
Pasted prose retains pending/inherited typing styles and explicit formatting exits.
See [table/clipboard evidence](../tasks/table-clipboard-2026-10-01.md).

### Find/replace across modes (2026-10-01)

Find keeps the active editor mode. Rich/Read match visible inline prose in text,
headings, lists and quotes; Source/Split match literal source. Other specialized/raw
blocks retain literal search; table/callout behavior is described below. Search
results map to owning source ranges, with
Unicode whole-word checks against the full text before selection filtering.
Case-insensitive matching uses the generated Unicode 15.1 full case-fold map,
so length-changing folds such as `ß` to `ss` still map to the exact authored
UTF-16 span; partial expansion matches remain literal. Rich and Source share
these ranges, while replacements keep the existing formatting and target-safe
projection rules.
Single Replace accepts only computed matches. Selection scope follows source
edits and history, and counts refresh after edits, mode changes and undo/redo.

Rich replacement preserves supported inline marks and link targets using the
existing projection, verifies literal replacement text and refuses unsafe batches
atomically with a Source fallback. Enter/Shift+Enter retain Find focus; Source
navigation scrolls to distant results. Read navigation remains approximate.
See [find/replace evidence](../tasks/find-replace-2026-10-01.md).

### Table/callout search and source preservation (2026-10-02)

Rich/Read search table editing-cell text and callout title/body text, excluding
table alignment/boundary pipes and callout type/quote syntax. Escaped pipes map
to visible cell characters. Rich navigation selects exact cells/body ranges,
highlights callout titles and brings distant cells into view while Find retains
focus. Read still uses approximate navigation; table/callout Markdown delimiters
are literal as in their editing fields.
Find seeds queries/scopes from live structured-field selections, preserving raw
source boundaries around escaped pipes and quote prefixes.

Callout typing/type changes and search replacement preserve unknown type names,
untouched whitespace, quote prefixes and LF/CRLF instead of encoding the whole
block again. New lines preserve quoted structure. Tables/callouts retain compatible
controllers and focused selections through shared undo/redo. Unsafe newline
replacement into cells/titles refuses the complete batch; Source remains editable.
Structured navigation and follow-up edits use the child field's latest local
emission while a parent rebuild is pending, so a rapid callout type change cannot
be reverted by the next body keystroke or mapped against stale source offsets.
Deleting an authored leading blank line keeps the body inside its callout and
participates in exact source undo.
See [table/callout search evidence](../tasks/table-callout-search-2026-10-01.md).

### Precise fenced-code search (2026-10-02)

Rich/Read search literal fenced code bodies, excluding fences and language/info
labels; Source/Split search complete source. Rich navigation selects exact code
ranges and scrolls distant lines/columns into view while Find retains focus.
Live code selections seed queries and selection scopes with raw source coordinates.

Code typing and replacement preserve fence style, info, spacing and LF/CRLF;
delimiter-only body lines grow fences only as needed to retain block ownership.
The replacement field accepts multiline text. Undo/redo retains code fields and
valid selections and restores exact source. Embedded view/snapshot blocks and
unfinished raw fences keep their existing navigation fallback; Read remains
approximate. See [code-search evidence](../tasks/code-search-2026-10-02.md).
When a delimiter edit replaces the parsed block during `_load`, a following
input event resolves the current code block by position before applying its
source-preserving edit, so fast typing cannot drop a line between frames.

### Read search highlights and layout navigation (2026-10-03)

Read highlights in-scope matches and outlines the active result in mapped rendered
text. Search uses the existing full-document renderer and does not modify Markdown.
Next/Previous reveal the actual match box, including distant code lines/columns,
while Find retains keyboard focus. Matching case, whole-word and selection rules
stay consistent with the source search index.

Occurrence count and owning segment text must both agree with source before exact
decoration/navigation is enabled. Unmapped/custom/raw or LaTeX rendering retains
approximate fallback; a mismatch suppresses highlights rather than guessing the
wrong occurrence. Closing Find and empty queries clear decoration. See
[Read-search evidence](../tasks/read-search-2026-10-03.md).

Fenced-code Read search treats authored CRLF and LF line endings as equivalent
to the renderer's LF display for multiline queries without rewriting source.
Language/info strings remain outside the searchable code body. The Find field
accepts multiline pasted queries, and exact code highlight/reveal retains focus.

### Callout Read search and selectable titles (2026-10-03)

Read callout titles can be selected/copied and wrap without header overflow.
Search maps authored title characters separately from generated type labels.
Plain multi-paragraph bodies are verified as one source segment and navigate in
source order with titles and surrounding prose. Aligned selectable headings/prose
retain their existing layout and exact Read matching. Source/rendered markup
ambiguity still uses the conservative fallback. See
[custom Read-search evidence](../tasks/custom-read-search-2026-10-03.md).

Callout bodies reuse the note-level link router in Read mode, so external,
internal, missing and relative attachment links keep the same opening behavior
as ordinary prose. The note image builder is also passed into nested callout
Markdown. Relative attachment images remain local previews and expose an
accessible tap target that opens the original file through workspace storage.

Aligned blocks, tables and block quotes use the same local attachment preview
and tap behavior. Remote and data images remain display-only, while every local
relative image can open its original without changing authored Markdown.

Footnote definitions and paragraphs adjacent to inline or display math use the
same image action. Read mode also renders `orbit-view` and `orbit-snapshot`
fences as their interactive view/snapshot surfaces instead of showing raw code;
those widgets use their existing local object-opening behavior and never rewrite
the fence source.

PDF quote links preserve `#page=N` targets when opened from Read mode, and
Canvas wiki-links open their stable object IDs. Local image previews expose a
retryable failure state so transient vault/read errors can recover without
rewriting the image reference or the surrounding note.

Attachment replacements detected in the native Vault now invalidate visible
Read and Canvas previews through a batched media revision. Ordinary widget
rebuilds do not re-read unchanged images, and generation fencing prevents an
older in-flight decode from winning after a replacement.

Read attachment failures are explicit: missing files, Vault read errors, and
undecodable bytes have separate messages and all retain a Retry action. A
replacement revision shows “Refreshing preview…” while the new bytes load.
Read previews also expose attachment title, MIME type, recorded versus loaded
byte counts, a selectable Vault reference, copy-reference, open-original, and
Show in Folder actions. Authored image alt text is included in the accessible
open-attachment label; remote images remain display-only.

PDF review quote cards expose copy-citation and open-source actions while
preserving the selected page target. Canvas citation and image previews expose
the same copy/open affordances, routing source PDFs and original attachments
through workspace storage. Math-adjacent images use the shared attachment
action surface, including authored descriptions for accessibility and the same
retry/details controls when bytes are missing or cannot be decoded.

Source drift remains visible at the point of use. PDF review rows warn when the
stored checksum differs from the open document and require review before direct
navigation. Canvas citation cards show a source-changed badge but keep the
source-open action available for verification. Attachment previews announce the
new revision after replacement bytes load, including images beside equations.

### Local passage review (2026-10-10, EDT-12)

Rich/Source selections support comments and proposed Markdown replacements.
Document review provides unresolved/comments/suggestions/all filters, exact passage
navigation, resolve/reopen, accept/reject, explicit reattachment and removal.
Wide screens dock the panel; smaller/enlarged layouts use a scrollable sheet.
Ctrl+Alt+M comments on the current selection. Accepted suggestions retain a receipt;
one undo restores both the original wording and the open suggestion.

Annotations travel with the owning Markdown as versioned JSON HTML comments.
Stable block anchors are reused/created only when selection bytes remain intact;
other ranges use conservative quote/context matching. Missing, duplicate or changed
targets disable acceptance and require explicit reattachment. A changed note while
composing cannot be overwritten by a stale draft. Unknown metadata fields survive;
unsupported versions and fenced examples remain editable literal source.
This is offline local review, without shared threads, live collaboration or an
automatic wording service. Review metadata is hidden in Rich/Read, visible in Source.


### Structured writing tools (2026-10-10, EDT-02/03/04/10/12/15)

Writing tools provides a searchable section planner, footnote manager and linked
section connections. Whole-section movement includes subordinate headings and
preserves authored source, existing anchors and LF/CRLF. Heading edits change
only the heading. Section focus and outline-only planning are per-pane view state,
with an accessible Show full document recovery. Missing/duplicate restored targets
never hide content permanently or rewrite it. Outline planning supports heading
creation, rename, level changes, movement and deletion without displaying prose.

Typing-format controls expose on/off/mixed selection state and continue chosen
marks into the next paragraph. Mixed cross-block formatting covers supported
paragraphs/headings/lists; code and unsupported blocks remain source-preserving.
Rich/Source/Split transfer source selection endpoints, including reversed ranges.
Specialized table/code/equation caret parity remains a separate acceptance limit.
For a paragraph containing inline math, Edit paragraph continuously switches to
one native text field with authored TeX and editable rendered equation previews;
Rendered equations restores the segmented view. This view state and selection
survive mode changes when the source fingerprint is unchanged; changed source
falls back safely. This is a deliberate editing mode, not a claim of continuous native selection through rendered math widgets.

Click supported footnote markers in Rich to edit their definition, or use the
Footnotes manager from any Markdown mode. The manager diagnoses missing/unused
and duplicate definitions, navigates exact reference/definition ranges, edits
multiline definitions using indented continuation lines and renames identifiers
atomically. IDs are whitespace/bracket/colon-free and at most 100 characters;
large definitions are capped at 100,000 characters. Duplicate definitions require
explicit Source repair. Footnote definitions are reserved from shortcut-link
resolution. Literal code/comments/frontmatter and linked embed fallback examples
are excluded from reference edits. All edits use normal history/save boundaries;
stale source/owners, read-only objects and ambiguous identifiers are not overwritten.

Connections displays incoming/outgoing supported live section references and
saved fallback excerpts for impact review. Renaming/deleting a used section asks
for impact review before applying. Existing block anchors survive rename/moves;
heading-name references may need explicit repair after rename. Incoming/outgoing
repair invokes the normal section picker and validates the host source before
saving. It never silently changes another reference or removes its underlying
object. Missing sources retain their readable fallback; unresolved forms stay
editable in Source.

## Shared live object cards — 2026-10-13

Rich and Read use shared source cards for non-Canvas object embeds: current title,
kind, available context/status, bounded text/image preview and source actions.
Task checkboxes edit the original task when interaction is enabled. Supported
saved views expose current members; Canvas previews keep the existing spatial
engine. No recursive rich-card renderer or new content owner is introduced.

Copy live card and Use elsewhere retain stable object identity. Optional precise
URL fragments on object blocks survive note/Canvas clipboard transfers, including
PDF pages, headings, block IDs and unknown future fragments. Open beside/new tab
retains the location; Show backlinks opens the referenced object's Connections.
Missing/ambiguous precise sections show an explicit warning without substituting
unrelated prose. Opening the source still allows deliberate review. Image reads
retry and invalidate on attachment-source revision; large images with recorded
byte length over 16 MiB use source navigation rather than a card thumbnail.

## Document Checks and deliberate link repair — 2026-10-14

Writing tools → Document Checks inspects the current Markdown snapshot and groups
findings into Links, Footnotes and Structure, with line locations and 30-row pages.
It identifies missing/ambiguous wiki targets, missing/unused/duplicate footnote
definitions, repeated heading titles and skipped heading levels. Existing parsers
keep code/frontmatter/comments literal and preserve CRLF/UTF-16 source offsets.
Clicking a finding opens Source, reveals and selects the authored range. If the
note or Vault changed while the inspector was open, navigation refuses stale ranges.
Standalone editors retain footnote/structure checks and explain unavailable link
coverage. Findings are review hints, not grammar judgments or complete validation.

Writable Vault notes offer Choose a source for this link. The existing universal
picker previews candidate objects; applying retains the written label and exact
page/section-fragment spelling and changes only that mention with normal undo/
autosave/history. Cancellation changes nothing. Changed source/Vault, active IME
composition, read-only notes and unavailable targets prevent the edit. The fragment
is retained rather than guessed to match a different source; inspect that location
after repairing. No external URL checks, automatic cleanup or storage migration.

## Block formats and BTW callouts — 2026-10-14

Format block formats the current supported block or selected complete blocks as
paragraphs, six heading levels, bullet/numbered/checklists, quotes or Note/BTW/Tip/
Warning callouts. The searchable chooser retains inline source, links, checklist
completion and stable block anchors, uses normal undo/history and rejects stale
source/Vault changes. Structured/unknown/aligned blocks and nested list/quote levels
keep their existing editing tools. Multi-line prose cannot silently become several
headings. Adjacent quote content must be selected together for callout conversion.

Insert and slash commands also offer BTW block, displayed as By the way in Rich.
Empty BTW blocks provide an editing hint rather than storing a sample sentence.
Callout options edit the title, switch types, make a callout collapsible or choose
expanded/collapsed defaults. `> [!BTW]+ Title` starts expanded; `> [!BTW]- Title`
starts collapsed. Controls preserve body quoting, label/type spelling and CRLF.
Clicking expand/collapse changes only the view; default controls deliberately
change the marker with normal undo. Unknown alphabetic callout types retain source.
Read-mode search temporarily reveals folded bodies so they remain discoverable.
Unsupported readers/exporters retain ordinary blockquote contents; no content is
removed because it was folded. Compact command chrome scrolls rather than removing
actions, and the cursor-position control keeps full details in its tooltip.

## Shared Math Lab — 2026-10-14

Math Lab opens from the note header, Writing tools/Insert, rich LaTeX toolbar and
Equation Studio. It runs offline: bounded arithmetic with named numeric variables,
pi/e and real trigonometric/exponential/logarithmic functions; sampled function
plots with explicit windows; function values, central-difference derivatives,
Simpson integrals and bracketed roots; 1×1–6×6 real transpose/determinant/inverse/
product/system solving. Presets cover force, jump height, vector length and plots.
Twenty new reusable templates cover calculus, linear algebra, probability and game
geometry, shared by both symbol palettes and the lab. All inputs remain editable.

Insert result deliberately creates ordinary display TeX with named parameter values;
Markdown also retains the calculation description and approximation details.
LaTeX rich insertion uses the document insertion boundary before end{document}.
Equation Studio inserts into the captured formula selection. Calculations alone
change no document; changing inputs invalidates a previous result. Note/Vault/source/
mode, read-only and composition guards protect application, with normal undo/history.
The dialog scrolls at narrow widths and enlarged text; errors and results announce.

These are real floating-point tools, not symbolic algebra or proof. Trig uses radians;
calculus error figures are refinement estimates, not guaranteed bounds. Roots require
a sign change and satisfactory residual; singularities/oscillation can defeat samples.
Expressions are bounded to 4,096 characters/512 nodes/64 recursive parse levels and
12 variables. Matrix cells must be finite and rectangular; inverse/solve refuse
singular or severely ill-conditioned matrices. No arbitrary code or network execution.
Numeric results stay ordinary TeX. Plot insertion is extended by the live recipe
behavior below; LaTeX keeps equation snapshots and Canvas keeps editable strokes.
No new attachment or workspace object schema.

The math dialog keeps its content and title scrollable with an on-screen keyboard
and enlarged text; Copy LaTeX sits beside the result to leave primary footer space
for Cancel/Insert. Search and math command chrome retain a bounded scroll region
when Find/Replace is open. Derivatives refuse obvious sampled corners/jumps whose
one-sided slope disagreement fails to shrink; this remains a numerical diagnostic.

## Live mathematical plots and value tables — 2026-10-14

Math Lab Plot now inserts a readable orbit-plot fenced JSON recipe into Markdown.
Rich/Read/Split recreate the graph offline from formulas, named parameters and
ranges. Edit plot opens the shared Math Lab with these settings, preserving unknown
metadata and fence/line-ending spelling on application. Source editing remains
available; repairing raw JSON does not hide the code field until Show plot. Read-only
plots expose inspection/copy/export but no edit actions. Stale note/Vault/source/mode,
read-only changes and composition prevent application with normal undo/history.

Up to four single-line function expressions can be compared. Legends, axis values,
pointer/tap inspection and a keyboard-accessible inspector slider expose numeric
values. A 21-row table is available in each plot, including valid values outside
the visible y range. Invalid real domains appear as undefined, never zero. Copy
values uses TSV and full floating-point precision without display-style exponent
spaces; Math Lab exports CSV/SVG through existing local platform adapters. Table
operation creates an 11-row ordinary TeX snapshot for notes/LaTeX/Canvas, with
consistent 11-row data copy/export. Single-expression tools refuse comparison
input rather than silently multiply the separate lines. Hidden y/title fields do
not prevent table calculation. Ten additional algebra/geometry/physics templates
bring the shared new Math Lab template set to 30. Common π/×/÷/− inputs work in
numeric expressions; authored plot strings remain unchanged. Trig remains radians.

Graph source/samples are cached per unchanged widget; hover and ordinary surrounding
text edits do not reparse/resample the same graph. Rich find reveals and selects the
native JSON source range; Read search reveals source transiently and restores the
graph when closed. Inspecting/searching/expanding tables changes no authored source.
Other Markdown tools and current publication exports retain the complete fenced
recipe as readable code; use Export SVG for a standalone vector figure. There is
no symbolic CAS, external execution, networking or second spatial engine. Samples
may miss discontinuities/oscillation; outputs remain numerical approximations.

## Writing surfaces — 2026-10-14

The Writing surface button (Alt+T with the editor focused) offers Orbit, Pixel
notebook, Bound book, CRT terminal, Retro desktop and Command prompt designs.
Plain, lined, math-grid and dotted paper can be combined with any design; spacing
is adjustable from 20–64 logical pixels. Vector leather/binding/page-edge/bezel and
desktop frames surround actual editable text. These are reference-inspired original
drawings, not bundled screenshots or exact reproductions of another application's
controls. Retro title bars display the real note title rather than fake buttons.

Themed writing can use bundled Tiny5, Space Mono or Crimson Text typography, or
retain the user's font by disabling Design typography. Picking a custom font from
the existing menu disables the design font override. Sizes, line height, native
caret/selection/clipboard and undo remain existing editor behavior. Colors also
scope the toolbar, modes, selection and supported content cards, without changing
the app-wide theme. Rich, Source, Read and Split use the same surface; LaTeX retains
its existing appearance. Read-only notes allow presentation changes but no content
writes. Background paper is a viewport decoration, not a paginated document or a
guarantee that rich blocks align with every rule.

Choosing a themed desk from Orbit starts Quiet writing: appearance/mode controls,
title and the writing area, with Show editor tools restoring the full interface.
Quiet writing is also independently configurable. Mode controls take priority in
the full header so they remain reachable while Find constrains the chrome. Apply
and Cancel preview choices; Reset restores Orbit/plain/default-font behavior after
Apply. A picker opened for a different note/Vault cannot apply to its replacement.

Presentation is stored in device-local pane/note view state; no Markdown,
frontmatter, object properties, relations, history or attachments are rewritten.
Malformed/future preferences safely display Orbit; their raw data survives unrelated
view updates. Explicit changes keep unfamiliar preference fields. These preferences
remain device-local and do not share a design across devices. As of 2026-10-25,
PDF publishing captures the active design by default, with a plain-document
opt-out; HTML/Word continue using document styles. See the editor-design PDF
section in [portability](import-export-and-portability.md).
Static decorative layers never intercept input; high-contrast mode removes CRT
scanlines/vignette. There is no flicker, blur over text or background animation.
Themes are cached while typing; background painting sits in its own repaint boundary.

### Personal photo backgrounds — 2026-10-14

Writing surface can choose/replace a local PNG, JPEG or WebP background, position
it horizontally/vertically, fill-and-crop or fit the whole picture, and set its
intensity. A protected Reading sheet is the default: strong imagery can appear
around a quiet central writing area. Without a sheet, the effective intensity is
conservatively capped against solid white/black images for the theme's normal,
secondary and link ink. Existing low-contrast custom colors are not made worse;
this is a color bound, not per-photo content analysis. Paper patterns still work
on the sheet. High contrast hides photos and retains the stored choice.

Selection/position changes preview without saving. Apply saves the bounded copy
before updating the pane recipe; Cancel leaves the prior appearance intact. Failed
decode/storage/quota or a stale note/Vault keeps a useful error and does not change
authored source. Remove photo and Reset clear the pane reference, not other panes'
photos. Missing/corrupt caches show a plain fallback with Retry background and a
route to replace/remove through Writing surface. Read-only Vaults disable importing
new photo bytes; existing presentation still renders. No network URLs are loaded.

Inputs are bounded to 16 MiB, 40 megapixels and 10,000 px per dimension. The first
frame is normalized to a static PNG, at most 1,600 px per side and 2 MiB; progressively
smaller copies are attempted for detailed images. Embedded source metadata is not
copied, the original file is untouched, and animations are not played. Bytes live
separately under existing .orbit/device state; session JSON contains only the recipe.
They are excluded from authored-content sync, ordinary document exports and new
Universal Objects. Browser storage can refuse quota; the previous setting remains.
Unused device copies are retained rather than deleting an image referenced by
another pane. No automatic retention cleanup or shared-photo portability claim.
Image loads are cached per photo/Vault; changes during typing do not reread files,
and late responses from a replaced Vault/selection are refused. Text remains native
and unblurred; no image layer intercepts input or changes text/undo/history.
