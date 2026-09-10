# Quality requirements and acceptance budgets

Status: product acceptance principles plus **proposed** measurement targets.
Derived from the source conversation's ownership, customization and canvas concerns.
They are not measured claims or external certification/compliance promises.
See the [engine](../architecture/canvas-engine.md) for technical direction and
[definition of done](../development/definition-of-done.md) for task-sized checks.

## Reliability and user ownership

| Area | Required outcome when the feature ships | Evidence |
|---|---|---|
| Local operation | Core features work without login or network | Offline create/edit/reopen/search/export scenario |
| Save truth | Saved locally means recoverable durable data, not an optimistic screen | Fault injection before/after actual persistence boundaries |
| Index recovery | Losing a derived index does not lose the only content copy | Rebuild from owning files plus any committed recovery log |
| External edits | Preserve concurrent external content rather than silently overwrite | Hash/revision conflict fixtures and restart/reconciliation |
| Cross-view coherence | Multiple representations show one object identity | Edit in one, observe in others; remove placement independently |
| Migration | Old content is backed up and interrupted migration is recoverable | Supported-version fixtures, rollback/retry |
| Export | All implemented meaningful data has a documented exit path | Export/restore/reference-integrity round-trip |
| Assistance | AI/plugin/rule failures cannot silently corrupt the workspace | Rejection, cancellation, permission and partial-failure tests |

## Proposed performance workloads

The chat proposed 60 FPS ordinary interaction, 120 Hz where feasible, a 10,000-element
board, a 100,000 lightweight-element stress scene and 100,000+ ink points. Preserve
these ambitions while selecting a representative reference device and workload
before enforcing numbers. Do not describe them as tested capacity.

| Scenario | Proposed budget/goal | Record before claiming success |
|---|---|---|
| Ordinary canvas pan/zoom | Meet a 60 Hz frame budget (about 16.7 ms); inspect both build and raster timings | Profile/release build, hardware/display, p50/p95/worst frames, input latency |
| Large board | 10,000 mixed elements; working viewport containing tens/hundreds, not all interactive widgets | Visible count, mounted widgets, index query time, memory and loading state |
| Stress board | 100,000 lightweight elements as an exploratory capacity test | Total/visible complexity, index/build time, peak memory and degradation |
| Dense ink | At least 100,000 samples; separate active stroke from stored ink | Input-to-render behavior, simplification fidelity, replay/save cost |
| Images/PDFs | Bounded cache and viewport-appropriate decoding | Original size, requested preview size, peak decoded memory, page count |
| Local search | Proposed p95 under 200 ms for indexed queries on a 10,000-note fixture | Cold/warm query, index completeness, note-size distribution and device |
| Capture | Visible response to input without synchronous disk/network stalls | Responsiveness and separate durable-save latency, including failures |

The search number is an elaboration proposed in this documentation pass, not a
promise extracted verbatim from the chat. M0 does not need these benchmark harnesses.
Adopt/adjust them in the relevant task with evidence. Culling helps hidden content;
it cannot make a fully visible dense scene free to render.

## Usability and accessibility

Every feature should cover empty, normal, loading, error, read-only, missing-source
and offline states where applicable. Keep empty states truthful and actions real.
Require discoverable keyboard focus, semantic labels, readable contrast, scalable
text, and a touch alternative to essential drag/hover-only interactions.

Use M0's prescribed narrow/wide sizes and 2.0 text scale for the starter; set
additional device cases when a feature needs them. Drawing needs a non-spatial
object list/commands where practical and real pen/tablet testing for hardware claims.
Customization must retain recovery through hidden/broken panels and unplugged monitors.
Reduced-motion behavior should be considered before animation-heavy transitions ship.

## Privacy, extensibility and maintainability

No analytics, AI transmission, clipper monitoring or system-wide activity recording
is implied by the concept. Any future telemetry needs a separately documented choice.
Minimize permissions for actual capabilities and keep credentials out of content exports.
Imported documents and model responses cannot grant capabilities.

Keep domain/storage/rendering/provider boundaries inspectable. Packages must be
needed, compatible with intended targets and accompanied by migration notes where
necessary. Feature status should identify which requirement subset exists, its tests
and limitations; a successful build alone is not a claim of functional completeness.
