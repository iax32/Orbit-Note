# Canonical feature backlog

Status: canonical release classification. Requirements describe full target behavior.
Working subsets are tracked in [implementation status](implementation-status.md). The
[current task](../tasks/current.md) defines active scope. Do not duplicate requirements.

| Class | Meaning |
|---|---|
| F | Foundation / required prerequisite or quality gate, applied when its feature ships. Not all are M0 work. |
| V1 | Orbit 1.0 candidate; a deliberately selected release cut, not a promise to ship every candidate. |
| P1 | Post-1.0; useful but deferred behind a polished local core. |
| X | Experimental / future; feasibility and product value must be validated. |

Priority: harden durable/recoverable M1, then extend connected M2, shared Canvas
M3, basic ink M4, and selected structured views/manual context M5. Gate a release
on data ownership, compatibility and desktop quality. Sync M6, plugins M7 and AI
M8 follow independently scoped designs. No dates or completeness claims are implied.

Each row links to the sole behavioral definition. Dependencies refer to
[prerequisites](open-questions.md); gates can mature incrementally. A combined
requirement is classified for its full behavior: a smaller core slice can be
scheduled earlier explicitly, while clauses marked later remain later. Examples:
basic image viewing before crop, recorded summaries before AI, local calendars
before external integration. Such a task must state its subset and leave the
remaining requirement planned. Do not interpret a row as a giant implementation task.

## AI assistance and knowledge health

| Requirement | Class | Sequence | Major prerequisites |
|---|---|---|---|
| [AI-01](../features/ai-and-knowledge-health.md) | F | M1 onward | PRE-01 |
| [AI-02](../features/ai-and-knowledge-health.md) | P1 | M8 | PRE-11, PRE-02 |
| [AI-03](../features/ai-and-knowledge-health.md) | P1 | M8 | PRE-11, PRE-02 |
| [AI-04](../features/ai-and-knowledge-health.md) | P1 | M8 | PRE-11, PRE-02 |
| [AI-05](../features/ai-and-knowledge-health.md) | P1 | M8 | PRE-11, PRE-02 |
| [AI-06](../features/ai-and-knowledge-health.md) | P1 | M8 | PRE-11, PRE-02 |
| [AI-07](../features/ai-and-knowledge-health.md) | P1 | M8 | PRE-11, PRE-02 |
| [AI-08](../features/ai-and-knowledge-health.md) | X | M8+ | PRE-11 |
| [AI-09](../features/ai-and-knowledge-health.md) | P1 | M5 deterministic; M8 semantic | PRE-07, PRE-11 |
| [AI-10](../features/ai-and-knowledge-health.md) | X | M8+ | PRE-11 |
| [AI-11](../features/ai-and-knowledge-health.md) | P1 | M8 | PRE-11, PRE-02 |
| [AI-12](../features/ai-and-knowledge-health.md) | P1 | M8 | PRE-11, PRE-02 |
| [AI-13](../features/ai-and-knowledge-health.md) | P1 | M8 | PRE-11, PRE-02 |
| [AI-14](../features/ai-and-knowledge-health.md) | P1 | M8 | PRE-11, PRE-02 |
| [AI-15](../features/ai-and-knowledge-health.md) | P1 | M5 deterministic; M8 semantic | PRE-07, PRE-11 |
| [AI-16](../features/ai-and-knowledge-health.md) | P1 | M8 | PRE-11, PRE-02 |

## Attachments, media and research

