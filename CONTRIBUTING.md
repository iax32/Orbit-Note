# Contributing

Read [AGENTS.md](AGENTS.md), the [current task](docs/tasks/current.md), and the
documents it references. Product terms live in [terminology](docs/product/terminology.md).
Use [task templates](docs/tasks/TEMPLATE.md) to keep work small and reviewable.

## Change workflow

1. Inspect existing behavior and relevant tests. Keep one user-visible outcome
   or one foundation concern per change; explain scope before coding.
2. Follow the [architecture boundaries](docs/architecture/overview.md). Add a
   dependency only when used; verify supported platforms and its license.
3. Add meaningful tests for changed behavior. Persistence work requires recovery
   and migration tests; canvas work requires coordinate/input tests and profiling;
   sync work requires conflict and retry tests. Pure documentation changes need
   link/consistency checks, not artificial app tests.
4. Format, analyze, and test as described in [setup](docs/development/setup.md).
   Record commands and results, including unavailable platform checks.
5. Update task status/evidence. Change design docs only if documented behavior
   changes; use an [ADR](docs/adr/TEMPLATE.md) for architecture changes. Do not
   quietly overwrite an accepted decision: supersede it and update its index.
6. Describe the problem, resulting behavior, validation, and remaining limitations.
   Do not implement the next task, commit unrelated files, or publish automatically.

## Code conventions

- Idiomatic null-safe Dart, small cohesive types, immutable domain values.
- Widgets compose UI; application logic owns commands; repositories own local I/O.
- Riverpod provides UI state and dependency injection, not a second content store.
- Resolve IDs through repositories; avoid view-owned copies of user knowledge.
- Prefer feature-local code until a second real consumer needs shared code.
- Keep platform-specific imports behind adapters. Preserve keyboard access,
  text scaling, contrast, pointer/stylus use, and narrow layouts.
- Do not commit credentials, private workspaces, build outputs, or SDKs. Keep the
  application lockfile. Commit necessary generated platform source; add a generated
  Dart policy when code generation first becomes necessary.

Open design questions are tracked in the relevant document and milestone, not
invented as blockers to unrelated work. License selection belongs to the maintainer
before the first public distribution.

Use the [focused workflow](docs/development/agent-workflow.md) and
[definition of done](docs/development/definition-of-done.md). Identify the scoped
requirement IDs; do not implement a whole specification merely because it exists.
