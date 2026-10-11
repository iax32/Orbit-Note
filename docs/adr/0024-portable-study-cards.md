# ADR 0024 — Portable study cards and deterministic reviews

Status: accepted, 2026-10-09. Scope: STUDY-05 and manual STUDY-03 review states.

## Decision

A card is an `orbit.note`, using its title for the question and Markdown body for
the answer. `properties.studyCard` version 1 owns scheduling, original source
snapshot and review history. Course membership uses existing `course` metadata;
understanding uses `studyUnderstanding` on the original material. Views never
copy or replace a card. No SQLite schema, package or secondary database is added.

Source snapshots retain object UUID, revision, captured UTC time, title, passage,
optional page/checksum and original PDF reference. Editing an answer does not
alter the original note/attachment. Missing or changed sources retain snapshots
and surface warnings. PDF cards reuse existing source/page navigation. OCR cards
verify attachment bytes before creation; corrections remain authored snapshots.

Reviews use an explicit, deterministic rule: Again in ten minutes; Hard at least
one day then previous interval ×1.2 rounded up; Good starts at three days then ×2;
Easy starts at seven days then ×3. Intervals cap at 3,650 days. A day is 24 hours
from the UTC review instant. No adaptive model or inferred mastery is claimed.
Exam horizons filter workload, never permit a future card to be rated early.

Validated repository saves are the authority. Ratings record previous/new due
times and intervals plus rating/time in the same durable note mutation. A failed
write, stale card or paused/future review does not advance the queue. Guarded
session undo restores complete card content/metadata unless later edits exist;
native storage retains the existing bounded before-file recovery history.

Unknown metadata survives. Unsupported card versions stay ordinary readable
notes but are excluded from scheduling; unchanged future records survive unrelated
edits and exports. `orbit-note-study` JSON version 1 exports UUIDs, full properties,
Markdown and extra document data. Normal Vault backup/restore carries cards too.

## Consequences

Cards remain searchable/editable using existing note workflows. The scheduler is
explainable but not a personalized memory predictor. JSON export is an archival
interchange, with no dedicated re-import/Anki adapter in this task. Limits: 2,000
question characters, 100,000 answer/passage characters, 500 course characters,
10,000 review entries per card; history is never silently truncated. Queue refresh
is explicit for clock-only changes. Full Study Resume, Canvas learning-map badges,
cloze/image occlusion, notifications and other scheduling engines remain separate.