| Requirement | Class | Sequence | Major prerequisites |
|---|---|---|---|
| [FILE-01](../features/attachments-and-research.md) | V1 | M2–M4 | PRE-04, PRE-08 |
| [FILE-02](../features/attachments-and-research.md) | V1 | M2–M4 | PRE-04, PRE-08 |
| [FILE-03](../features/attachments-and-research.md) | V1 | M2–M4 | PRE-04, PRE-08 |
| [FILE-04](../features/attachments-and-research.md) | V1 | M2–M4 | PRE-04, PRE-08 |
| [FILE-05](../features/attachments-and-research.md) | V1 | M2–M4 | PRE-04, PRE-08 |
| [FILE-06](../features/attachments-and-research.md) | V1 | M2–M4 | PRE-04, PRE-08 |
| [FILE-07](../features/attachments-and-research.md) | P1 | After local core | PRE-03, PRE-04, PRE-08 |
| [FILE-08](../features/attachments-and-research.md) | P1 | After local core | PRE-03, PRE-04, PRE-08 |
| [FILE-09](../features/attachments-and-research.md) | V1 | M2–M4 | PRE-04, PRE-08 |
| [FILE-10](../features/attachments-and-research.md) | P1 | After local core | PRE-03, PRE-04, PRE-08 |
| [FILE-11](../features/attachments-and-research.md) | V1 | M2–M4 | PRE-04, PRE-08 |
| [FILE-12](../features/attachments-and-research.md) | P1 | M4+ | PRE-03, PRE-04, PRE-05 |
| [FILE-13](../features/attachments-and-research.md) | P1 | M4+ | PRE-03, PRE-04, PRE-05 |
| [FILE-14](../features/attachments-and-research.md) | P1 | After local core | PRE-03, PRE-04, PRE-08 |

## Calendars and event context

| Requirement | Class | Sequence | Major prerequisites |
|---|---|---|---|
| [EVT-01](../features/calendar-and-events.md) | V1 | M5 | PRE-07 |
| [EVT-02](../features/calendar-and-events.md) | V1 | M5 | PRE-07 |
| [EVT-03](../features/calendar-and-events.md) | V1 | M5 | PRE-07 |
| [EVT-04](../features/calendar-and-events.md) | P1 | After M6 authorization | PRE-09, PRE-10 |
| [EVT-05](../features/calendar-and-events.md) | P1 | After M6 authorization | PRE-09, PRE-10 |

## Capture and Inbox

| Requirement | Class | Sequence | Major prerequisites |
|---|---|---|---|
| [CAP-01](../features/capture-and-inbox.md) | V1 | M1–M2 | PRE-01 |
| [CAP-02](../features/capture-and-inbox.md) | V1 | M1–M2 | PRE-01 |
| [CAP-03](../features/capture-and-inbox.md) | V1 | M1–M2 | PRE-01 |
| [CAP-04](../features/capture-and-inbox.md) | V1 | M1–M2 | PRE-01 |
| [CAP-05](../features/capture-and-inbox.md) | P1 | After local core | PRE-03, PRE-04, PRE-08 |
| [CAP-06](../features/capture-and-inbox.md) | P1 | After local core | PRE-03, PRE-04, PRE-08 |
| [CAP-07](../features/capture-and-inbox.md) | V1 | M1–M2 | PRE-01 |
| [CAP-08](../features/capture-and-inbox.md) | V1 | M1–M2 | PRE-01 |
| [CAP-09](../features/capture-and-inbox.md) | P1 | After local core | PRE-03, PRE-04, PRE-08 |

## Collections and structured views

| Requirement | Class | Sequence | Major prerequisites |
|---|---|---|---|
| [VIEW-01](../features/collections-and-views.md) | V1 | M5 | PRE-07 |
| [VIEW-02](../features/collections-and-views.md) | V1 | M5 | PRE-07 |
| [VIEW-03](../features/collections-and-views.md) | V1 | M5 | PRE-07 |
| [VIEW-04](../features/collections-and-views.md) | V1 | M5 | PRE-07 |
| [VIEW-05](../features/collections-and-views.md) | V1 | M5 | PRE-07 |
| [VIEW-06](../features/collections-and-views.md) | V1 | M5 | PRE-07 |
| [VIEW-07](../features/collections-and-views.md) | V1 | M5 | PRE-07 |
| [VIEW-08](../features/collections-and-views.md) | P1 | M5–M8 | PRE-07, PRE-11 |
| [VIEW-09](../features/collections-and-views.md) | X | Future | PRE-02, PRE-05, PRE-12 |
| [VIEW-10](../features/collections-and-views.md) | V1 | M5 | PRE-07 |
| [VIEW-11](../features/collections-and-views.md) | P1 | M5–M8 | PRE-07, PRE-11 |

## Compatibility and migrations

