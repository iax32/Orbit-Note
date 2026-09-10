# ADR-0005 — Universal objects and reference-based views

- Status: accepted
- Date: 2026-09-07
- Scope: identity, content and presentation model
- Supersedes: none

## Context

A note/project/task should appear across documents, tables, boards and graphs
without divergent copies. Identity must survive renaming, moves and offline edits.

## Decision

Use stable UUID universal objects with typed properties, content references and
relations. Views query/reference objects. Canvas placements have separate identity
and geometry. Notebook/collection membership is organization, not another copy of
content. Use the term `UniversalObject`, not a competing `Node` subsystem.

Shared identity does not force every local ink stroke or decorative element into
the global object catalog. Promote embedded content explicitly when needed.

## Alternatives

Separate note/task/board content stores are initially easy but make synchronized
editing across views fragile. One undifferentiated dynamic map erases validation
and capabilities. A common identity with typed schemas keeps both flexibility and rules.

## Consequences

Resolve IDs through repository boundaries; validate references and deletion
semantics. A placement can disappear while its object remains. Queries determine
appropriate views by capabilities, not a promise that every type fits every view.

## Validation / follow-up

The [draft model](../architecture/universal-object-model.md) is refined with M1.
When views/canvas arrive, tests must show an object edit reflected across views,
two independent placements, and non-destructive removal of a placement/membership.
