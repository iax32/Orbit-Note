# Architecture overview

Status: accepted boundaries, now implemented by the local core. See
[implementation status](../planning/implementation-status.md). Read the [ADRs](../adr/README.md) and
[current task](../tasks/current.md) before extending it.

## Dependency direction

```text
Flutter views / shell
         ↓ Riverpod state and injection
Application queries + validated commands
         ↓ repository interfaces
Pure Dart domain values
         ↑ implementations in infrastructure
Local workspace files + Drift/SQLite

Later: Sync / AI / plugins → application capability interfaces
       Sync transport → hosted/self-hosted backend
```

UI reads observable local state. Commands validate identities, schema, permissions,
and expected revisions, then persist locally. The repository coordinates file and
database changes; rendering never waits for a remote provider. Background adapters
publish committed local changes through the same application boundaries.

The domain owns identity, typed properties, relations, and invariants. It imports
neither Flutter, Riverpod, Drift, nor Supabase. Infrastructure implements domain/
application interfaces. Riverpod constructs dependencies and observes state; it
does not replace repositories or durable storage.

## Grow folders when code needs them

| Location | Responsibility |
|---|---|
| `lib/main.dart` | Small composition entry point |
| `lib/app/` | App root, provider scope, theme, shell/navigation composition |
| `lib/features/<feature>/` | Feature presentation and feature-specific application code |
| `lib/domain/` | Shared pure Dart models and invariants once required |
| `lib/application/` | Shared commands, queries, repository contracts once required |
| `lib/infrastructure/` | Filesystem/browser storage, Drift, platform and later network adapters |
| `lib/canvas/` | Reusable camera, geometry, input, spatial index, render/ink primitives |
| `test/` | Behavioral unit/widget tests mirroring meaningful boundaries |

These folders now contain the local core. Keep a single
Flutter package until a concrete consumer justifies extracting a package. Avoid
generic base repositories, event frameworks, or speculative services.

## Authority and failure boundaries

- Portable files own user content at rest. SQLite accelerates queries and holds
  operational state. The [storage contract](storage-formats.md) defines saves and recovery.
- View definitions and layouts own presentation; object content remains independent.
- A canvas edits geometry locally and submits a command per completed gesture.
- Database migrations and file-format migrations are separate, versioned, and tested.
- Later sync/AI/plugin errors cannot prevent local opening, reading, editing, or export.
- Unknown plugin types/formats preserve raw data and show a fallback instead of
  discarding it. No code is executed just because a workspace contains it.

## Platform strategy

Windows desktop is the first supported development loop. Keep native filesystem,
browser storage, file picking, secure secrets, and pointer/stylus differences behind
adapters. Web must not import `dart:io` unconditionally. Mobile uses the same domain
and storage contracts with sandboxed storage and explicit import/export flows.
The browser adapter and file permission UX must be validated before claiming full
local-workspace parity. See [local-first/sync](local-first-sync.md).

## Verification by feature

Use widget tests for shell behavior; pure tests for identities/query/command rules;
temporary-workspace tests for recovery and external edits; migration fixtures for
database and formats; coordinate/hit-testing tests plus profile builds for canvas;
multi-replica simulations for sync. Add each harness when its feature is implemented.

## Expanded design contracts

Use [compatibility/migrations](compatibility-and-migrations.md) before persistent
formats ship. [Prerequisites](../planning/open-questions.md) identify unresolved
save, anchor, query, context, sync and extension contracts. Specialist workflows
reuse the universal model; none requires a separate application architecture.