| Requirement | Class | Sequence | Major prerequisites |
|---|---|---|---|
| [COMP-01](../architecture/compatibility-and-migrations.md) | F | M1+ as applicable | PRE-08 |
| [COMP-02](../architecture/compatibility-and-migrations.md) | F | M1+ as applicable | PRE-08 |
| [COMP-03](../architecture/compatibility-and-migrations.md) | F | M1+ as applicable | PRE-08 |
| [COMP-04](../architecture/compatibility-and-migrations.md) | F | M1+ as applicable | PRE-08 |
| [COMP-05](../architecture/compatibility-and-migrations.md) | F | M1+ as applicable | PRE-08 |
| [COMP-06](../architecture/compatibility-and-migrations.md) | F | M1+ as applicable | PRE-08 |

## Customization, layouts, themes and Spaces

| Requirement | Class | Sequence | Major prerequisites |
|---|---|---|---|
| [LAY-01](../features/customization-and-spaces.md) | V1 | M5 | PRE-06, PRE-13 |
| [LAY-02](../features/customization-and-spaces.md) | P1 | M5+ | PRE-06, PRE-13 |
| [LAY-03](../features/customization-and-spaces.md) | V1 | M5 | PRE-06, PRE-13 |
| [LAY-04](../features/customization-and-spaces.md) | V1 | M5 | PRE-06, PRE-13 |
| [LAY-05](../features/customization-and-spaces.md) | P1 | M5+ | PRE-06, PRE-13 |
| [LAY-06](../features/customization-and-spaces.md) | V1 | M5 | PRE-06, PRE-13 |
| [LAY-07](../features/customization-and-spaces.md) | P1 | M5+ | PRE-06, PRE-13 |
| [LAY-08](../features/customization-and-spaces.md) | P1 | M5+ | PRE-06, PRE-13 |
| [LAY-09](../features/customization-and-spaces.md) | P1 | M5+ | PRE-06, PRE-13 |
| [LAY-10](../features/customization-and-spaces.md) | F | With customization | PRE-13 |

## Decisions, assumptions and provenance

| Requirement | Class | Sequence | Major prerequisites |
|---|---|---|---|
| [PROV-01](../features/decisions-and-provenance.md) | P1 | M5+ | PRE-07 |
| [PROV-02](../features/decisions-and-provenance.md) | P1 | M5+ | PRE-07 |
| [PROV-03](../features/decisions-and-provenance.md) | P1 | M5+ | PRE-07 |
| [PROV-04](../features/decisions-and-provenance.md) | P1 | M5+ | PRE-07 |
| [PROV-05](../features/decisions-and-provenance.md) | P1 | M5+ | PRE-07 |
| [PROV-06](../features/decisions-and-provenance.md) | P1 | M5+ | PRE-07 |
| [PROV-07](../features/decisions-and-provenance.md) | P1 | M5+ | PRE-07 |
| [PROV-08](../features/decisions-and-provenance.md) | P1 | M5+ | PRE-07 |

## Desktop interaction quality

| Requirement | Class | Sequence | Major prerequisites |
|---|---|---|---|
| [DES-01](../features/desktop-interactions.md) | F | M2–M4 as applicable | PRE-03, PRE-04 |
| [DES-02](../features/desktop-interactions.md) | F | M2–M4 as applicable | PRE-03, PRE-04 |
| [DES-03](../features/desktop-interactions.md) | F | M2–M4 as applicable | PRE-03, PRE-04 |
| [DES-04](../features/desktop-interactions.md) | F | M2–M4 as applicable | PRE-03, PRE-04 |
| [DES-05](../features/desktop-interactions.md) | F | M2–M4 as applicable | PRE-03, PRE-04 |
| [DES-06](../features/desktop-interactions.md) | F | M2–M4 as applicable | PRE-03, PRE-04 |
| [DES-07](../features/desktop-interactions.md) | F | M2–M4 as applicable | PRE-03, PRE-04 |
| [DES-08](../features/desktop-interactions.md) | F | M2–M4 as applicable | PRE-03, PRE-04 |
| [DES-09](../features/desktop-interactions.md) | P1 | M4+ | PRE-04 |

## Freeform pages, handwriting and drawing

