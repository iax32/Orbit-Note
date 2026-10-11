# Search, links, backlinks and context graph

Status: partially implemented; requirements below remain the broader target.
Stage: M2 for search/links; M5 for graph and richer relations.
Sources: S01, S03, S04, S08 in the [source map](../product/conversation-extraction.md).
Architecture: [model](../architecture/universal-object-model.md),
[local indexing](../architecture/overview.md).

## Delivered discovery behavior — 2026-09-30

The subsequent architectural pass adds shared rich search results and precise
editable-source/Canvas-element navigation, lazy block links, live Note-block cards
and exact backlink locations. Name rank is shared with Quick Switcher. See the
[architecture/evidence](../tasks/architecture-composition-2026-09-30.md) for current
candidate limits, background execution, compatibility and remaining PDF indexing.

Universal Search shows loading, failure with retry, and empty states separately.
Type/project/folder/tag/match/completion filters refine the complete projected
result set before sorting and 50-row pagination. Results expose readable kind,
project and folder context rather than internal identifiers.

## PDF search delivery — 2026-10-08

Workspace search includes completed text-based PDF page indexes alongside notes,
tasks, names/metadata and Canvas elements. PDF rows show page-level excerpts and
open the exact verified text range, including when the file is already open.
Index details expose per-file page progress, failure reasons, missing/no-text pages,
partial scan coverage, pause/resume and retry. Results update as background work
finishes; changed attachments cannot retain navigable stale text ranges.
Native page text caches survive restart and rebuild if lost or invalid. Browser
cache is session-only. Complete filtering fixes the former first-100 cutoff;
collection/Space scopes and OCR remain future work. This delivers LNK-01/08/12 and
the type/project/folder subset of LNK-02, not the full broader specification.
See [search architecture](../architecture/search.md) for bounds and execution,
and [current task](../tasks/current.md) for validation evidence.

## Other delivered discovery surfaces

Live linked note sections (2026-10-10, LNK-10/EDT-08) use stable note IDs and
explicit block anchors, including heading-section scopes. An editor picker searches
and previews fragments; Rich/Read render current source text and open the precise
anchor. Missing/duplicate/cyclic sources show the saved Markdown fallback rather
than guessing. Rich removes the reference or detaches it into an independent copy.
This delivery does not add section-specific backlink/impact reporting; metadata
references are not yet indexed by the ordinary wiki-link backlink parser.

Quick Switcher (Ctrl+O, with Ctrl+E retained) ranks exact title/alias, prefix,
substring, context tokens and conservative fuzzy title matches. Titles and context
wrap into variable-height lazy rows; keyboard selection reveals measured geometry,
including the beginning of rows taller than the viewport. Query/clear resets
selection and scroll position. Search, accessible Clear, and Close remain above
scrolling results/help. Rows expose button/selected semantics and support Tab and
Space/Enter activation. Results are reused while query and object list stay
unchanged. PDF, generic file and LaTeX labels are distinct.
No link format, object identity or index authority changes. See the
[coherence audit](../tasks/product-coherence-2026-09-29.md) for remaining gaps.

The note link picker searches titles/aliases case-insensitively and sorts by title,
with stable ID as the same-title tie-breaker. Full titles, IDs, and aliases wrap
in lazy rows; the ID distinguishes otherwise identical titles. Arrow keys select
and reveal measured rows, Enter chooses the selected target even with multiple
matches, and Tab/Space can activate rows. Query/clear resets selection and scroll;
empty matches cannot choose a target. The scrolling Orbit dialog keeps Cancel
reachable at enlarged text sizes and keyboard insets. The returned target and
existing stable-ID link insertion/repair contracts are unchanged.

## Purpose and workflow

A user searches “graph theory,” finds notes, tasks and files with relevant context,
opens a concept and discovers where it was referenced. A later graph can distinguish
“uses,” “part of,” or “written by” relationships rather than show every edge alike.

## Requirements

