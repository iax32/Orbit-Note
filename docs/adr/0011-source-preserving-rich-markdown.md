# ADR-0011 — Source-preserving Rich Markdown editing

Status: accepted, 2026-09-10. Extends ADR-0004 and ADR-0009; no storage migration.

## Context

The owner requires directly editable formatted documents, visual tables and math.
Markdown must remain portable and authoritative. A rich editor that serializes
its whole internal document could discard unfamiliar syntax, rewrite frontmatter,
change wiki targets or normalize unrelated paragraphs. Source/Read already work.

## Decision

Use the implemented transient `MarkdownDocument` projection over original source
slices. Recognized blocks own their exact prefix/content/suffix; ordinary inline
editing maps visible UTF-16 positions to source splices. Structure commands reparse
the resulting source and reuse unaffected blocks. Unsupported blocks retain an
editable source fallback. Merely rendering or switching modes never serializes
replacement Markdown. No second persisted rich-document schema is introduced.

Rich fields and Source share one bounded splice history per open NoteEditor:
200 operations / 4 Mi changed UTF-16 units, retaining at least one operation.
Undo/redo is session-local; file recovery remains the application/storage layer's
responsibility. External replacement resets stale history. Existing save/conflict
commands, Universal Object UUIDs and metadata link bindings remain authoritative.

Visual table edits may canonicalize only the explicitly edited table. Rectangular
pipe tables retain alignment and line-ending style; malformed or oversized tables
remain source-editable. This is not a database object or a spreadsheet engine.

Math grammar: `$...$` for one-line inline equations, `$$...$$` or standalone `$$`
lines for display equations. Escaped dollars and code spans are not equations.
Local `flutter_math_fork` renders supported TeX, with source fallback on errors;
editing an equation opens a local source-and-preview dialog. There is no remote
renderer or LaTeX executable. `highlight` colors code locally; Copy Code copies
only the code content. Code blocks are never executed.

## Alternatives and consequences

- A preview-only Rich mode fails the requested direct-editing workflow.
- A separate rich document/HTML/Delta as durable authority risks round-trip loss
  and another storage model. It is not adopted.
- A full CommonMark/Word editing engine is beyond this bounded implementation.
  This projection needs explicit subset tests and visible source fallbacks.

Block fields retain controllers and reuse unaffected widgets, but the document
layout is not virtualized. Inline equations currently divide prose into editable
segments; arbitrary selections across blocks/embedded widgets are not represented
as one native text selection. These are delivery limitations, not permission to
truncate content or claim complete Word/Typora parity. See CURRENT status.

## Validation

Require exact no-edit round-trips, isolated edit/save/reopen fixtures, formatting
boundaries, Enter/list/Tab tests, visual table undo, code copy, valid/invalid TeX,
mode switching and cross-mode undo. Keep existing storage/conflict/UI regressions.
Run analysis, all tests and a Windows release build before declaring a batch done.
Model timings do not establish release frame rate or large-document UI capacity.

Primary package references: [flutter_math_fork](https://pub.dev/packages/flutter_math_fork)
and [highlight](https://pub.dev/packages/highlight). Versions are pinned by the
repository lockfile; neither changes canonical note storage.