| Requirement | Class | Sequence | Major prerequisites |
|---|---|---|---|
| [INK-01](../features/freeform-and-ink.md) | V1 | M4 | PRE-05 |
| [INK-02](../features/freeform-and-ink.md) | V1 | M4 | PRE-05 |
| [INK-03](../features/freeform-and-ink.md) | V1 | M4 | PRE-05 |
| [INK-04](../features/freeform-and-ink.md) | V1 | M4 | PRE-05 |
| [INK-05](../features/freeform-and-ink.md) | V1 | M4 | PRE-05 |
| [INK-06](../features/freeform-and-ink.md) | V1 | M4 | PRE-05 |
| [INK-07](../features/freeform-and-ink.md) | V1 | M4 | PRE-05 |
| [INK-08](../features/freeform-and-ink.md) | V1 | M4 | PRE-05 |
| [INK-09](../features/freeform-and-ink.md) | X | Future | PRE-02, PRE-05, PRE-12 |
| [INK-10](../features/freeform-and-ink.md) | V1 | M4 | PRE-05 |
| [INK-11](../features/freeform-and-ink.md) | V1 | M4 | PRE-05 |

## Game development and team project presets

| Requirement | Class | Sequence | Major prerequisites |
|---|---|---|---|
| [GAME-01](../features/game-development-and-teams.md) | P1 | M5+ | PRE-07 |
| [GAME-02](../features/game-development-and-teams.md) | P1 | M5+ | PRE-07 |
| [GAME-03](../features/game-development-and-teams.md) | P1 | M5+ | PRE-07 |
| [GAME-04](../features/game-development-and-teams.md) | P1 | After M6 authorization | PRE-09, PRE-10 |

## Universal history, undo and recovery

| Requirement | Class | Sequence | Major prerequisites |
|---|---|---|---|
| [HIST-01](../features/history-and-recovery.md) | F | M1+ as applicable | PRE-01, PRE-02 |
| [HIST-02](../features/history-and-recovery.md) | F | M1+ as applicable | PRE-01, PRE-02 |
| [HIST-03](../features/history-and-recovery.md) | F | M1+ as applicable | PRE-01, PRE-02 |
| [HIST-04](../features/history-and-recovery.md) | P1 | M5–M8 | PRE-02 |
| [HIST-05](../features/history-and-recovery.md) | P1 | M5–M8 | PRE-02 |
| [HIST-06](../features/history-and-recovery.md) | P1 | M5–M8 | PRE-02 |
| [HIST-07](../features/history-and-recovery.md) | F | M1+ as applicable | PRE-01, PRE-02 |
| [HIST-08](../features/history-and-recovery.md) | X | Future | PRE-02, PRE-05, PRE-12 |
| [HIST-09](../features/history-and-recovery.md) | F | M1+ as applicable | PRE-01, PRE-02 |

## Home, context restoration and work sessions

| Requirement | Class | Sequence | Major prerequisites |
|---|---|---|---|
| [CTX-01](../features/home-and-work-sessions.md) | V1 | M2–M5 per supported view | PRE-06 |
| [CTX-02](../features/home-and-work-sessions.md) | P1 | M5+ | PRE-06 |
| [CTX-03](../features/home-and-work-sessions.md) | V1 | M2–M5 per supported view | PRE-06 |
| [CTX-04](../features/home-and-work-sessions.md) | P1 | M5+ | PRE-06 |
| [CTX-05](../features/home-and-work-sessions.md) | P1 | M5+ | PRE-06 |
| [CTX-06](../features/home-and-work-sessions.md) | P1 | M5 recorded; M8 AI | PRE-06, PRE-11 |
| [CTX-07](../features/home-and-work-sessions.md) | P1 | M5+ | PRE-06 |
| [CTX-08](../features/home-and-work-sessions.md) | P1 | M5+ | PRE-06 |
| [CTX-09](../features/home-and-work-sessions.md) | V1 | M2–M5 per supported view | PRE-06 |
| [CTX-10](../features/home-and-work-sessions.md) | V1 | M2–M5 per supported view | PRE-06 |
| [CTX-11](../features/home-and-work-sessions.md) | P1 | M5 recorded; M8 AI | PRE-06, PRE-11 |
| [CTX-12](../features/home-and-work-sessions.md) | P1 | M5+ | PRE-06 |

## Import, export and portability

