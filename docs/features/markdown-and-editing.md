# Markdown and document editing

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
