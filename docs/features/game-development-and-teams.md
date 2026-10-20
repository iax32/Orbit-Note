# Game development and team project presets

## Project source investigations — 2026-10-13

Browse source files on Game dashboards now supports all-file scoped search and
Save evidence note. Exact-line search navigation checks the current file hash;
stale results never select a possibly wrong line. Saved working-tree evidence
retains source path/range/text/hashes and links the dashboard/project context.
It saves in the project's Programming folder and can be linked to mechanics,
playtests, tasks or Canvas using existing object controls. Gameplay's Capture from
source file also has the shared folder search. These are local technical knowledge
bridges, not source-file editing, automatic Git verification or engine execution.
See the software-development specification for bounds and failure handling.


## Narrative and asset planning — 2026-10-11

Story, character, world, dialogue, branching-quest and game-narrative Markdown
templates provide editable planning structures and production checks. OBJ/GLB
attachments have an offline static-geometry viewer and canonical Canvas cards,
so reference boards can link model originals without duplicating them. Texture,
rig and animation previews remain outside this delivery.

## Playtest and release review — 2026-10-10

Open Playtest & Release from Gameplay workbench. It aggregates the mechanics in
that workbench's project/folder scope and their canonical linked records/tasks.
Select baseline and release builds explicitly. Task rows show the latest
verification for each chosen build; a pass on another build is never reused.
Filter failed fixes, blocked tests, awaiting retest, passed-but-open tasks, or
verified completed tasks. Baseline-pass/target-fail counts are recorded regressions,
not inferred game behaviour. Both builds' playtest findings remain browsable.

Evidence expands beside each finding/result with its saved text, source-change
warning, missing-link labels and open-original actions for screenshots/code/design
records. The release summary counts tasks needing attention, findings without a
linked fix task, and incomplete plan coverage. No recorded checks means coverage
is unknown, not that a build is ready. Tasks are never automatically closed.

Reusable plan presets cover mechanics, levels, controls, saves and performance.
Choose a mechanic and edit the Markdown checklist before saving an ordinary note.
Start run with a build identifier creates a new unchecked note retaining the
plan UUID/revision, linked evidence and unknown properties. Edit its original
checklist/observations through Rich or Source. Set pending/passed/failed/blocked
in the release view. A pass requires a nonempty, fully checked checklist outside
fenced code examples. The newest run per plan/build supplies coverage; a changed
plan revision invalidates that coverage until retested. Old runs/plans remain.
Limits: 1–200 checklist items, 20,000-character plan body, 300-character title/build.
Failed verdict saves retain dirty recoverable edits; stale forms reject changes.
Existing note/JSON authority, document history, unknown-data preservation and
offline operation apply. This is manual evidence review; no engine execution,
automated tests, per-check outcomes, image-preview comparison or certification.

2026-10-10 source capture: Attach code reference can browse a local source folder,
select exact lines and prefill repository/path/range/excerpt. Capture clears any
previous revision claims; enter and verify the immutable commit before saving.
External files remain read-only. See software-development.md for clipboard,
range selection and language support.

## Connected gameplay workbench — 2026-10-10

Open Gameplay workbench from a Game dashboard. Select an existing Mechanic Spec
or create an empty specification. The workspace shows readable specification/evidence
beside linked tasks, diagrams, decisions, attachments, code citations and playtests.
Open beside specification uses existing primary/secondary editors and readers;
original UUID objects remain authoritative. Sources have text/build filters and
30-item pagination. Explicit resource links can be removed without deleting originals;
missing links have a remove-link control.

Attach code reference records repository label/location, relative path, line range,
full 40/64-character commit, optional captured branch and literal source excerpt.
Manual capture works offline with no repository access; a branch never substitutes
for an immutable commit. Record playtest requires tested build, expected behaviour
and observations; link existing screenshot, decision, code or other evidence.
Create fix task retains originating playtest UUID, mechanic UUID and tested build.
Verify fix adds a new ordinary note for a chosen task with tested build, expected/
observed behaviour, passed/failed/blocked outcome and optional implementation evidence.
Earlier results remain visible; the newest result appears on the task's workbench card.
Verification does not silently complete/reopen tasks. Source-version warnings retain
the captured evidence when a source changes or disappears. Edit records through the
ordinary note editor and recover changes through existing document history.