| Requirement | Class | Sequence | Major prerequisites |
|---|---|---|---|
| [PORT-01](../features/import-export-and-portability.md) | V1 | M2 | PRE-01, PRE-08 |
| [PORT-02](../features/import-export-and-portability.md) | V1 | M2 | PRE-01, PRE-08 |
| [PORT-03](../features/import-export-and-portability.md) | P1 | After local core | PRE-03, PRE-04, PRE-08 |
| [PORT-04](../features/import-export-and-portability.md) | F | M1+ as applicable | PRE-01, PRE-08 |
| [PORT-05](../features/import-export-and-portability.md) | P1 | After local core | PRE-03, PRE-04, PRE-08 |
| [PORT-06](../features/import-export-and-portability.md) | F | M1+ as applicable | PRE-01, PRE-08 |
| [PORT-07](../features/import-export-and-portability.md) | F | M1+ as applicable | PRE-01, PRE-08 |
| [PORT-08](../features/import-export-and-portability.md) | F | M1+ as applicable | PRE-01, PRE-08 |
| [PORT-09](../features/import-export-and-portability.md) | F | M1+ as applicable | PRE-01, PRE-08 |
| [PORT-10](../features/import-export-and-portability.md) | P1 | After local core | PRE-03, PRE-04, PRE-08 |
| [PORT-11](../features/import-export-and-portability.md) | P1 | After local core | PRE-03, PRE-04, PRE-08 |

## Markdown and document editing

| Requirement | Class | Sequence | Major prerequisites |
|---|---|---|---|
| [EDT-01](../features/markdown-and-editing.md) | V1 | M2 | PRE-03 |
| [EDT-02](../features/markdown-and-editing.md) | V1 | M2 | PRE-03 |
| [EDT-03](../features/markdown-and-editing.md) | V1 | M2 | PRE-03 |
| [EDT-04](../features/markdown-and-editing.md) | V1 | M2 | PRE-03 |
| [EDT-05](../features/markdown-and-editing.md) | V1 | M2 | PRE-03 |
| [EDT-06](../features/markdown-and-editing.md) | V1 | M2 | PRE-03 |
| [EDT-07](../features/markdown-and-editing.md) | V1 | M2 | PRE-03 |
| [EDT-08](../features/markdown-and-editing.md) | V1 | M2 | PRE-03 |
| [EDT-09](../features/markdown-and-editing.md) | V1 | M2 | PRE-03 |
| [EDT-10](../features/markdown-and-editing.md) | V1 | M2 | PRE-03 |
| [EDT-11](../features/markdown-and-editing.md) | V1 | M2 | PRE-03 |
| [EDT-12](../features/markdown-and-editing.md) | V1 | M2 | PRE-03 |
| [EDT-13](../features/markdown-and-editing.md) | V1 | M2 | PRE-03 |
| [EDT-14](../features/markdown-and-editing.md) | P1 | After local core | PRE-03, PRE-04, PRE-08 |
| [EDT-15](../features/markdown-and-editing.md) | V1 | M2 | PRE-03 |

## Motion system

| Requirement | Class | Sequence | Major prerequisites |
|---|---|---|---|
| [MOT-01](../design/motion.md) | F | With motion-capable UI | PRE-13 |
| [MOT-02](../design/motion.md) | P1 | M5+ | PRE-13 |
| [MOT-03](../design/motion.md) | P1 | M5+ | PRE-13 |
| [MOT-04](../design/motion.md) | P1 | M5+ | PRE-13 |
| [MOT-05](../design/motion.md) | P1 | M5+ | PRE-13 |
| [MOT-06](../design/motion.md) | X | Future | PRE-09, PRE-13 |

## Universal objects and organization

| Requirement | Class | Sequence | Major prerequisites |
|---|---|---|---|
| [ORG-01](../features/objects-and-organization.md) | F | M1 onward | PRE-01 |
| [ORG-02](../features/objects-and-organization.md) | V1 | M2–M5 | PRE-01, PRE-07 |
| [ORG-03](../features/objects-and-organization.md) | V1 | M2–M5 | PRE-01, PRE-07 |
| [ORG-04](../features/objects-and-organization.md) | P1 | M5+ | PRE-07 |
| [ORG-05](../features/objects-and-organization.md) | V1 | M2–M5 | PRE-01, PRE-07 |
| [ORG-06](../features/objects-and-organization.md) | V1 | M2–M5 | PRE-01, PRE-07 |
| [ORG-07](../features/objects-and-organization.md) | V1 | M2–M5 | PRE-01, PRE-07 |
| [ORG-08](../features/objects-and-organization.md) | V1 | M2–M5 | PRE-01, PRE-07 |
| [ORG-09](../features/objects-and-organization.md) | V1 | M2–M5 | PRE-01, PRE-07 |
| [ORG-10](../features/objects-and-organization.md) | V1 | M2–M5 | PRE-01, PRE-07 |
| [ORG-11](../features/objects-and-organization.md) | V1 | M2–M5 | PRE-01, PRE-07 |
| [ORG-12](../features/objects-and-organization.md) | P1 | M5+ | PRE-07 |

