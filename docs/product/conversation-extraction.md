# Product discussion extraction and provenance

This is a traceability map, not an alternative backlog. The original **Build Note
Taking App** conversation (14 turns, ID `6a9ab318-7770-83eb-86be-9182fb3ab4bc`)
was read during the documentation expansion. The owner's explicit 2026-09-08
pasted brief adds/clarifies requirements. Specs contain proposed interaction
details where the discussion gave only an idea; those are not historical quotes.

## Source registry

| Source | Discussion topic | Repository destination |
|---|---|---|
| S01 | Combined Obsidian/OneNote/Milanote/Notion app | Product definition; editor, organization, Canvas, views |
| S02 | Flutter, local data and future sync | Architecture overview; ADRs 0001–0003; sync |
| S03 | Knowledge OS, universal objects, multiple views | Object model; collections; context; AI |
| S04 | Distinctive knowledge/context ideas | Provenance, history, sessions, health, smart views, automation |
| S05 | Small-context agent instructions | AGENTS, task template, agent workflow, docs map |
| S06 | Extreme but safe workspace customization | Layout architecture; customization; navigation |
| S07 | Markdown/open ownership and portability | Storage formats; import/export; ADR-0004 |
| S08 | Reused spatial/ink engine | Canvas/ink specs; canvas architecture; ADR-0006 |
| S09 | Large Canvas performance | Canvas architecture; quality requirements |
| S10 | Owner's detailed product brief, 2026-09-08 | Expanded specs, specialist workflows, compatibility, design/motion, canonical backlog |

Naming discussion selects **Orbit Note**. Comparisons of coding models/IDEs are
development context, not application feature requirements. Suggested plugin
examples remain optional ecosystem ideas, not promises to ship integrations.

## S10 coverage map

| Brief area | Canonical requirement family / document |
|---|---|
| Goal, audience, ten principles | Product definition, principles, terminology |
| Notes and editor | EDT, LNK; Markdown and editing |
| Desktop fundamentals | DES, NAV, HIST, CTX; desktop interactions |
| One Universal Canvas and scale | CAN, INK; spatial boards, canvas architecture, quality requirements |
| Knowledge system and object types | ORG, PROV; objects and organization |
| Contextual graphs | LNK, CAN; search/links/graph |
| Tasks and planning | TASK, VIEW |
| Calendars and external calendar scopes | EVT |
| Resume Context and session memory | CTX |
| PDF and research | FILE, INK, PROV |
| Study/university | STUDY |
| Software development | DEV |
| Reverse engineering | REV |
| Game development/team projects | GAME |
| Collaboration | SYNC, TASK, EVT |
| Search/discovery | LNK, AI |
| Smart Views/databases | VIEW |
| Knowledge Health | AI-09, AI-15; deterministic checks do not require a model |
| Capture | CAP, DES |
| Integration/migration | PORT, EXT, EVT, DEV, FILE |
| Sync/providers | SYNC; local-first/sync architecture |
| Ownership/compatibility | COMP, PORT, HIST; compatibility and migrations |
| UI/UX | NAV, LAY; visual design |
| Animations/motion | MOT; motion system |
| AI/providers and independent permissions | AI |
| Plugins/extensibility/API/MCP | EXT |
| Four release classes and dependencies | Single feature backlog; prerequisites |

## Earlier differentiators retained

Context inspector, capture intent, decision/assumption trails, source provenance,
work sessions and continuation notes live in CTX/PROV/CAP. Knowledge compiler,
duplicate/concept/link suggestions, contradiction detection and resurfacing live
in AI. Smart Pages are saved query presentations (VIEW); living notes and
trigger-condition-action automation live in EXT. History, snapshots, time-machine
exploration and branches live in HIST. Portals, nested canvases, semantic zoom,
auto-layout and document-to-board conversion live in CAN. Custom dashboards,
themes, keybindings and community layouts live in LAY/EXT. Optional executable
notes, recognition and integrations remain future ideas with boundaries.

## Tensions resolved without changing accepted ADRs

1. Earlier database-only examples conflict with later open ownership: accepted
   Markdown/JSON owning files remain durable authority; SQLite indexes/operational
   data are not the sole copy of knowledge.
2. Separate OneNote/Milanote-like modes mean presets of one Canvas, not incompatible
   engines or formats. A canvas can mix all supported element capabilities.
3. Multiple presentations/semantic roles do not create multiple object identities.
   Inline checkboxes and real Task objects need explicit promotion/anchor rules.
4. An object can supply context for another without granting access. Local Spaces
   organize work; shared Spaces need a future authorization contract.
5. The new graphite/violet direction is future product branding. M0-01's explicit
   system light/dark theme remains unchanged.
6. Essential tabs/splits and manual continuation should arrive with useful local
   work, before advanced docking and AI summaries. Roadmap sequencing is clarified;
   current M0 scope is unchanged.
7. Safe deterministic cleanup requires defined authorized reversible rules.
   Semantic AI organization still requires a reviewed diff and stale-state checks.
8. Resume restores view state around current content; history restore is separate.
   Universal PDF Highlight objects do not require one object per ink sample.
9. Backward compatibility does not mean old clients may blindly rewrite unknown
   future formats. Preserve unknown fields or use read-only fallback.
10. Undo cannot retract data already transmitted to an external service. Document
    compensating actions and irreversible boundaries honestly.

There is no new stack/ownership decision requiring an ADR in this documentation
update. Runtime, sync protocol, anchor and migration questions remain explicit
prerequisites rather than invented completed architecture.

## Later implementation and refinement sources

S11: owner's attached implementation brief (`8a1de9a1`), adopted 2026-09-09:
finish the existing local core and favor usable features over placeholder screens.
Mapped to the existing Notes, Canvas, storage, attachments, shell and recovery
families; it does not create a second backlog.

S12: owner's attached continuation/refinement brief (`4ae03b8b`) and subsequent
explicit continuation request, adopted 2026-09-09: preserve work, fix builds,
quiet-observatory styling, rounded controls, split/side-by-side workflows and
regular validation. It supersedes the earlier M0-only implementation restriction
and deferred-dark-branding statement above. Product goals and stable requirement
IDs remain unchanged. Actual delivery is tracked in implementation status.

S13: owner's Final Consolidated Astra Medium Implementation Prompt, explicitly
adopted 2026-09-09. It prioritizes audit/data safety, bounded recovery, native change
events, indexed search and Canvas deltas; then Vault lifecycle, real folders, Notes
comfort, Calendar and shared Canvas organization. Vault aliases Workspace. Autosave
must preserve authored source exactly, superseding the prior conversion behavior.
Existing feature IDs/backlog entries remain; no duplicate requirements are added.
The requested Windows release gate and unfinished phases are recorded in CURRENT status.

S14: owner's attached Rich Markdown continuation (`ecd2ce3a`) and explicit
2026-09-10 stabilization request. Continue the existing lossless projection and
shared undo, fixing formatted boundaries, paragraphs, smart lists, visual tables,
code copy and LaTeX before unrelated work. Mapped to existing EDT-01–15; no new
requirement IDs. This overrides the prior proposed Notes-list-only task.
