# ADR-0034 — Source-bound derived routing workers

- Status: accepted
- Date: 2026-10-25
- Scope: CAN-05/07/14/15/16 performance; extends the shared spatial engine.

## Decision

Keep canonical routing in the pure Dart engine. The editor may run that same
solver through Flutter `compute` and publish an opaque prepared layout only
when its complete rendering-relevant geometry signature still matches the
current scene. This is a derived cache, not authored content or a new authority.

The synchronous scene constructor remains the default for exports, reopened
documents and existing callers. For larger use-case scenes the editor requests
deferred automatic bounds, shows an accessible loading state, and exposes the
Canvas only after exact canonical bounds are installed. No provisional straight
connections are drawn as final geometry. The initial threshold is 12 relationship
markers; scenes without visible automatic relationships need no worker.

At gesture completion, a previously validated preview may stay visible while
canonical routing runs. Already canonical geometry is reused. Installing a
result refreshes route/hit/content bounds together. Exports construct canonical
scenes from authored data; pending UI cache state is never serialized.

Each editor has at most one in-flight worker and one latest queued scene. A
replacement Canvas, active/new gesture, changed geometry or disposed editor
rejects obsolete results. Removing/hiding the last automatic relationship retires
pending work rather than retrying forever. Later style/unknown metadata remain
in the current scene: workers never replace authored elements or history.

Signatures compare finite numeric routing inputs as the renderer consumes them.
Ignored future JSON maps must not compare by cross-isolate object identity.
If worker preparation fails, retain the existing synchronous solver as fallback.
Native `compute` uses an isolate; web execution has no off-main guarantee.

## Consequences

No file/schema migration, external service, new dependency, rendering downgrade,
route simplification or resolution reduction. Raw route computation still has a
cost; worker completion is not the pointer-event time. Large initial scenes have
a visible preparation phase. Invalid in-gesture continuation may still require
the bounded synchronous solver. This does not promise zero latency on arbitrary
graphs or eliminate first-raster/GPU startup spikes. Validate both event/frame
timings and exact canonical route/label equivalence, including stale jobs and
lossless storage/undo, before delivery.
