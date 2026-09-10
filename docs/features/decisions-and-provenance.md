# Decisions, assumptions and provenance

Status: planned M5+; automatic assumption/contradiction analysis exploratory M8+.
Sources: S04, S06, S07 in the [source map](../product/conversation-extraction.md).
Architecture: [universal objects](../architecture/universal-object-model.md),
[AI](../architecture/ai.md).

## Purpose and workflow

A project contains more than notes: why something was saved, what was decided,
which alternatives were rejected and what assumptions remain uncertain. A user
saves a source while researching sync, records “Use an optional self-hostable
backend” as a decision, and links it to the assumption that offline work must
remain available. Months later that context is still inspectable.

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
