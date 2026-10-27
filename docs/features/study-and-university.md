# Study and university workflows

Status: optional presets plus delivered review subset below. Source: S10. Reuse objects, views, calendar,
Canvas, PDF and [continuity](home-and-work-sessions.md); no separate study database.

| ID | Observable behavior |
|---|---|
| STUDY-01 | A Study Space preset connects courses, lecture/reading notes, assignments, PDFs, exam dates and study sessions through existing types and views. |
| STUDY-02 | Cornell-style note and lecture Canvas templates provide editable starting layouts without imposing a new content format. |
| STUDY-03 | Concept maps/learning maps show related material and explicit understanding/review status; a graph edge does not imply the user understands a concept. |
| STUDY-04 | Study Resume Context restores reading/writing position and relevant unfinished work; related material resurfaces with an explanation and dismissal control. |
| STUDY-05 | Later flashcards and spaced repetition define card provenance, scheduling/history and export before introducing review queues. |

Workflow: capture a lecture, link an uncertain concept to a PDF highlight, mark it
for review, and resume before the exam from the same course context. Presets are
optional and removable without deleting notes. Template upgrades must not rewrite
user-edited documents. Acceptance: switch out of Study Space and find the same
notes in universal search; reopen a session with a removed PDF and show a useful
missing-resource state. The original later-scheduling target is superseded by the
fixed-rule delivery below; adaptive learning remains separate.

## Delivered Study & Review — 2026-10-09

Course dashboards also open Assignments & exams. The Calendar planning workspace
creates ordinary course tasks/events with explicit estimates and UUID resource
links. Linked study sessions reference the same assignment/exam. Exam details show
the existing course review workload through the recorded exam date and open Study
& Review with that horizon; choosing a horizon never reschedules review cards.
This is the planning part of STUDY-01, not an automatic exam preparation algorithm.

STUDY-05 now has Markdown cards with portable provenance/schedule/history and a
local review queue. Enter Study & Review from Home/workspace toolbars or a course
dashboard. Review reveals Markdown answers before Again/Hard/Good/Easy ratings;
Space reveals and keys 1–4 rate. Cards can be edited, paused, opened as notes,
exported or inspected for history. Refresh queue updates clock-only due changes.

Material lists filter by course/search and offer explicit uncertain, learning or
understood states (manual STUDY-03 subset). Reviews do not infer understanding.
Create cards from selected note text, extracted PDF highlight/quote notes, or
selected recognized text in OCR review. Captured passages retain source UUID,
revision/time, page/checksum when present, and return navigation. Missing/edited
sources warn without deleting evidence. Source documents and bytes stay intact.

Course queues show due-now, next-seven-day/exam-horizon workload and paused counts.
The chosen horizon is temporary UI state; it does not reschedule or allow early
reviews. Scheduling uses fixed UTC intervals and history, with guarded durable
saves/undo and existing recovery/backup. Unsupported versions remain ordinary
notes, excluded from scheduling and included in export.

Rules, limits and boundaries: [ADR 0024](../adr/0024-portable-study-cards.md) and
[implemented formats](../architecture/implemented-formats.md). No dedicated JSON
re-import, Anki integration, adaptive scheduler, cloze/image occlusion, automatic
exam plan, notification or new Canvas learning-map renderer is claimed. Broader
STUDY-01–04 learning-map and broader Space criteria remain separate from this delivery.

## Delivered manual Study Resume — 2026-10-09

Select a course in Study & Review and expand Continue studying. Write the next
step and Save current position while course notes/PDFs/Canvas tabs are open.
Resume course merges these tabs into the workspace, restoring supported note
cursor/scroll/collapse, PDF page/zoom and Canvas camera state. A changed source
resets its position with an explanation; deleted sources are skipped, and a
fully missing continuation gives a start-again message. Missing attachment bytes
retain the reader's existing recovery choices. This restores views of current
content, never historical text or original files.

Unfinished work comes from current incomplete course tasks. Related material is
limited to same-course objects explicitly marked uncertain, with that reason
shown. Dismissal persists until Reset suggestions; no speculative relevance is
inferred. Continuations remain device-local, manual, one per course, bounded by
the existing 30 saved contexts. Failed saves are reported. STUDY-04 and the
manual CTX-08–11 subsets are supported; automatic tracking remains separate.

## Connected course hub — 2026-10-13

Explorer's Courses button and the command palette open Courses & study progress.
Add a course with name/code, semester, fractional ECTS and lecturer. Existing
overview notes are discovered automatically. Search and semester/status filters
expose active, passed and archived courses. Editable display names leave authored
Markdown and existing paths untouched. Passed ECTS require an explicit Passed
status; task completion never infers a grade or earned credits.

Each course shows independent assignment completion, solved practice and manually
understood concept counts, plus overdue tasks and linked material. Create lecture
notes, practice Canvases and assignments; link existing objects or remove course
membership without deleting them. Membership prefers optional courseId (overview
UUID), then legacy folders/labels. An explicit empty ID means detached. Same-name
courses in different parent folders remain separate in this hub and its linked
views, Study & Review and course continuations. Source-linked cards inherit a
matching source course ID. Legacy name-based entry points continue to work.

Course planning opens existing assignment/exam/study scheduling; items created
from the hub retain course ID and folder, without inheriting an unrelated active
project. Read-only courses remain readable. Metadata saves preserve concurrent
body/unrelated property edits and reject overlapping stale form changes. Template
setup stops on save failure or changed Vault; completed items are retained and
discoverable, with an explanation. Setup is not a multi-file atomic transaction.
Duplicate course folders are rejected rather than silently mixing their records.

Open study board creates/reopens a normal Canvas with three editable columns,
canonical course/material cards and two live saved queries: course material and
open assignments. Initial placements include at most 18 material objects; query
cards continue to reflect current sources. Later captures are ordinary Canvas
operations. Removing a placement never removes a course, task or source. This
reuses existing Canvas references, captions, checklists, links and layout tools;
it does not claim complete Milanote/Notion feature parity, timetable imports,
automatic grading or a new course-specific database.

## University modeling and engineering lab — 2026-10-26

Owner-approved STUDY-06–12 extend CAN/EDT/DEV/PORT with the shared offline
[University Lab](university-modeling-lab.md): state/activity replay, structural UML
checks, test evidence, Java/SMQP, distributed traces and explicit Dafny adapters.
The specification records operational subsets, native-tool prerequisites,
portable data and acceptance limits. It does not claim full UML/IDE certification.