Continue development saves a written next step and mechanic-related open tabs/view
positions in the device-local context library. Resume merges those tabs, preserves
unrelated tabs/appearance, skips missing sources and resets positions for changed
sources. Unfinished tasks come from current canonical tasks, not saved copies.
The workbench itself is reopened through the dashboard; it is not a new editor type.

Limits: 100 explicit mechanic resources, 40 record evidence links, 100,000-character
code excerpts, 20,000-character expectation/observation, existing 30-context library.
Record creation is a single ordinary save. Finding conversion spans task and source
files; partial backlink failure is reported with the created task retained. No atomic
multi-file transaction, Git inspection/file opening, IDE adapter, engine integration,
code execution, automatic test run, video timeline or shared team session is claimed.
This delivers local GAME-01–03/DEV-02–04 workflow subsets, not GAME-04 collaboration.

Creative planning/code refinement (2026-10-09): New Note from Template includes a
Creative Project Brief with optional fill-in details, Storyboard & Shot Plan,
Prototype & Playtest Plan, and HTML/CSS/C++/JavaScript source starters. These are
portable Markdown notes. Expand code editor opens a draft with search, wrapping,
indentation and undo; Apply updates the owning note only if its source is still
current. No code execution, external source-file editing or language server is
included. Brief checklists do not silently create duplicate task objects.
The expanded draft also supports find/replace, go-to-line, line movement and
duplication, supported line comments and configurable indentation; see
[code editing tools](software-development.md#expanded-code-editing--2026-10-10-dev-01--edt-09-subset).

Status: delivered and validated (GAME-01, GAME-02, GAME-03); team collaboration is later. Source: S10.

2026-10-03 readability refinement: project dashboard uses a bounded reading width,
responsive metric/section columns and wrapping actions including Open GDD. Bug
and task dialogs scroll at enlarged app zoom and reject empty submissions.
Project-health metrics use plain grouped values. New Game Project boards set
Tasks only by default; older generic boards retain their membership and offer
an explicit Tasks only filter. Both board presentations map todo onto the Game
Dev Planned column without changing the stored task status. Production milestone
content is bounded to 1080 logical pixels.

| ID | Observable behavior |
|---|---|
| GAME-01 | A game project preset connects a Game Design Document, roadmap, milestones, backlog, bugs, assets/references, characters, levels, mechanics and ideas using editable types/templates. |
| GAME-02 | Playtest findings link to decisions, tasks, resources and relevant designs; references retain provenance. |
| GAME-03 | Personal project boards show owners, deadlines, dependencies, estimates, and resource attachments without requiring a team account. |
| GAME-04 | Later shared Canvas/calendar, assignment and contextual comments use the common collaboration permissions and review model; this is not a chat replacement. |

Example: a playtest finding references a level, leads to a mechanics decision and
creates a linked task. Moving the task on a board updates its existing object.
A local owner/Person relation is descriptive until an authenticated membership is
established; it is not access control. Acceptance: remove the preset and retain all
objects; revoke access to a shared asset and ensure embedded previews/search do
not leak its content. See [collaboration](sync-and-collaboration.md).

## Implementation Details & Features (Delivered 2026-09-12)

### 1. Invariant: "CREATE ONCE. VIEW ANYWHERE."
- Tasks, notes, and canvases are standard `UniversalObject` entries (`orbit.task`, `orbit.note`, `orbit.canvas`, `orbit.view`).
- No separate or divergent task system; no isolated game database.
- A single task exists once with universal ID and properties (`discipline`, `milestone`, `estimate`, `blockedBy`, `severity`, `platform`, `build`, `isBug`), viewed seamlessly across List, Kanban, Dashboard, Milestones, and Timeline.

### 2. Project Scaffolding & Subfolder Hierarchy
`createGameProject(projectName, ...)` automatically scaffolds:
- Folder structure: `Games/<Name>` with subfolders: `Design`, `Art`, `Programming`, `Audio`, `Narrative`, `Levels`, `Production`, `Playtests`, `Reference`.
- Starter Notes:
  - Game Design Document (GDD) with Core Pillars, Target Audience, Camera & Controls, Core Loop, Progression, Art & Audio pillars, and Milestones.
  - Core Mechanics Spec note.
- Canvases:
  - `Core Loop` (preset: `core_loop`)
  - `Art Direction & Moodboard` (preset: `moodboard`)
  - `Game Roadmap` (preset: `game_roadmap`)
- 7 Scoped Views:
  - `Dashboard` (`game_dashboard`)
  - `Board` (`board`, 6-stage `gamedev` preset)
  - `Backlog` (`tasks`)
  - `Current Focus` (`tasks`, filtered by in-progress, urgent, and blocked)
  - `Bugs` (`board`, 5-stage `bugs` preset)
  - `Milestones` (`milestones`)
  - `Roadmap` (`timeline`)

### 3. Comprehensive Specialized Templates Suite
Directly accessible from folder context menus and workspace controller:
- **GDD Note**: Comprehensive design documentation.
- **Feature Spec**: Gameplay systems and technical specifications.
- **Mechanic Spec**: Input rules, juice/feedback, edge cases, failure conditions.
- **Enemy Design**: Roles, HP, movement, attacks, AI state transitions, drops.
- **Character Profile**: Visual turnaround, lore, dialogue voice, abilities.
- **Item / Weapon Spec**: Category, rarity, stats, crafting recipes, balance notes.
- **Audio Planning**: Cue tracker table (SFX, Music, Ambient, Voice), priority, format.
- **Quest Spec**: Objectives, narrative beats, multi-stage flow, fail conditions.
- **Release Checklist**: Build verification, QA stability, Store assets, Disaster recovery.
- **Weekly Review**: Accomplished items, blockers, velocity/burnup, goals, risks.
- **Risk Assessment**: Description, impact/likelihood, mitigation strategies, triggers.
- **Architecture Decision Record (ADR)**: Evaluated options, tradeoffs, rationale.

### 4. Playtest Finding → Task Conversion (`createTaskFromFinding`)
- Direct conversion of playtest observations into actionable universal tasks.
- Automatically sets `isBug`, `severity`, `discipline`, `priority`, and records `sourceNoteId`.
- Automatically appends a bidirectional markdown reference link `[[finding]]` in the source playtest session note.
- As of 2026-10-03, both directions use stable object-ID wiki links rather than
  title lookup; the playtest also records `findingTaskIds`. Source edits made while
  creating the task are retained, and the backlink is flushed through normal save/
  recovery handling. Missing/read-only source notes cannot create orphan tasks.

### 5. Project Structure Duplication (`duplicateGameProjectStructure`)
- Clones full folder hierarchy and scoped view configurations for new game iterations or sequels.
- Resets scope and folders cleanly without duplicating completed historical tasks.

### 6. Estimation & Kanban Pipeline
- 6-Stage Game Dev Pipeline: `Backlog` → `Planned` → `In Progress` → `Review` → `Testing / QA` → `Done`.
- 5-Stage Bug Pipeline: `New` → `Confirmed` → `In Progress` → `Verify` → `Done`.
- Estimation support: Fibonacci story points (`1`, `2`, `3`, `5`, `8`, `13`) and T-Shirt sizing (`XS`, `S`, `M`, `L`, `XL`).
- Full estimation sorting (`sortOption == 'estimate'`) and card badges.

### 7. Canvas Spatial Templates
- `Playtest Feedback Board`: 4-column structured review (Worked Well, Confusing/Friction, Bugs & Crashes, Ideas & Must Fix).
- `Narrative & Quest Board`: 3-act storytelling layout with plot cards.
- `Game Architecture & Systems`: Core engine and manager subsystem cards (Input, Controller, Combat, Animation/VFX, Save Manager).

## Connected creative planning subset — 2026-10-09

New Creative Project in the Notes folder menu creates a folder with an editable
brief, decision log, references Canvas, project Canvas, four starter tasks, task
view and milestone view. The brief UUID is the shared project scope; readable
projectName metadata does not replace identity. Brief links and Canvas cards refer
to canonical objects. Task bodies/resources link the brief, references and decisions.

Milestone views accept optional milestoneStages (nonempty strings, deduplicated,
up to 40 entries). Missing/invalid/empty lists retain the game pipeline defaults;
task milestones not in the configured list still appear. Creation uses normal
validated repository saves and rejects existing project folders. Interrupted setup
retains saved items and reports incomplete setup; no destructive rollback or
automatic resume is claimed. No new object type or storage migration is needed.