## Plugins, personal APIs, automations and executable notes

| Requirement | Class | Sequence | Major prerequisites |
|---|---|---|---|
| [EXT-01](../features/plugins-apis-and-automation.md) | P1 | M7 | PRE-12 |
| [EXT-02](../features/plugins-apis-and-automation.md) | P1 | M7 | PRE-12 |
| [EXT-03](../features/plugins-apis-and-automation.md) | P1 | M7 | PRE-12 |
| [EXT-04](../features/plugins-apis-and-automation.md) | P1 | M7 | PRE-12 |
| [EXT-05](../features/plugins-apis-and-automation.md) | P1 | M7 | PRE-12 |
| [EXT-06](../features/plugins-apis-and-automation.md) | P1 | M7 | PRE-12 |
| [EXT-07](../features/plugins-apis-and-automation.md) | P1 | M7 | PRE-12 |
| [EXT-08](../features/plugins-apis-and-automation.md) | P1 | M7 | PRE-12 |
| [EXT-09](../features/plugins-apis-and-automation.md) | X | Future | PRE-02, PRE-05, PRE-12 |
| [EXT-10](../features/plugins-apis-and-automation.md) | P1 | M7 | PRE-12 |
| [EXT-11](../features/plugins-apis-and-automation.md) | P1 | M7 | PRE-12 |

## Reverse engineering knowledge preset

| Requirement | Class | Sequence | Major prerequisites |
|---|---|---|---|
| [REV-01](../features/reverse-engineering.md) | X | Future | PRE-07, PRE-12 |
| [REV-02](../features/reverse-engineering.md) | X | Future | PRE-07, PRE-12 |
| [REV-03](../features/reverse-engineering.md) | X | Future | PRE-07, PRE-12 |
| [REV-04](../features/reverse-engineering.md) | X | Future | PRE-07, PRE-12 |
| [REV-05](../features/reverse-engineering.md) | X | Future | PRE-09, PRE-10, PRE-12 |

## Search, links, backlinks and context graph

| Requirement | Class | Sequence | Major prerequisites |
|---|---|---|---|
| [LNK-01](../features/search-links-and-graph.md) | V1 | M2–M5 | PRE-03, PRE-07 |
| [LNK-02](../features/search-links-and-graph.md) | V1 | M2–M5 | PRE-03, PRE-07 |
| [LNK-03](../features/search-links-and-graph.md) | V1 | M2–M5 | PRE-03, PRE-07 |
| [LNK-04](../features/search-links-and-graph.md) | V1 | M2–M5 | PRE-03, PRE-07 |
| [LNK-05](../features/search-links-and-graph.md) | V1 | M2–M5 | PRE-03, PRE-07 |
| [LNK-06](../features/search-links-and-graph.md) | V1 | M2–M5 | PRE-03, PRE-07 |
| [LNK-07](../features/search-links-and-graph.md) | V1 | M2–M5 | PRE-03, PRE-07 |
| [LNK-08](../features/search-links-and-graph.md) | F | M1 onward | PRE-01 |
| [LNK-09](../features/search-links-and-graph.md) | V1 | M2–M5 | PRE-03, PRE-07 |
| [LNK-10](../features/search-links-and-graph.md) | V1 | M2–M5 | PRE-03, PRE-07 |
| [LNK-11](../features/search-links-and-graph.md) | P1 | M5+; AI portions M8 | PRE-05, PRE-07, PRE-11 |
| [LNK-12](../features/search-links-and-graph.md) | V1 | M2–M5 | PRE-03, PRE-07 |
| [LNK-13](../features/search-links-and-graph.md) | P1 | M5+; AI portions M8 | PRE-05, PRE-07, PRE-11 |
| [LNK-14](../features/search-links-and-graph.md) | P1 | M5+; AI portions M8 | PRE-05, PRE-07, PRE-11 |

