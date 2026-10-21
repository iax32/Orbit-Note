# Life Workspace

Owner-approved scope: 2026-10-21, full twelve-part personal Life proposal.
This extends CTX, TASK, EVT, EDT and CAN using the existing local repository.

## Observable behavior

| ID | Behavior |
| --- | --- |
| LIFE-01 | Configurable Home shows actual scheduled work, goals, routines, sessions and recent entries, with capture and canonical navigation. |
| LIFE-02 | Goals support reasons, constraints, dates, numeric targets, milestones, linked actions/evidence and pause/achieve/retire history. Progress distinguishes linked completion from manual measurements. |
| LIFE-03 | Daily, weekly and chosen-weekday habits support quantity/duration/count, minimum versions, planned breaks, neutral gaps, dated history and restart. Routines retain ordered steps and dated completion. |
| LIFE-04 | Custom exercises, reusable workouts and multiweek programs retain equipment, instructions, substitutions, resources and schedules. Sessions resume after restart, record sets/reps/weight/distance/duration/effort, duplicate sets and rest deadlines. History/charts/comparison distinguish planned from completed and never mix incompatible units. |
| LIFE-05 | Dated journals include intentions/reflections/gratitude/decisions/achievements/travel/nature and weekly/monthly/yearly reviews; free writing and object links remain available. |
| LIFE-06 | Experiments record a reason, baseline, change, observation period, measure, observations and continue/adapt/stop outcomes. |
| LIFE-07 | Optional sleep/mood/energy/stress/outdoor/custom observations retain dates and units. Trends show recorded values and missing data; no inferred diagnosis or causal claim. |
| LIFE-08 | Meals/recipes/groceries, home/maintenance, travel/packing, appointments/renewals/documents, inventories, people/follow-ups and community events connect notes, tasks and calendar records. |
| LIFE-09 | Skills/learning roadmaps link courses, sources, practice records, portfolio evidence, gaps and periodic self-assessments. |
| LIFE-10 | Searchable content packs and reusable personal note/Canvas templates preview editable setup and create ordinary records. Templates run no model/service. |
| LIFE-11 | Goal/weekly/habit/fitness/life/learning/vision/review boards reuse the Canvas engine and canonical cards, including live progress and valid missing-source fallbacks. |
| LIFE-12 | Weekly/monthly/yearly reviews gather actual tasks, habit logs, workouts, practice, journals and upcoming commitments with links. Conclusions are user-written and next actions use ordinary tasks. |

## Data and safety contract

Ordinary note/task/event properties may contain `life` with `version: 1`, `kind`
and validated known fields; Markdown remains editable. Logs have real UUIDs and
explicit parent links. Universal IDs, links, unknown fields and original bodies
survive updates. Unsupported Life versions are displayed without destructive
editing. No migration rewrites existing documents. Personal presentation stays in
device settings. Rest timers store an absolute deadline, not a stream of writes.
Dates use local civil days, including DST; instants use ISO UTC where needed.
Workout units are explicit and trends do not aggregate unlike dimensions.

Mutations go through guarded repository commands and normal save/history. A failed
save must keep a recoverable draft or unchanged original; duplicate submissions
must not multiply dated logs or resumed sessions. Multi-item plans expose partial
completion and can retry by stable action keys; no fake cross-file atomicity.
Core use is offline, with no credential, mandatory account, automatic AI, health
recommendation or background monitoring requirement.

## Acceptance

Create and reopen a linked goal/habit/workout/journal/learning/life plan; discover
the same UUIDs via search, calendar, notes and Canvas. Log quantity/rest/skip/break,
resume a session, compare units and change plans without rewriting old logs.
Generate an evidence-linked review and follow-up task; simulate duplicate actions,
external edits, disk failure, missing links, future metadata and workspace switch.
Verify compact layouts, enlarged text, keyboard paths and portable recovery.

## Using the workspace

Open **Home → Open Life**, the sidebar leaf icon, or **Open Life workspace** in
the command palette. **Set up a Life pack** creates a connected foundations,
training, learning, home or outdoors workspace. Choose a name and your own
quantities/exercises. A failed setup retains its input and reports saved records;
**Retry setup** reuses them. No pack pretends that tracking has already happened.
The searchable starter library also creates individual prepared records.

