# Feature specifications

These documents turn the chat's feature ideas into concrete product behavior.
They supplement the compact [feature catalog](../product/feature-catalog.md) and
architectural contracts; they do not change the [current task](../tasks/current.md).
Specs describe full target behavior, with exploratory sections. See [implementation status](../planning/implementation-status.md) for working subsets.

## How to use a specification

Each spec contains a purpose, example workflow, stable requirement IDs, data
boundaries, edge cases, acceptance scenarios and staged delivery. A task should
name only the requirement IDs it implements. Requirements describe the eventual
behavior; a minimal slice can implement a clearly identified subset without
pretending the whole feature is finished.

Detailed interaction defaults added while expanding the chat are **proposed product
defaults** until their task accepts them. Existing accepted ADRs, terms and current
task constraints remain binding. Do not treat an example shortcut, timing, schema
or speculative feature as an already-selected implementation decision.

| IDs | Specification | Earliest relevant stage |
|---|---|---|
| CAP | [Capture and Inbox](capture-and-inbox.md) | M1–M2 |
| EDT | [Markdown and editing](markdown-and-editing.md) | M1–M2 |
| ORG | [Objects and organization](objects-and-organization.md) | M1–M5 |
| LNK | [Search, links and graph](search-links-and-graph.md) | M2; graph M5 |
| VIEW | [Collections and views](collections-and-views.md) | M5 |
| TASK | [Tasks, calendar and planning](tasks-calendar-and-planning.md) | M2 basics; M5 advanced |
| CAN | [Spatial boards](spatial-boards.md) | M3; advanced M5+ |
| INK | [Freeform pages and ink](freeform-and-ink.md) | M4 |
| FILE | [Attachments and research](attachments-and-research.md) | M2; annotations M4 |
| PORT | [Import, export and portability](import-export-and-portability.md) | M1 onward |
| NAV | [Shell and navigation](shell-and-navigation.md) | M0 subset; M2/M5 |
| LAY | [Customization and Spaces](customization-and-spaces.md) | M5+ |
| CTX | [Home and work sessions](home-and-work-sessions.md) | M5; AI M8 |
| PROV | [Decisions, assumptions and provenance](decisions-and-provenance.md) | M5+ |
| HIST | [History and recovery](history-and-recovery.md) | M1 onward |
| AI | [AI and knowledge health](ai-and-knowledge-health.md) | M8; deterministic checks earlier |
| EXT | [Plugins, APIs and automation](plugins-apis-and-automation.md) | M7+ |
| SYNC | [Sync and collaboration](sync-and-collaboration.md) | M6; collaboration later |

Use [user journeys](../product/user-journeys.md) for integration expectations,
[quality requirements](../product/quality-requirements.md) for cross-cutting checks,
[source extraction](../product/conversation-extraction.md) for idea provenance,
and [open questions](../planning/open-questions.md) for unresolved decisions.

New specifications can use [the feature template](TEMPLATE.md). Keep IDs stable;
retire a requirement with a reason rather than silently reusing its number.

## Additional workflows and quality contracts

| IDs | Specification |
|---|---|
| DES | [Desktop interactions](desktop-interactions.md) |
| EVT | [Calendars and events](calendar-and-events.md) |
| STUDY | [Study and university](study-and-university.md) |
| DEV | [Software development](software-development.md) |
| REV | [Reverse engineering](reverse-engineering.md) |
| GAME | [Game development and teams](game-development-and-teams.md) |
| COMP | [Compatibility/migrations](../architecture/compatibility-and-migrations.md) |
| MOT | [Motion system](../design/motion.md) |

The [single backlog](../planning/feature-backlog.md) classifies every requirement.
S10 also expands earlier specs; their older source lists indicate original
provenance rather than excluding the later brief. See the source map for coverage.
