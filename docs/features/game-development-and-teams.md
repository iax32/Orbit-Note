# Game development and team project presets

Status: delivered and validated (GAME-01, GAME-02, GAME-03); team collaboration is later. Source: S10.

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
