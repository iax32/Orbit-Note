# LaTeX document editing redesign — 2026-09-27

Owner request: replace the form-like LaTeX editor with a polished rich document
editor, familiar formatting and visual mathematics.

## Delivered scope

- Continuous document page, restrained typography, one horizontally scrollable
  formatting toolbar and quiet paragraph action menus. Removed colored block
  badges, boxed paragraph headers and repeated labelled Add Block buttons.
- LaTeX uses its document title rather than the duplicate note cover/title header.
  The file name remains available in breadcrumbs and the Explorer.
- Visual bold/italic/underline with selection formatting and keyboard shortcuts;
  heading styles and left/center/right paragraph alignment. Supported formatting
  commands are hidden by a temporary text projection, not a whole-document export.
- Display equations use the existing structured mathematics editor: fractions,
  roots, scripts, operators, symbols and templates remain editable in place.
  Equation controls appear for the focused equation rather than every equation.
- Inline dollar-delimited formulas render in unfocused paragraphs and open a
  structured equation dialog. Apply changes only that source range; Cancel
  preserves the original. Prose editing exposes inline delimiters for precise
  text editing. Enter splits a paragraph and focuses the next one.
- Symbol and matrix actions target the active rich equation or insert a new
  equation before the document end. They no longer use the source editor's stale
  selection in Rich mode. The palette is a single responsive dialog.
- Undo/redo use the document history supplied by NoteEditor. Paragraph insertion,
  reordering, deletion and explicit source editing remain accessible.
- Metadata edits replace the relevant command argument rather than reconstructing
  the entire preamble. Ordinary text edits keep existing block delimiters, custom
  macros and comments. Alignment uses ordinary TeX environments.
- Parser fixes preserve empty documents and final newlines, and prevent an
  adjacent end-of-document marker being included in editable prose.

## Limits

This is a document authoring surface, not a full TeX typesetting engine. Arbitrary
macros, lists and tabular source retain their existing
source-oriented fallback; full Word-style selection across multiple blocks is
not implemented. Table and figure controls remain available. No claim of exact
TeX pagination or universal package rendering is made.

## Validation

Focused controller/widget and existing LaTeX/math tests passed (29 tests).
New cases exercise nested formatting, selection replacement, source preservation,
insertion before the document end, alignment parsing and narrow large-text layout.
Follow-up validation on 2026-09-30: full suite passed (1,006 tests), analyzer clean.
The metadata test now scrolls the toolbar action into view before tapping it.
Native Windows review inspected the rich document with title, heading, prose,
inline/display mathematics and centered toolbar. Source-format and cross-block
selection limitations above still apply. Final production build evidence is in
[the coherence task](product-coherence-2026-09-29.md).

Next suggested task: continuous inline equation editing and cross-paragraph selection with
the same source-preservation guarantees.
