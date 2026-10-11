# Decisions, assumptions and provenance

Status: delivered local subset below; broader M5+ behavior and automatic
assumption/contradiction analysis remain planned/exploratory.
Sources: S04, S06, S07 in the [source map](../product/conversation-extraction.md).
Architecture: [universal objects](../architecture/universal-object-model.md),
[AI](../architecture/ai.md).

## Purpose and workflow

A project contains more than notes: why something was saved, what was decided,
which alternatives were rejected and what assumptions remain uncertain. A user
saves a source while researching sync, records “Use an optional self-hostable
backend” as a decision, and links it to the assumption that offline work must
remain available. Months later that context is still inspectable.

## Delivered local records — 2026-10-10

Research workspace > New decision/New assumption creates an ordinary Markdown note
with optional research metadata. Statement, Markdown reasoning/alternatives,
recorded creation time, state, explicit confidence/importance, supporting evidence,
assumption dependencies and superseded-record UUIDs are editable through validated
controller commands. An assumption dependency must reference an assumption; a
superseded record must have the same kind. Self links and newly missing sources
are rejected; existing missing links remain removable and inspectable. Unknown
metadata is retained and unsupported record versions cannot be upgraded by editing.

Decision review compares stored source revision/time/checksum/content fingerprints against
current canonical sources. Missing or changed evidence and changed, missing,
disproved or superseded assumptions have concrete review reasons. Mark reviewed
acknowledges current saved versions. Disproved/superseded assumptions and missing
links continue to need attention; no reasoning, state or confidence is inferred or
rewritten. Editing a record keeps acknowledged evidence versions until explicit
review. Conflicted/unsaved sources cannot be acknowledged as durable evidence.

Project records show current state and dates plus a bounded timeline of before-edit
and before-review checkpoints. These use the existing 30-entry note revision list
and additionally retain researchFields. Revision History compares/restores note
title/body using its existing behavior; it does not restore research state fields.
Backlinks label Supported by, Depends on assumption and Supersedes relations; the
graph includes the connections subject to its existing type filters. Superseding
is an explicit relation, not an automatic mutation of another record's state.

This delivers manual PROV-03/04/05 and deterministic PROV-06 with available-history
PROV-07. It does not infer contradictions, reconstruct historical boards, monitor
web sources, provide a complete workspace evolution timeline or migrate existing
freeform decision-log notes into structured records.

## Requirements

| ID | Observable behavior |
|---|---|
| PROV-01 | Captured objects can retain source URL/file/app, time, associated project/session and an optional user-entered reason for saving. |
| PROV-02 | “Why is this here?” shows recorded provenance and supporting references; unavailable reasons remain unknown rather than invented. |
| PROV-03 | Decision objects support statement, rationale, alternatives, date, status and linked evidence/assumptions; confidence can be recorded explicitly. |
| PROV-04 | Assumption objects support statement, importance, verification status and evidence. Proposed statuses include unverified, confirmed, disproved and superseded. |
| PROV-05 | Decisions/assumptions connect to projects, concepts, people, tasks, sources and other decisions through typed relations. |
| PROV-06 | Changing evidence or assumptions can produce a review suggestion for dependent decisions; the app must not automatically rewrite the decision as fact. |
| PROV-07 | Object/workspace timelines can show creation, meaningful changes, decisions and revisions with source/actor provenance and links to available history. |
| PROV-08 | User-entered facts, imported metadata, deterministic extraction and AI inference are distinguishable; users can correct derived metadata without destroying the source. |

## Data and meaning

These are product objects in a user's workspace. They are different from this
repository's ADR files, although both preserve reasoning. The product does not
need to force every personal decision into an engineering ADR template.

Relations should express “decision depends on assumption,” “claim supported by
source,” and “decision supersedes decision” as useful types once schemas exist.
The graph can present those edges and a project inspector can list them. A timeline
shows recorded evolution; a reconstructed historical canvas is a more demanding
history feature with separate support/retention requirements.

Captured context is optional, editable and privacy-scoped. A browser URL can later
change or disappear; retain quoted/extracted material only within supported import
and permission rules, keep capture time, and distinguish a current live source from
a preserved version. The original brainstorm's “assumption changed” notification
does not imply background web monitoring is always enabled.

## Acceptance scenarios

- PROV-01/02: save a PDF during a session with a written reason, then inspect it
  later and navigate to the source/project without AI.
- PROV-03–06: mark an assumption disproved, inspect affected decisions and choose
  which to review; no decision text or historical rationale changes automatically.
- PROV-07: supersede a decision and retain its alternatives/rationale in the timeline.
- PROV-08: reject incorrect extracted metadata and keep original bytes plus the
  user's correction, rather than replacing evidence to match the extraction.

## Delivery

Add lightweight capture provenance first where already available. Custom-object
capabilities allow manual decision/assumption records before specialized UI.
Dependency analysis, external monitoring and AI contradiction review come later.
