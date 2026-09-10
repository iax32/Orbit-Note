# ADR-0003 — Drift and SQLite locally

- Status: accepted
- Date: 2026-09-07
- Scope: local indexed and operational state, M1 onward
- Supersedes: none

## Context

Orbit Note needs efficient object queries, links, local full-text search, canvas
indexes and eventual change tracking while offline.

## Decision

Use Drift over SQLite behind local repository implementations. Treat SQL schema
migrations and file-format migrations separately. Add the dependency, minimal
tables and generated code only with the first persistence task. No database in M0.

SQLite holds derived content indexes and operational state. It is not the sole
durable source for user-created text, geometry, ink or semantic structure. Follow
[ADR-0004](0004-markdown-open-formats.md) for authority and recovery.

## Alternatives

Raw SQLite bindings require more manual query/migration plumbing. Files alone
are portable but insufficient for rich queries at scale. A cloud-only database
does not meet offline and ownership requirements.

## Consequences

Repositories coordinate portable files and indexes without pretending that one
SQL transaction also commits files. Use background database/I/O work as needed.
Keep browser/native connections behind adapters and verify supported storage modes
using [Drift's platform documentation](https://drift.simonbinder.eu/platforms/).

## Validation / follow-up

M1 tests indexing, reopen, corruption/rebuild and migrations. Confirm FTS and
platform requirements for the actual package versions. Large-canvas working-state
and sync outbox durability must pass their own crash/recovery tests before use.
