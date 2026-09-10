# Feature catalog

This catalog preserves the product conversation without assigning all of it to
the next implementation. **Planned** means intended capability; **exploratory**
means an idea to validate. See [implementation status](../planning/implementation-status.md) for implemented subsets.
Milestone numbers are sequencing, not dates; see the [roadmap](../planning/roadmap.md).

| Area | Capabilities | Target stage (full capability) |
|---|---|---|
| Foundation | Branded Flutter runners, focused docs, validation; then adaptive shell and Riverpod | M0 foundation present |
| Capture and writing | Inbox, quick note, journal/daily notes, Markdown editing/preview, lists, checkboxes, code blocks, links, attachments | M1–M2, planned |
| Local workspace | Create/open workspace, CRUD, rename/move/trash/restore, atomic saves, external file reconciliation, backup/export | M1, planned |
| Organization | Folders, notebook/section hierarchy, tags, aliases, manual/smart collections, custom properties and object types | M2–M5, planned |
| Linked knowledge | Wiki links, standard links, embeds, autocomplete, backlinks, unresolved links, typed relations, local/global graph | M2–M5, planned |
| Search and commands | Local full-text search, universal command palette, keyboard shortcuts, scoped filters | M2, planned |
| Structured views | List, table, Kanban, calendar, gallery, timeline and saved queries over the same objects; formulas later | M5, planned |
| Tasks and planning | Note checkboxes, standalone tasks, due dates, priorities, projects, recurring tasks, date-based views | M2 basic; M5 advanced, planned |
| Board | Pan/zoom, existing object cards, text, images, files, shapes, arrows, groups, frames, columns, selection, resize, layers, snapping, undo | M3, planned |
| Freeform and ink | Click-to-write, finite/extendable pages, pen/highlighter, pressure/tilt where available, lasso, stroke eraser, backgrounds, shared engine | M4, planned |
| Advanced spatial | Live views on canvas, compact/card/preview modes, auto-layout, mind maps, semantic zoom, portals/nested boards, document↔board conversion | M5+, planned; conversion/portals exploratory |
| Advanced drawing | Segment eraser, handwriting recognition, optional ink-to-text/object and shape conversion | M4+, exploratory |
| Files and research | Ordinary attachments, image/PDF preview, linked highlights and annotations, regions, OCR, source-code highlighting, audio/video and voice capture | M2 files; M4 annotations; richer tools later |
| Portability | Markdown folders/Obsidian, CSV and HTML import; later Notion exports, OneNote exports, ENEX, Joplin, Logseq, Apple Notes/Keep where export permits | M1 export foundation; later importers, planned |
| Export | Complete open workspace; Markdown/JSON/CSV, HTML/PDF; later DOCX; vector ink SVG plus PNG/PDF renderings | Incremental with each content type |
| Desktop shell | Activity rail, contextual sidebar, tabs/splits, optional inspector, command palette, focus/Zen, status and recoverable layout | M0 basic; M5 advanced, planned |
| Customization | Resizable/dockable panels, saved layouts, semantic theme tokens, fonts/density, keybinding/menu editors, dashboards, contextual Spaces | M5+, planned |
| Multi-device UX | Adaptive phone navigation, tablet pen/workspace, desktop multi-window/multi-monitor, global quick capture, share sheets/browser clipper | Compatibility throughout; integrations later |
| Local-first sync | Durable change queue, retries, conflict review, attachment transfer, account optional, hosted Supabase or self-hosted/custom adapter | M6, planned |
| Collaboration | Shared workspaces, roles, presence, comments; later concurrent text/ink with an evaluated merge protocol | After M6, exploratory |
| Plugins and APIs | Commands, views, panels, object types, tools, import/export, themes, automations; permissioned local API/CLI and event subscriptions | M7, planned |
| Ecosystem ideas | Flashcards/Anki, Pomodoro, habits, budgets, citations/Zotero, LaTeX, Git/GitHub, RSS, music, weather, language learning, code runner | Plugin examples, not core commitments |
| AI assistance | Workspace-grounded Q&A with citations, summaries, tasks from notes, inbox organization, suggested links, typed query/view generation | M8, planned; optional local/BYO remote models |
| Knowledge compiler | Duplicate/concept suggestions, contradiction detection, knowledge health, orphan/broken link checks, resurfacing and spaced review | M8+, exploratory; deterministic checks can precede AI |
| Context and memory | Capture provenance/“why saved,” decision and assumption objects, context inspector, work sessions, “continue where I left off,” session summaries | M5–M8, planned incrementally |
| History | Command undo/redo, revisions, snapshots, workspace/knowledge timeline, AI before/after review; branches and selective historical reversal | Durability starts M1; time-machine/branches later exploratory |
| Living/executable notes | Trigger-condition-action rules, event bus, smart pages, calculations, charts, queries, scripts/API blocks | M7+, exploratory with permission and execution boundaries |

Universal object types eventually cover notes, tasks, projects, people, concepts,
bookmarks, files/images/PDFs, events, canvases, drawings, code snippets, decisions,
assumptions, sessions, collections, and user-defined types. Introduce only a type
needed by an approved task; a universal model does not require an empty class for
every possibility.

Import/export must disclose fidelity limits and preserve originals. Attaching an
arbitrary file is distinct from rendering or executing it. Competitive references
describe desired capabilities, not promises to match proprietary formats exactly.

## Expanded product coverage

This catalog is a discovery summary. The [spec map](../features/README.md) owns
detailed behavior; the [single backlog](../planning/feature-backlog.md) owns the
four release classes and dependencies, superseding coarse stage summaries above.

| Area | Added or clarified behavior | Detailed specification |
|---|---|---|
| Desktop essentials | Rich clipboard, screenshot paste, contextual drop, shared image ownership, native input and recovery | [DES](../features/desktop-interactions.md) |
| Universal Canvas | Mixed ink/cards/PDFs/diagrams/live views; compatible presets and scalable rendering | [CAN](../features/spatial-boards.md) |
| Calendar | Local/project events and linked context; shared/external calendars later | [EVT](../features/calendar-and-events.md) |
| Continuity | Continue Session/Writing/Reading, Where Was I, per-view restoration and recorded context | [CTX](../features/home-and-work-sessions.md) |
| Research | PDF viewer, anchored highlights as objects, citation metadata and original preservation | [FILE](../features/attachments-and-research.md) |
| Study | Courses, Cornell templates, concept understanding and study context | [STUDY](../features/study-and-university.md) |
| Development | Snippets, bugs, revision-aware references, journals and technical context | [DEV](../features/software-development.md) |
| Reverse engineering | Optional binary/address/finding/hypothesis schemas and specialist connectors | [REV](../features/reverse-engineering.md) |
| Game/team work | GDD, assets, levels/mechanics, playtests and contextual project tracking | [GAME](../features/game-development-and-teams.md) |
| Compatibility | Versioned formats, migration backup, old fixtures, unknown-field retention | [COMP](../architecture/compatibility-and-migrations.md) |
| Visual/motion | Calm graphite/violet direction, progressive disclosure, Normal/Reduced/Off | [Design](../design/visual-design.md), [MOT](../design/motion.md) |

Editor, task, search/graph, Smart View, AI, sync and extension requirements are
expanded in their existing specs rather than separate competing feature lists.