| ID | Observable behavior |
|---|---|
| LNK-01 | Universal local search finds supported object titles/content and indexed metadata, groups or filters results by type, and opens the right object/location. |
| LNK-02 | Search can scope to the workspace, active collection or Space; it identifies its current scope and handles archived/trash content explicitly. |
| LNK-03 | Wiki links support completion and navigation; ordinary Markdown links remain useful. Aliases and ambiguous titles resolve visibly rather than selecting a random target. |
| LNK-04 | Backlinks show referencing sources and useful surrounding text; unresolved links are discoverable and can be repaired without discarding the written target. |
| LNK-05 | Typed relations support meaningful directed edges such as Project → uses → Technology, Book → written by → Person, or Task → part of → Project. |
| LNK-06 | A local graph focuses on an object with configurable depth/types; a global graph can inspect the workspace with filtering, selection and navigation. |
| LNK-07 | Semantic connectors and relation views refer to the same relation identities; decorative arrows do not create semantic edges by default. |
| LNK-08 | Search indexes rebuild from durable sources and catch up with external edits; users can distinguish no matches from indexing failure/incompleteness. |
| LNK-09 | Later contextual search may use handwriting/OCR/transcription or optional semantic retrieval, with source attribution and quality limits. |
| LNK-10 | Block references and transclusion/live embeds address stable fragments and preserve a readable fallback when an anchor is missing or unsupported. |
| LNK-11 | Graph clustering, semantic zoom and saved graph views serve project dependencies, study concepts, team responsibilities and research sources; technical call graphs use explicit source/adapter provenance. |
| LNK-12 | Ctrl+F searches the active document/view; Universal Search spans supported notes, tasks, projects, people, PDFs, files, highlights, decisions and canvases with visible scope. |
| LNK-13 | A resizable live graph widget can appear on Canvas; dragging a node creates a normal object placement, while “Expand graph into Canvas” previews reversible placement/connector changes. |
| LNK-14 | Contextual ranking and Smart Connections-style discovery expose why a result/link was suggested; AI missing-link suggestions remain reviewable, and graph use stays optional. |

## Data and integration

Parsed text links/backlinks are derived from source text. Explicit semantic relations
are durable user-created knowledge. Deleting a derived index row cannot remove a
link from the note. Object IDs own established relationships; display titles and
paths can change. Newly typed unresolved names retain the original text until
resolution is deliberate. Search and command execution may share a surface but
must clearly distinguish an object result from a command with side effects.

## States and edge cases

An index rebuilding in the background reports partial coverage. Queries containing
punctuation or unsupported syntax fail safely and preserve input. Missing/deleted
targets have repair/restore affordances rather than navigation loops. Large graphs
use bounded layouts, filtered neighborhoods and simplified detail; a global graph
must not block typing elsewhere. Touch/keyboard users need a non-spatial list of
connections and a way to traverse it.

## Acceptance scenarios

- LNK-01/08: import a folder, rebuild the index, edit a file externally and find
  its updated content locally with the network disabled.
- LNK-03/04: create two equal titles; choose the intended target, rename it and
  verify backlink identity/context remain correct.
- LNK-05/07: create a labelled semantic board connector and observe its relation
  in the graph; a decorative connector produces no extra knowledge edge.
- LNK-06: use a large graph while editing another pane and record responsiveness.

The S10 brief names additional relation examples: `depends on`, `references`,
`assigned to` and `supports`, alongside `uses`. They are semantic schemas, not
decorative edge styles. A saved graph view and an expanded spatial arrangement
retain references to the same objects; a generated graph layout cannot overwrite
the user's carefully arranged Canvas positions without review.

## Delivery

Deliver literal local search, link completion and backlinks before a complex
graph. Ranking details, query syntax, anchor syntax and graph layout algorithm are
implementation decisions to evaluate in their tasks.

## Incremental delivery (2026-09-10)

Native FTS5 literal substring search and bounded large-graph layout are implemented subsets. See [ADR-0012](../adr/0012-fts5-derived-search.md) and the [current batch](../planning/audit-polish-batch.md); saved/typed relation graphs remain future work.
