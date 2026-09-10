# Orbit Note — agent guide

Open-source, local-first personal knowledge OS. Flutter/Dart; Windows first,
Android/iOS/web compatible. Riverpod and Drift/SQLite are accepted choices;
add them only when the current task needs them.

## Start here

1. Read [current task](docs/tasks/current.md), then only its required docs.
2. Inspect relevant implementation and tests; make a brief plan and implement
   only that task. The roadmap is context, not permission to build ahead.
3. Use the [docs index](docs/README.md) for targeted lookup. Do not load every
   doc, the whole repository, or the original conversation by default.

## Invariants

- Core use works offline without an account. UI uses local application/repository
  boundaries; cloud, plugins, and AI never bypass them.
- One stable universal object identity; views and canvas placements reference
  objects rather than copy their content. Placement deletion is not object deletion.
- Markdown, documented JSON, and ordinary attachments preserve user knowledge.
  SQLite is not the sole durable copy. Follow the storage authority/save contract.
- Reuse one spatial/ink engine for boards, freeform pages, and annotations.
- User and AI mutations use validated commands with recoverable history when
  persistence exists. AI proposals require review and must be reversible.
- Layout customization must retain accessible recovery/reset paths.
- Keep domain code independent of Flutter, database, and provider SDKs. Preserve
  platform adapters; do not introduce unconditional `dart:io` in shared code.

## Working rules

Prefer small changes and existing code. Do not prebuild future layers, install
unused packages, or add backend credentials. Preserve unrelated user changes.
Test behavior and failure boundaries, not private implementation details.

Run `dart format lib test`, `flutter analyze`, and `flutter test`; check formatting
with `dart format --output=none --set-exit-if-changed lib test`. Run additional
platform checks when relevant. Report blocked checks honestly; do not hide failures.

Update task status and validation evidence. Update design docs only when documented
behavior changes; create/supersede an ADR only for an architecture change. Accepted
ADRs describe direction, not completion. Report changes, checks, unresolved issues,
and one suggested next task; stop before implementing it.

For larger feature tasks, consult the [spec map](docs/features/README.md) and
[single backlog](docs/planning/feature-backlog.md); use the
[workflow](docs/development/agent-workflow.md) for detailed checks. Preserve old
workspace compatibility and unknown data; migrations need recovery evidence.