- **Goals:** choose linked-action or measured progress; write reasons/obstacles,
  set dates, link evidence, and add actual task milestones. Complete linked tasks
  in place or open them in Tasks. State changes use normal recoverable history.
- **Habits:** choose daily/weekly/weekday targets, units, minimum and planned
  breaks. Record an amount, skip or rest for a chosen date. Resaving replaces that
  day's amount. Weekly totals use Monday–Sunday civil days. The heatmap never
  treats an unrecorded day as a failure. Routines snapshot their ordered steps
  into dated logs so later plan edits cannot rename historical completions.
- **Fitness:** create custom exercises and workouts, choose exercises and units,
  then start/resume a workout. Edit/complete/duplicate/remove/add sets, substitute
  an exercise, record effort, and start/clear rest. Completed sessions contribute
  to unit-separated exercise maxima, daily charts and selectable comparisons.
  **Schedule program** rotates workouts across chosen weekdays for 1–26 weeks;
  retries reuse calendar entries. Calendar scheduling creates plans, not results.
- **Journal, experiments and check-ins:** use prepared questions or free Markdown.
  Experiments link dated observations; optional check-ins record only chosen
  values. Custom measurement units are separated in charts. Gaps remain unknown.
- **Learning:** connect parent skills without cycles, courses, practice minutes,
  self-assessment and portfolio resources. **Courses & study** opens the existing
  course and review system rather than copying its records.
- **Life:** meal/recipe/grocery, maintenance/document/renewal, travel/inventory,
  appointment, people/follow-up and event starters combine writing, checklists,
  references, actual tasks and existing Calendar controls. They are user-maintained
  plans, not nutrition advice, contact scraping or external calendar automation.
- **Reviews:** week/month/year snapshots gather dated records and actual task
  completion timestamps. Repeating a period request opens its existing review
  and preserves authored conclusions. Create linked next actions from that review.
- **Templates:** save a note/Canvas here or from its editor's template menu.
  Personal notes appear in the shared note-template picker, including insertion.
  A new Canvas gets fresh spatial identities while its cards keep canonical
  object references. Unknown portable fields survive. Template use creates a new
  object; it never changes the source or deletes referenced objects.
- **Boards:** select canonical records with **Live board** or **Place on Canvas**.
  Card summaries derive current progress. Opening a Life card opens its controls;
  **Open note** still exposes ordinary Markdown. Removing a card removes a placement.

Home section visibility is device-local and resettable by selecting all sections.
Ordinary global search, graph connections, note links, backup/export, Trash and
history remain the same repository-backed systems. No account is required.

## Version 1 fields and boundaries

Known kinds are `goal`, `habit`, `routine`, `exercise`, `workout`, `program`,
`session`, `journal`, `experiment`, `checkin`, `skill`, `practice`, `life`, `review`,
`template`, `habitLog`, `routineLog`. States are active, paused, completed,
archived, retired. Date fields use `YYYY-MM-DD`; timers/started/finished instants
use ISO timestamps. Quantity fields are finite and bounded; weight is kg/lb,
distance m/km/mi, optional effort 0–10, mood/energy/stress 1–5 and sleep 0–24 hours.
Custom quantities retain an authored unit; unlike units are never combined.

`parentId`, `goalId`, `programId`, `workoutId`, `courseId` and reference lists hold
canonical IDs. Session sets have independent IDs and exercise references. Dated
habit/routine action identities are immutable. Personal templates retain body,
portable source properties and optional Canvas data; instantiation removes daily
action identity and remaps known spatial references. Newer/invalid Life metadata
stays readable in the normal note without destructive typed editing.

Sessions support up to 1,000 sets; reference/checklist lists up to 200 entries.
Lists and link pickers paginate. A derived incoming-link index avoids repeated
whole-Vault scans per card. Rest ticking rebuilds its clock only, never the whole
Vault index or saved document. No new package, remote service or database-only
storage layer is introduced. Existing synchronization limitations still apply;
this task does not expand multiplayer transport or add sensor integrations.
