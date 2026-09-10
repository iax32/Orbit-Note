# Terminology

| Term | Meaning |
|---|---|
| Workspace | Ownership/storage boundary with a stable ID, content, configuration, and optional sync. No account is required. |
| Vault | User-facing name for the existing Workspace and its ordinary local folder. It does not introduce another identity or storage model. |
| Notes folder | A real directory under `Notes/`; moving a note changes its owner path, never its Universal Object ID. Distinct from an object collection or Space. |
| Space | A saved context within one workspace: filters, focused collections, panes, and layout. It is not a separate content store or a permission boundary. |
| Universal object | A stable identity plus type, properties, content references, and relationships; the canonical domain term. Earlier chat examples used “Node.” |
| Object type | Built-in or namespaced custom schema describing capabilities and typed properties. Start with note; add types incrementally. |
| Note / document | A Markdown-backed object, shown in a linear document editor. Rich embeds remain references with readable fallbacks. |
| Page | A user-facing presentation term. A document page uses a note; a freeform page uses a canvas object with the freeform preset. |
| Notebook / section | Organizational objects whose ordered memberships form an optional hierarchy. They do not create another note format. |
| Collection | A manual membership list or a saved query over existing objects. An object may belong to several. |
| Database / record | UI terms for a collection in structured views / one underlying object, not another independent SQL database. |
| View definition | A saved query/scope and presentation configuration (list, table, Kanban, calendar, graph, etc.). No copied object bodies. |
| View instance | An open rendering of a view in a pane or canvas embed; selection and scroll are ephemeral. |
| Pane / tab | Shell containers hosting view instances. They do not own knowledge. |
| Canvas | Spatial content object with placements, shapes, connectors, and drawing references. |
| Board / freeform page | Presets of the same canvas: infinite spatial organization / writing and pen-focused page behavior. |
| Placement | A stable canvas element identity referring to an object, with per-placement transform and display settings. Several may refer to the same object. |
| Ink / stroke | Editable vector input samples and style; strokes live in a drawing, not individual global knowledge objects by default. |
| Relation | A typed semantic edge between object identities. |
| Connector | A visual edge between placements. It can optionally reference a relation; a decorative arrow alone has no semantic meaning. |
| Graph | A view of object relations/backlinks, not an alternate identity system. |
| Attachment | Original bytes plus a file object/metadata; content is referenced, not embedded as base64 in Markdown/SQL rows. |
| Command / change set | A validated mutation / grouped mutations with preconditions and reversible history. |
| Tombstone | A deletion record retained for recovery and eventual replication; distinct from removing a placement or collection membership. |
| Revision | A local optimistic-concurrency value. It is not a global order across devices. |
| Checkpoint | A durable materialization of committed changes into portable workspace files. |

Use these meanings in code and docs. Avoid creating a separate `Node` and
`UniversalObject` hierarchy for the same concept.

## Clarifications from the expanded brief

| Term | Meaning |
|---|---|
| Universal Canvas | One shared spatial scene/engine combining supported writing, ink, cards, media and views; presets change defaults, not format compatibility. |
| Smart View | Reusable query and presentation over Universal Objects; saved/database views and Smart Pages use this mechanism. |
| Resume Context | Restore personal view/navigation state around current content; distinct from restoring historical content. |
| Context anchor | Stable reference to an object or supported fragment/page/highlight, with a fallback when the target changes. |
| PDF Highlight | Linkable annotation object with source anchors; distinct from individual ink samples. |
| External reference | Pointer to externally owned content, distinct from an owned attachment and a Canvas portal. |
| Optional preset | Editable schema/template/layout configuration for study/development/team workflows; no separate knowledge store. |

## Optional Orbit names (S12; terminology, not new subsystems)

- **Orbit Focus**: the existing Focus/Zen presentation (NAV-07).
- **Resume Orbit**: the existing manual context/session continuation experience.
- **Trail**: navigation/history context, not a second object-history database.
- **Radius**: an optional label for graph scope/hop depth when Graph is implemented.
- **Knowledge Gravity**: a future explainable relevance/resurfacing idea within AI
  and knowledge health; no current scoring engine or autonomous organizer exists.

Use clear functional labels until these names improve comprehension. None expands
current implementation scope or duplicates an existing feature requirement.
