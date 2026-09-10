# Documentation update — 2026-09-08

Documentation-only expansion from the original product conversation and the
owner's detailed brief. Product code, platform configuration, dependencies, six
accepted ADRs and the ready/unimplemented M0-01 task remain unchanged.

## Changes

Added 38 documents (including this report) and updated 17 existing documents.
There are 24 feature specifications plus compatibility and motion contracts,
covering 264 unique requirements in one canonical backlog. AGENTS remains 2.7 KB.

New dedicated areas: desktop clipboard/drop/image quality, calendars/events,
study/university, developer knowledge, reverse engineering, game/team presets,
compatibility/migrations, visual design, motion, source traceability and delivery
prerequisites. Existing editor, objects, Canvas/ink, PDF/research, graphs, tasks,
Smart Views, continuity, AI, sync, plugins and portability coverage was expanded.

## Release classification

32 requirements are Foundation/required quality gates, 108 are Orbit 1.0
candidates, 108 are Post-1.0, and 16 are Experimental/future. These are grouped
requirements, not equal effort estimates or 264 implementation tasks. The
[backlog](feature-backlog.md) owns the exact classification and dependencies.

The 1.0 candidate emphasizes durable local Markdown, capture/search/links,
attachments and desktop essentials, shared Canvas/basic ink, selected structured
views/task planning and manual continuation. A candidate is not a mandatory
release promise. Sync, collaboration, AI, plugin runtimes, specialist integrations
and expensive advanced capabilities remain later. Basic slices can precede their
later enhancements only through an explicitly scoped task.

## Missing prerequisites and tensions

[Prerequisites](open-questions.md) identify durable save/journaling, fragment/PDF
anchors, attachment ownership, scalable Canvas persistence, versioned view state,
query/type contracts, compatibility fixtures, sync revisions, collaboration
permissions, AI scope and plugin isolation. None is represented as implemented.

The [source map](../product/conversation-extraction.md) records resolved tensions:
file authority versus database-only examples; one Canvas versus separate modes;
object identity versus placements; private context versus sharing; M0 system theme
versus future branding; manual restoration versus AI/history; unknown-field
preservation versus unsupported future writes; and deterministic versus AI cleanup.
No accepted architectural decision was changed, so no ADR was superseded.

## Validation

- All relative documentation links resolve.
- All 264 requirement definitions are unique and appear exactly once in the backlog.
- Baseline hashes confirm product code, current task and accepted ADRs are unchanged.
- Dart formatting check: passed, 2 files checked, no changes.
- Flutter analyze: passed, no issues.
- Flutter test: passed, 1 existing bootstrap test.
- Platform builds were not repeated for this documentation-only change.

The first sandboxed Flutter check stalled and was stopped; rerunning with access
to the existing SDK/cache completed successfully. No package or toolchain was added.

## Files

- updated: AGENTS.md
- updated: CONTRIBUTING.md
- updated: docs/architecture/ai.md
- updated: docs/architecture/canvas-engine.md
- added: docs/architecture/compatibility-and-migrations.md
- updated: docs/architecture/local-first-sync.md
- updated: docs/architecture/overview.md
- updated: docs/architecture/storage-formats.md
- updated: docs/architecture/ui-layout.md
- added: docs/design/motion.md
- added: docs/design/visual-design.md
- added: docs/development/agent-workflow.md
- added: docs/development/definition-of-done.md
- added: docs/features/ai-and-knowledge-health.md
- added: docs/features/attachments-and-research.md
- added: docs/features/calendar-and-events.md
- added: docs/features/capture-and-inbox.md
- added: docs/features/collections-and-views.md
- added: docs/features/customization-and-spaces.md
- added: docs/features/decisions-and-provenance.md
- added: docs/features/desktop-interactions.md
- added: docs/features/freeform-and-ink.md
- added: docs/features/game-development-and-teams.md
- added: docs/features/history-and-recovery.md
- added: docs/features/home-and-work-sessions.md
- added: docs/features/import-export-and-portability.md
- added: docs/features/markdown-and-editing.md
- added: docs/features/objects-and-organization.md
- added: docs/features/plugins-apis-and-automation.md
- added: docs/features/README.md
- added: docs/features/reverse-engineering.md
- added: docs/features/search-links-and-graph.md
- added: docs/features/shell-and-navigation.md
- added: docs/features/software-development.md
- added: docs/features/spatial-boards.md
- added: docs/features/study-and-university.md
- added: docs/features/sync-and-collaboration.md
- added: docs/features/tasks-calendar-and-planning.md
- added: docs/features/TEMPLATE.md
- updated: docs/planning/current-milestone.md
- added: docs/planning/feature-backlog.md
- added: docs/planning/open-questions.md
- updated: docs/planning/roadmap.md
- added: docs/product/conversation-extraction.md
- updated: docs/product/feature-catalog.md
- updated: docs/product/principles.md
- added: docs/product/product-definition.md
- added: docs/product/quality-requirements.md
- updated: docs/product/terminology.md
- added: docs/product/user-journeys.md
- updated: docs/product/vision.md
- updated: docs/README.md
- updated: docs/tasks/TEMPLATE.md
- updated: README.md
- added: docs/planning/documentation-update-2026-09-08.md

