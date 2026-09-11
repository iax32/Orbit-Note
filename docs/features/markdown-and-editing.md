# Markdown and document editing

Status: product requirements; implemented subsets and limits are recorded in
[CURRENT status](../planning/implementation-status.md). Stage: M1–M2 and later.
Sources: S01 and S07 in the [source map](../product/conversation-extraction.md).
Architecture: [open formats](../architecture/storage-formats.md).

## Purpose and workflow

A user writes an ordinary Markdown note, inserts links and a checklist, saves it,
and can continue in another text editor. Orbit Note can render richer linked content
without making the underlying document unreadable. The first editor should favor
reliable text input and save behavior over an ambitious custom block engine.

## Requirements

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

Rich formatting escape, block action menu and academic math-grid subset are tracked in the [audit polish report](../planning/audit-polish-batch.md). Cross-block selection is not complete. Grid edits emit standard TeX; no document database is introduced.

## Delivered Notes interaction refinement — 2026-09-11

Desktop paragraph insertion and block-action menus appear on hover or keyboard
focus; touch and accessible-navigation modes keep controls visible. Hovering alone
never changes the source. Reduced gutter/control heights remove excess vertical
spacing, while the document remains centered. The formatting bar sizes to its
contents at the left and scrolls horizontally when the pane is narrow.

PDF attachments inserted now use stable file-object wiki references. Standalone
legacy Markdown PDF links retain their source and expose an Open PDF action in
Rich mode. PDF UUID page anchors survive Rich/Read navigation. Cross-block native
selection and drag reordering are still unfinished; this is not full Notion parity.
