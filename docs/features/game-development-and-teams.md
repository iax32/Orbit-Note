# Game development and team project presets

Status: planned optional presets; collaboration is later. Source: S10.

| ID | Observable behavior |
|---|---|
| GAME-01 | A game project preset connects a Game Design Document, roadmap, milestones, backlog, bugs, assets/references, characters, levels, mechanics and ideas using editable types/templates. |
| GAME-02 | Playtest findings link to decisions, tasks, resources and relevant designs; references and GitHub resources retain provenance. |
| GAME-03 | Personal project boards show owners, deadlines, dependencies and resource attachments without requiring a team account. |
| GAME-04 | Later shared Canvas/calendar, assignment and contextual comments use the common collaboration permissions and review model; this is not a chat replacement. |

Example: a playtest finding references a level, leads to a mechanics decision and
creates a linked task. Moving the task on a board updates its existing object.
A local owner/Person relation is descriptive until an authenticated membership is
established; it is not access control. Acceptance: remove the preset and retain all
objects; revoke access to a shared asset and ensure embedded previews/search do
not leak its content. See [collaboration](sync-and-collaboration.md).

## Delivered documentation subset — 2026-09-11

From a PDF, Create document offers Game design decision and Playtest finding alongside
Research note. These are editable ordinary Markdown starters linked to the PDF UUID,
page and source checksum. Selected PDF text can supply quoted evidence. The note
opens beside the reader. Design sections cover player experience, constraints,
options, tradeoffs, code/assets/level references and validation. Playtest sections
cover build/session, hypothesis, observations, reproduction, impact, proposed change,
linked decisions/tasks and follow-up checks. Users author the content and links.

This is a small GAME-02 documentation workflow, not completion of GAME-01/02.
There is no preset/type registry, automatic task creation, GitHub connection, team
assignment or project scaffolding. Existing notes remain normal Markdown if starter
choices change. The full editable game-project preset remains subject to PRE-07.
