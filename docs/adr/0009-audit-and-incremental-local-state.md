# ADR-0009 — Authored source, bounded recovery and incremental local work

Status: accepted and implemented subset, 2026-09-09. Partially supersedes
[ADR-0008](0008-backup-import-and-workspaces.md). Completion is tracked in
[CURRENT status](../planning/implementation-status.md).

## Context and decision

The owner's consolidated brief prioritizes trustworthy local editing over new
subsystems. Autosave must preserve authored Markdown exactly. Plain wiki links can
bind to UUIDs in additive `properties.orbitLinkBindings` metadata; explicit
`[[uuid|display]]` insertion remains available. Renames retain readable aliases.
Binding metadata from an earlier in-flight save survives a newer draft. Missing
bound objects do not silently retarget another object with the same title.

Native saves retain before-images and unresolved journals, but completed journals
are retired. History retention targets are 200 entries, 64 MiB and 30 days, preserving
at least one previous version per path and every unresolved recovery dependency.
Known legacy completed chains can retire only when hashes prove completion.
Unknown/unproven records remain. Hard deletion to enforce a strict byte cap was
rejected because it could destroy the only recovery evidence.

Backup container/path/version errors still reject before writes. Ordinary Markdown,
unsupported/malformed object files, duplicate IDs and missing attachment references
produce preview/report warnings while preserving their bytes. Imported journals
remain quarantined and are never replayed. This replaces ADR-0008's overly strict
object-level rejection without weakening path validation or separate-folder publication.

Native filesystem events schedule debounced targeted hash checks. Startup, resume
and directory-change reconciliation still scan canonical paths. Internal save/cache
events are excluded; there is no recurring idle hash timer. Events are hints, not
locks. Binary preview invalidation remains incomplete.

Search uses the repository index with unsaved-draft overlay. Native index schema v2
adds rebuildable `search_text` for bodies/properties/Canvas text and title-first
ranking. It is literal SQL matching, not FTS5 or semantic search.

Canvas undo records touched-element deltas per gesture; it no longer serializes
the whole scene for each history entry. Text layout, image decoding and stroke
points are cached with bounded working sets. Scene revisions inform repaint checks.
The app theme watches only relevant preferences; this does not claim every shell
widget is granular. Whole-board JSON persistence remains a measured scaling cost.

## Alternatives and consequences

Background rewriting of authored links was rejected because it shifts selections
and surprises external editors. Universal identities remain the existing UUIDs.
Aggressive recovery deletion and rejecting an entire mixed vault backup both risk
making user-owned knowledge inaccessible. Full idle scans and full-scene undo
copies were replaced with event/delta work while retaining reconciliation and
existing spatial culling.

Attachments can always be stored. Opening executable/unknown types requires a
concrete confirmation; Show in Explorer remains available. No attachment is run
during import or scanning.

## Evidence

Audit, backup, index, controller and Canvas regressions cover unchanged authored
source, stable bindings, retained unknown bytes, bounded completed history, native
events, metadata search, large-scene delta undo and bounded image decode admission.
Model benchmarks are not Flutter frame-time or physical-pen evidence.
