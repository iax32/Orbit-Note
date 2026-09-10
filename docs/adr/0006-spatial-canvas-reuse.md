# ADR-0006 — Reuse the spatial and ink engine

- Status: accepted
- Date: 2026-09-07
- Scope: boards, freeform pages and annotations, M3 onward
- Supersedes: none

## Context

Milanote-like boards and OneNote-like pages share transforms, selection, ink,
placement, hit-testing and undo. Separate implementations would duplicate difficult
behavior and make content conversion inconsistent.

## Decision

Build one spatial/ink engine with preset-specific behavior and coordinate adapters
for board, freeform page, PDF and image consumers. Use world coordinates, a camera,
viewport culling/spatial queries, batched painting and selective interactive widgets.
Object cards reference existing knowledge; vectors remain editable.

## Alternatives

Separate board/page/PDF renderers duplicate core logic. A widget for every scene
item is unsuitable as the unbounded architecture. A raster-only drawing surface
loses editable strokes and portable structure.

## Consequences

Keep geometry/input/rendering/persistence responsibilities explicit. Reuse the
linear editor where needed rather than turning all text into canvas elements.
Use one command per completed gesture. Shared code still needs device-specific
stylus and coordinate tests; caching and spatial indexing have real complexity.

## Validation / follow-up

Follow the [engine specification](../architecture/canvas-engine.md). M3 verifies
transforms, culling, hit-testing, placement undo and measured workloads. M4 verifies
pressure fallbacks, vector round-trips and annotation alignment. Performance targets
remain unverified until benchmarked; no canvas implementation belongs in M0.
