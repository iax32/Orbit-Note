# Architectural prerequisites and open decisions

These are implementation dependencies, not claims of completed infrastructure.
None enlarges [M0-01](../tasks/current.md). Resolve each through a small task and
an ADR only when selecting/changing an architectural decision.

| ID | Needed before | Missing contract / evidence |
|---|---|---|
| PRE-01 | M1 durable content | Stable identity, owning-file serializer, file-first save/recovery and Drift rebuild demonstrated under interruption and external edits. |
| PRE-02 | Multi-object edits/migrations | Durable multi-file transaction/recovery journal, idempotent replay, history and backup verification; filesystem and SQLite cannot be assumed one atomic transaction. |
| PRE-03 | M2 rich editor | Markdown round-trip/extension policy, stable fragment IDs, inline-task promotion and transclusion cycle/orphan handling. Select an editor with fidelity fixtures. |
| PRE-04 | M2 attachments/desktop | Owned versus linked bytes, reference accounting, clipboard/drop platform adapters, failed-import cleanup and attachment deletion recovery. |
| PRE-05 | M3/M4 Canvas | Versioned common scene/ink schema, camera/spatial index, gesture commands, durable incremental save design and measured large-scene rendering. |
| PRE-06 | Resume Context | Versioned per-view descriptors, anchor fallback, device/private versus shared layout state and opt-in session retention. |
| PRE-07 | M5 structured views | Type/property/relation registry, validated query model, date/time semantics and migration behavior for renamed/removed fields. |
| PRE-08 | First persistent release | Format support/deprecation policy, old-workspace fixtures, backup/restore and unknown-field preservation. |
| PRE-09 | M6 sync | Revision/shared-base model, outbox/tombstones, provider protocol and conflict UI; prove merges, offline retries and attachment integrity before selecting optimizations. |
| PRE-10 | Collaboration | Membership/role/object authorization including linked content, revocation, search/preview filtering and shared Space semantics. A local Space is not an ACL. |
| PRE-11 | M8 AI | Provider capability/secret handling, retrieval exclusions, permissions independent of sync, source anchors and stale-safe reviewed change sets. |
| PRE-12 | M7 extensions | Runtime isolation feasibility, capability permissions, API/version negotiation, safe mode, connector authentication and unsupported-type preservation. |
| PRE-13 | Branded UI/motion | Theme/motion tokens, accessible defaults, reduced/off behavior and layout recovery; retain M0's current system theme until its task changes. |

## Decisions still open

- File-format support window and migration rollback retention: decide before M1
  release; do not promise indefinite write compatibility with every future version.
- Rich editor package, PDF rendering/anchor strategy and pen-device support:
  evaluate platform capability, licensing and round-trip fidelity in their tasks.
- Incremental Canvas persistence: current authoritative file contract stands.
  A new journal/checkpoint strategy needs evidence and an ADR before adoption.
- Plugin execution runtime and sync merge/CRDT approach: accepted stack choices
  do not resolve these. Simultaneous editing is not required for first sync.
- E2EE: threat model, keys, recovery, sharing and search tradeoffs need a dedicated
  design; no encryption guarantee exists merely because it is on the roadmap.
- Public distribution: license selection, application ID ownership, signing and
  platform release checks remain necessary. No cloud account is needed for M0.

Dependency IDs in the [backlog](feature-backlog.md) name major gates. Each future
task must narrow them to a testable slice; the table is not an exhaustive build graph.
