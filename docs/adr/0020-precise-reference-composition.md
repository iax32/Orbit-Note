# ADR 0020 — Precise references and search composition

Status: accepted direction, 2026-09-30. Delivery evidence lives in the task report.

## Context

Object UUID WikiLinks and PDF-page links work, but search opens roots and Canvas
references cannot address a particular source paragraph. Source files remain
canonical; SQLite is derived. Existing scene elements already have UUIDs and
a bounded spatial grid. A wholesale storage/controller/index rewrite is unnecessary.

## Decision

Extend the existing ObjectReference with optional typed fragments. Keep Markdown
WikiLinks portable: `#^block-id`, literal/encoded heading, `#element=UUID`,
`#label=LaTeX-label`, existing `#page=N`, and annotation UUID targets. Preserve
unknown fragments. Never use a source offset or geometry as permanent identity.

Assign explicit prose `^orbit-UUID` anchors lazily, only when a user requests a
block reference. Rich rendering hides but preserves the suffix. Do not rewrite
ordinary notes on open, inject anchors everywhere, or duplicate existing TeX labels.
Missing/duplicate anchors are unresolved. No silent retarget after source deletion.

Canvas v1 cards retain `objectId` and optionally add `referenceTarget`. The target
must address that same canonical object. Resolve text from current source; no
copied body in placement data. Placement deletion cannot delete source content.
Editing a precise placement opens the source rather than editing a misleading
whole-note copy. Note→Canvas uses normal repository save/recovery boundaries.

Rich global search results project FTS candidates/current drafts and element/source
locations. Name ranking is shared with Quick Switcher. Native heavy projection uses
an isolate; browser fallback remains platform-safe. Source offsets only describe
unchanged query snapshots, not saved references. Navigation requests stay transient,
while existing device caret/camera/page state owns resume persistence.

Retain the current derived spatial grid; incremental geometry and connector updates
already use it. Add stress equality/diagnostics and fix oversized cell-count overflow.
Do not select a new tree or ink cache without workload evidence.

Extract search orchestration into an application service. AppPreferences owns
appearance/editor defaults while SessionState stays the flat-v1 compatibility
facade. Preserve unknown settings fields. No new persistent schema/migration or
sync protocol is introduced by this incremental ownership change.

## Consequences

Readable headings can become unresolved on rename; explicit block/element/label
IDs are preferred for durable precise content. Older readers show anchor suffixes
and whole-object cards without losing knowledge. Filter-before-index scope queries,
PDF page extraction, interactive nested canvases and further controller decomposition
remain separate work. SQL is never the only copy, and unsupported fragments retain
their written form for deliberate repair.
