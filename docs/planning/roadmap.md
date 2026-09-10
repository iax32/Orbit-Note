# Roadmap

This is sequencing, not authorization to implement everything. The single
[current task](../tasks/current.md) defines active scope. Maintain compatibility
throughout; bring Android/iOS/web features to parity through explicit platform tasks.

| Milestone | Outcome / exit gate |
|---|---|
| **M0 — Foundation** | Clean Flutter project and docs; adaptive Home/Inbox shell using Riverpod; format/analyze/widget tests; Windows build and narrow-layout coverage. No persistence yet. |
| M1 — Durable local notes | Stable note/workspace identities, create/open workspace, Markdown CRUD, Drift index, reopen, save errors/recovery, trash/restore and complete export for implemented content. A restart and index rebuild preserve notes. |
| M2 — Connected knowledge | Markdown editing/preview, search, wiki links/backlinks, tags, basic attachments, collection navigation, checkbox aggregation, basic tabs/splits and undo. External file edits do not silently lose content. |
| M3 — Spatial boards | Shared engine with camera/index, existing-object cards, selection/drag/resize, connectors/groups and gesture undo; documented board format and representative performance/reload tests. |
| M4 — Freeform and ink | Same engine supports page presets, vector pen/highlighter, lasso/stroke eraser and image/PDF annotation adapters; faithful editable export/reload and device testing. |
| M5 — Structured and personal workspace | Typed properties/custom types, table/Kanban/calendar/gallery/timeline, graph, live view embeds, advanced docking, inspector, Spaces, saved layouts/themes and reset. Each view edits the same object. |
| M6 — Optional sync | Versioned protocol ADR, tested outbox/conflicts/deletes, attachment transfer, hosted or self-hosted adapter, offline operation and restore. No silent last-write-wins for irreplaceable content. |
| M7 — Extensibility | Real capability use cases, versioned plugin API, runtime isolation proof, permissions, safe mode, local API/automation boundaries and portability tests. |
| M8 — Optional AI and context | Scoped retrieval, source-grounded answers, reviewed/stale-safe change sets and recovery; then knowledge compiler and resurfacing experiments. Manual context restoration can precede AI in M2–M5. |

Collaborative editing, CRDT/OT, workspace branches, portals, executable notes and
advanced recognition are post-foundation explorations, each needing evidence and
a small approved task. They must not delay a usable local editor and board.

## Cross-cutting gates

For each new content type: serialization round-trip, undo/recovery, index rebuild
and complete export. For every customization surface: accessible reset/recovery.
For storage/network/plugin/AI changes: failure and permission boundary tests.
Performance numbers remain goals until measured on named hardware/builds.

Before first public distribution, select the open-source license, confirm release
identifiers/ownership, replace starter icons, and configure signing. No public
hosting, account service, or paid provider is required for M0/M1.

## Release boundary

The [canonical backlog](feature-backlog.md) assigns each requirement to Foundation,
Orbit 1.0 candidate, Post-1.0 or Experimental/future. A milestone is a capability
sequence, not a requirement to finish every idea before advancing.

The 1.0 candidate is a coherent local workspace: durable Markdown, capture/search,
links/attachments, desktop essentials, useful shared Canvas/basic ink, a small set
of structured task/views and manual continuation. Choose and verify a release cut;
candidate does not mean every candidate item is mandatory. Compatibility, recovery,
export and accessible input accompany every feature included in that cut.

Optional sync, shared collaboration, AI, plugin execution, advanced importers,
specialist integrations, Gantt/map/formulas and elaborate customization follow the
polished local core. CRDT editing, portals, branching, recognition and reverse
engineering integrations remain experimental. See [prerequisites](open-questions.md).