## Shell and navigation

| Requirement | Class | Sequence | Major prerequisites |
|---|---|---|---|
| [NAV-01](../features/shell-and-navigation.md) | F | M0 subset; ongoing | PRE-13 when branding |
| [NAV-02](../features/shell-and-navigation.md) | V1 | M2–M5 | PRE-06, PRE-13 |
| [NAV-03](../features/shell-and-navigation.md) | V1 | M2–M5 | PRE-06, PRE-13 |
| [NAV-04](../features/shell-and-navigation.md) | V1 | M2–M5 | PRE-06, PRE-13 |
| [NAV-05](../features/shell-and-navigation.md) | V1 | M2–M5 | PRE-06, PRE-13 |
| [NAV-06](../features/shell-and-navigation.md) | V1 | M2–M5 | PRE-06, PRE-13 |
| [NAV-07](../features/shell-and-navigation.md) | V1 | M2–M5 | PRE-06, PRE-13 |
| [NAV-08](../features/shell-and-navigation.md) | V1 | M2–M5 | PRE-06, PRE-13 |
| [NAV-09](../features/shell-and-navigation.md) | P1 | M5+ | PRE-06, PRE-13 |
| [NAV-10](../features/shell-and-navigation.md) | F | M0 subset; ongoing | PRE-13 when branding |
| [NAV-11](../features/shell-and-navigation.md) | V1 | M2–M5 | PRE-06, PRE-13 |

## Software development knowledge

| Requirement | Class | Sequence | Major prerequisites |
|---|---|---|---|
| [DEV-01](../features/software-development.md) | V1 | M2–M4 | PRE-03, PRE-05 as applicable |
| [DEV-02](../features/software-development.md) | P1 | M5–M7 | PRE-03, PRE-07 |
| [DEV-03](../features/software-development.md) | P1 | M5–M7 | PRE-03, PRE-07 |
| [DEV-04](../features/software-development.md) | P1 | M5–M7 | PRE-03, PRE-07 |
| [DEV-05](../features/software-development.md) | P1 | M5–M7 | PRE-03, PRE-07 |

## Spatial boards

| Requirement | Class | Sequence | Major prerequisites |
|---|---|---|---|
| [CAN-01](../features/spatial-boards.md) | V1 | M3–M5 | PRE-05 |
| [CAN-02](../features/spatial-boards.md) | V1 | M3–M5 | PRE-05 |
| [CAN-03](../features/spatial-boards.md) | V1 | M3–M5 | PRE-05 |
| [CAN-04](../features/spatial-boards.md) | V1 | M3–M5 | PRE-05 |
| [CAN-05](../features/spatial-boards.md) | V1 | M3–M5 | PRE-05 |
| [CAN-06](../features/spatial-boards.md) | V1 | M3–M5 | PRE-05 |
| [CAN-07](../features/spatial-boards.md) | V1 | M3–M5 | PRE-05 |
| [CAN-08](../features/spatial-boards.md) | V1 | M3–M5 | PRE-05 |
| [CAN-09](../features/spatial-boards.md) | P1 | M5+; AI portions M8 | PRE-05, PRE-07, PRE-11 |
| [CAN-10](../features/spatial-boards.md) | P1 | M5+; AI portions M8 | PRE-05, PRE-07, PRE-11 |
| [CAN-11](../features/spatial-boards.md) | V1 | M3–M5 | PRE-05 |
| [CAN-12](../features/spatial-boards.md) | X | Future | PRE-02, PRE-05, PRE-12 |
| [CAN-13](../features/spatial-boards.md) | X | Future | PRE-02, PRE-05, PRE-12 |
| [CAN-14](../features/spatial-boards.md) | V1 | M3–M5 | PRE-05 |
| [CAN-15](../features/spatial-boards.md) | V1 | M3–M5 | PRE-05 |
| [CAN-16](../features/spatial-boards.md) | V1 | M3–M5 | PRE-05 |
| [CAN-17](../features/spatial-boards.md) | V1 | M3–M5 | PRE-05 |

