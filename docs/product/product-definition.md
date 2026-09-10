# Orbit Note — full product definition

Status: product intent, expanded from the source conversation and owner's
2026-09-08 product brief.
The local core is implemented in bounded subsets; see [implementation status](../planning/implementation-status.md). Read the [vision](vision.md) for the short
version, [source map](conversation-extraction.md) for provenance, and
[feature specifications](../features/README.md) for behavior.

## What we are building

Orbit Note is a personal knowledge operating system: a local application where
people capture information, develop ideas, connect evidence, plan work, think
visually, write by hand, and resume their context later. “Operating system” means
a coherent, customizable environment with shared objects, commands, history and
extensions. It does not mean replacing Windows or becoming a general desktop OS.

Its fundamental unit is a **universal object**, not a page trapped inside one
feature. Its fundamental user experience is **one piece of knowledge, multiple
useful representations**. The same project can be read as a document, placed on a
board, listed in a table, shown by deadline in a calendar and connected to decisions
in a graph. Editing that project's status changes the underlying project everywhere.

Orbit Note draws on four complementary approaches discussed in the chat:

| Inspiration | Capability Orbit Note should offer | Integration requirement |
|---|---|---|
| Obsidian concepts | Readable Markdown, links, backlinks, graph, local files | Links connect the same objects used in planning and spatial views |
| OneNote concepts | Notebooks/sections, click-to-write pages, handwriting and annotations | Freeform content uses the shared canvas/ink engine and links to objects |
| Milanote concepts | Visual boards, cards, images, columns, groups, arrows and moodboards | Cards reference existing objects; meaningful arrows can represent relations |
| Notion concepts | Properties, collections, tables, Kanban, calendar and embedded views | A record is an object; a database is a view over a collection |

These are desired concepts, not claims about current competing products or a
promise of exact proprietary format compatibility.

## The experience in one example

1. Capture “Need to understand conflict handling” into Inbox while offline.
2. Turn it into a task associated with a Language Learning App project.
3. Write an architecture note and link SQLite and Supabase concepts.
4. Place the project, task and note on an architecture board. Draw a labelled
   “uses” connection between the project and SQLite.
5. Open the same project in a table, change its deadline, and see the calendar
   update. Its board position does not change.
6. Import a research PDF, mark a passage and link that evidence to a decision.
7. Enter a project Space with the board, notes, tasks and references arranged
   for that work. Resume those views next time.
8. Ask optional AI to organize the remaining Inbox. Inspect proposed changes,
   accept a subset and undo them if they were unhelpful.
9. Export everything to readable files and documented structures without requiring
   an account, subscription, remote model or the original Orbit Note server.

This end-to-end integration is the product's test of coherence. A set of visually
similar screens with independent note/task/board copies would not satisfy it.

## Four modes of thinking

**Document** is linear writing: paragraphs, headings, lists, code, references and
embedded content. Markdown remains intelligible outside Orbit Note.

**Structured view** is comparison and planning: query existing objects, inspect
properties, group by status, arrange dates and save a reusable view.

**Infinite board** is spatial thinking: organize cards, files, drawings and live
views with geometry, grouping, arrows and progressively detailed zoom.

**Freeform page** is writing and drawing anywhere: type in positioned text regions,
paste images, annotate sources, use paper backgrounds and pen input. It is a
canvas preset, not an unrelated handwritten-file subsystem.

Switching a view changes presentation. Transforming content (for example a drawing
into a task or a document into an outline board) is an explicit operation that
preserves originals, explains interpretation and can be reversed.

## Knowledge should retain context

The long-term product should remember more than content. It should help answer:
Where did this come from? Why did I save it? Which project was it related to?
What evidence supported this decision? Which assumption is still unverified?
What changed? What was I doing when I stopped? What deserves attention now?

Provenance, decisions, assumptions, work sessions and history supply the evidence.
Contextual inspectors, timelines, resurfacing and optional AI supply presentations
or suggestions. The app must distinguish recorded facts from inferred explanations.
It should not invent a reason a user saved something.

## Ownership and freedom

Core use works locally without login. Markdown, normal attachment files and
documented JSON preserve the meaningful content. Drift/SQLite serves fast local
queries and operational state under the existing durability contract. Cloud sync
is an optional adapter; hosted Supabase, self-hosted infrastructure and alternative
providers must not become different object models.

Users can choose hierarchy, tags, collections, relations or spatial organization.
No automatic organization mode should force them to maintain every system. The
default remains calm; the interface can grow into a highly customized workspace
with movable panes, personal shortcuts, dashboards, themes and plugin views.
Recovery/reset remains reachable even after extensive customization.

## What success looks like

The same core serves personal note taking, university study, research, software
development, reverse engineering, game development and project management.
Optional presets supply appropriate types/templates/context; ordinary users do
not see specialist controls by default. Team workflows later add explicit sharing
and permissions without creating a second object model or a general chat product.
New versions should expand old workspaces through compatible formats and tested
migrations rather than forcing users to rebuild their knowledge.

- A newcomer can capture, save, reopen and find a note with little instruction.
- An experienced user can combine documents, boards, handwriting and planning
  without manually reconciling duplicate copies.
- A returning user can recover useful context and the next unresolved question.
- A contributor can implement one feature using a focused spec and stable boundaries.
- A departing user can take original content and meaningful structure with them.

Measured performance, reliability and usability criteria are in
[quality requirements](quality-requirements.md); these outcomes are goals, not
claims that the current starter already delivers them.

## Scope boundaries

The full vision is larger than the first usable release. Foundation builds a
small shell; the first durable product loop is capture → save → reopen → find →
link, then spatial boards. Rich properties, ink, customization, sync, extensions
and AI are delivered through later small tasks.

Workspace branches, portals, executable notes, recognition, spatial conversion,
and concurrent collaboration remain exploratory. Detailed behaviors in the feature
specs make those ideas reviewable; they do not silently select a runtime, editor,
CRDT, syntax or service. Open decisions have owners-by-milestone in
[open questions](../planning/open-questions.md).
