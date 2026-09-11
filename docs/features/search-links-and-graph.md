# Search, links, backlinks and context graph

Status: planned. Stage: M2 for search/links; M5 for graph and richer relations.
Sources: S01, S03, S04, S08 in the [source map](../product/conversation-extraction.md).
Architecture: [model](../architecture/universal-object-model.md),
[local indexing](../architecture/overview.md).

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