## Study and university workflows

| Requirement | Class | Sequence | Major prerequisites |
|---|---|---|---|
| [STUDY-01](../features/study-and-university.md) | P1 | M5+ | PRE-06, PRE-07 |
| [STUDY-02](../features/study-and-university.md) | V1 | M2–M4 | PRE-03, PRE-05 as applicable |
| [STUDY-03](../features/study-and-university.md) | P1 | M5+ | PRE-06, PRE-07 |
| [STUDY-04](../features/study-and-university.md) | P1 | M5+ | PRE-06, PRE-07 |
| [STUDY-05](../features/study-and-university.md) | P1 | M5+ | PRE-06, PRE-07 |

## Optional sync and future collaboration

| Requirement | Class | Sequence | Major prerequisites |
|---|---|---|---|
| [SYNC-01](../features/sync-and-collaboration.md) | F | M1 onward | PRE-01 |
| [SYNC-02](../features/sync-and-collaboration.md) | P1 | M6+ | PRE-09 |
| [SYNC-03](../features/sync-and-collaboration.md) | P1 | M6+ | PRE-09 |
| [SYNC-04](../features/sync-and-collaboration.md) | P1 | M6+ | PRE-09 |
| [SYNC-05](../features/sync-and-collaboration.md) | P1 | M6+ | PRE-09 |
| [SYNC-06](../features/sync-and-collaboration.md) | P1 | M6+ | PRE-09 |
| [SYNC-07](../features/sync-and-collaboration.md) | P1 | M6+ | PRE-09 |
| [SYNC-08](../features/sync-and-collaboration.md) | P1 | M6+ | PRE-09 |
| [SYNC-09](../features/sync-and-collaboration.md) | P1 | After M6 authorization | PRE-09, PRE-10 |
| [SYNC-10](../features/sync-and-collaboration.md) | X | Future | PRE-09, PRE-10, PRE-12 |
| [SYNC-11](../features/sync-and-collaboration.md) | P1 | M6+ | PRE-09 |
| [SYNC-12](../features/sync-and-collaboration.md) | P1 | M6+ | PRE-09 |
| [SYNC-13](../features/sync-and-collaboration.md) | P1 | M6+ | PRE-09 |
| [SYNC-14](../features/sync-and-collaboration.md) | P1 | After M6 authorization | PRE-09, PRE-10 |
| [SYNC-15](../features/sync-and-collaboration.md) | P1 | After M6 authorization | PRE-09, PRE-10 |
| [SYNC-16](../features/sync-and-collaboration.md) | X | Future | PRE-09, PRE-10, PRE-12 |

## Tasks, calendar and planning

| Requirement | Class | Sequence | Major prerequisites |
|---|---|---|---|
| [TASK-01](../features/tasks-calendar-and-planning.md) | V1 | M2–M5 | PRE-03, PRE-07 |
| [TASK-02](../features/tasks-calendar-and-planning.md) | V1 | M2–M5 | PRE-03, PRE-07 |
| [TASK-03](../features/tasks-calendar-and-planning.md) | V1 | M2–M5 | PRE-03, PRE-07 |
| [TASK-04](../features/tasks-calendar-and-planning.md) | V1 | M2–M5 | PRE-03, PRE-07 |
| [TASK-05](../features/tasks-calendar-and-planning.md) | V1 | M2–M5 | PRE-03, PRE-07 |
| [TASK-06](../features/tasks-calendar-and-planning.md) | V1 | M2–M5 | PRE-03, PRE-07 |
| [TASK-07](../features/tasks-calendar-and-planning.md) | P1 | M5+ | PRE-07 |
| [TASK-08](../features/tasks-calendar-and-planning.md) | P1 | M5+ | PRE-07 |
| [TASK-09](../features/tasks-calendar-and-planning.md) | P1 | M5+ | PRE-07 |
| [TASK-10](../features/tasks-calendar-and-planning.md) | P1 | After M6 authorization | PRE-09, PRE-10 |
| [TASK-11](../features/tasks-calendar-and-planning.md) | V1 | M2–M5 | PRE-03, PRE-07 |
| [TASK-12](../features/tasks-calendar-and-planning.md) | P1 | M5+ | PRE-07 |
