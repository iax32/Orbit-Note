# ADR-0002 — Riverpod state and dependency injection

- Status: accepted
- Date: 2026-09-07
- Scope: application composition and reactive presentation
- Supersedes: none

## Context

Multiple views need observable local state, scoped dependencies, and testable
controllers without coupling widgets directly to files/database/cloud.

## Decision

Use Riverpod for provider composition, application/UI state and repository
observation. Begin with the non-generated API in M0-01. Keep business invariants in
pure Dart domain/application code; provider state is not durable knowledge storage.
Use provider overrides for tests and granular subscriptions for future canvas work.

## Alternatives

Plain widget state is enough for the bootstrap but does not establish the chosen
shared dependency pattern. BLoC/Provider are viable alternatives; using several
state frameworks at once would add unnecessary conventions.

## Consequences

One root ProviderScope, clear provider ownership/disposal, and testable state
boundaries. Add generators/hooks only if a concrete need justifies their cost.
Riverpod is not installed by the setup pass; the current task introduces it.

## Validation / follow-up

Use a stable compatible package via the [official installation guidance](https://riverpod.dev/docs/introduction/getting_started)
and commit the app lockfile. M0 tests selection and responsive behavior; later
tests cover disposal, async failures and targeted rebuilds when those matter.
