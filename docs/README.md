# Documentation map

Start with [the current task](tasks/current.md). Read only the topic needed next.
These docs distill the full **Build Note Taking App** conversation (14 turns),
as explicitly adopted by the project owner on 2026-09-07. They are the repository
source of truth; illustrative chat snippets are not production specifications.

The later Markdown/open-format discussion resolves earlier database-only examples.
The later canvas discussion replaces the initial all-items-in-a-Stack prototype.
Use **Orbit Note**, **universal object**, **canvas**, and **Space** consistently.

## Product

| Read when… | Document |
|---|---|
| Understanding the purpose and audience | [Vision](product/vision.md) |
| Evaluating a tradeoff | [Principles](product/principles.md) |
| Resolving names and concepts | [Terminology](product/terminology.md) |
| Finding discussed capabilities and their stage | [Feature catalog](product/feature-catalog.md) |

## Architecture

| Read when… | Document |
|---|---|
| Placing code and identifying boundaries | [Overview](architecture/overview.md) |
| Working on objects, properties, relations, identity | [Universal objects](architecture/universal-object-model.md) |
| Reading/writing user files or migrations | [Storage and formats](architecture/storage-formats.md) |
| Working on spatial content or ink | [Canvas engine](architecture/canvas-engine.md) |
| Working on offline behavior or future replication | [Local-first and sync](architecture/local-first-sync.md) |
| Working on shell, panes, navigation, themes | [UI and layouts](architecture/ui-layout.md) |
| Designing extension capabilities | [Plugins](architecture/plugins.md) |
| Designing AI retrieval and reviewed changes | [AI](architecture/ai.md) |
| Checking why a stack decision was made | [ADR index](adr/README.md) |

## Delivery

- [Roadmap](planning/roadmap.md): order and exit gates, not a build-all checklist.
- [Current milestone: durable local core](planning/current-milestone.md).
- [Current task: Rich Markdown stabilization](tasks/current.md) and [task template](tasks/TEMPLATE.md).
- [Development setup and verification](development/setup.md).
- [ADR template](adr/TEMPLATE.md).

**Status vocabulary:** accepted = chosen direction; proposed = needs validation
before implementation; deferred = future scope; implemented = present in code and
verified. The feature catalog marks capabilities as planned or exploratory.
Current delivered subsets are recorded only in [implementation status](planning/implementation-status.md). Numerical performance targets are goals,
not measured claims. Draft data shapes are design contracts to refine with their
first implementation, not a released file-format standard.

When docs disagree, use accepted ADRs for decisions and the current task for scope.
Resolve a material inconsistency explicitly rather than silently inventing behavior.
Do not reread the original conversation for routine implementation.

## Detailed specifications and release planning

The owner's detailed 2026-09-08 brief is incorporated alongside the original chat.
Read only the relevant topic; the [source map](product/conversation-extraction.md)
records coverage and resolved tensions without requiring another transcript read.

- [Precise product definition](product/product-definition.md),
  [user journeys](product/user-journeys.md), [quality requirements](product/quality-requirements.md).
- [Feature specification map](features/README.md): stable IDs, behavior, edge cases
  and acceptance scenarios across the full feature set.
- [Canonical feature backlog](planning/feature-backlog.md): sole owner of release
  classification and sequencing; [prerequisites/open questions](planning/open-questions.md).
- [Compatibility/migrations](architecture/compatibility-and-migrations.md).
- [Visual direction](design/visual-design.md) and [motion system](design/motion.md).
- [Agent workflow](development/agent-workflow.md) and [definition of done](development/definition-of-done.md).

Feature specs own behavior; the backlog owns release classes; roadmap owns milestone
exit gates; the current task owns active scope. Stage notes in older specs describe
earliest slices, not a second release commitment. Future/experimental clauses stay
deferred even where a requirement's basic behavior can ship earlier.

Historical change record: [2026-09-08 documentation expansion](planning/documentation-update-2026-09-08.md).

- [Implemented features, evidence and limits](planning/implementation-status.md).
- [Current open-format subset](architecture/implemented-formats.md).


- [Historical local hardening batch report](planning/local-hardening-report.md).

Current implementation evidence: [incremental audit polish batch](planning/audit-polish-batch.md).
