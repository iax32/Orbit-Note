# Universal object and data model

Status: accepted identity/reference model ([ADR-0005](../adr/0005-universal-objects.md));
the shapes below are a draft for incremental implementation. No schema/classes yet.
Do not create all tables in M0.

## Core identities

Use offline-generated UUIDs for workspace, object, relation, canvas element, and
command IDs. Paths and titles can change without changing identity. Store UTC
timestamps; dates such as a deadline may instead be explicit date-only values.

| Record | Fields / role |
|---|---|
| Workspace | `id`, `name`, `formatVersion`, `createdAt`; independent of login |
| UniversalObject | `id`, `workspaceId`, `typeId`, `schemaVersion`, `title`, `createdAt`, `updatedAt`, local `revision`, nullable `deletedAt`, typed `properties`, `contentRef` |
| ObjectTypeDefinition | Namespaced `typeId`, schema version, property definitions, supported content/view capabilities; built-ins can use `orbit.note`, `orbit.task`, etc. |
| Relation | `id`, workspace, `sourceId`, `targetId`, `typeId`, properties, revision/tombstone; directed unless its schema declares otherwise |
| Collection | An object plus ordered memberships **or** a query definition; mixed mode requires explicit future design |
| ViewDefinition | `id`, workspace, `kind`, scope/query, filter/sort/group/columns, version; references object/collection IDs |
| CanvasElement | `id`, `canvasId`, element `kind`, optional `objectId`, world transform/bounds, z-order, layer, display options |
| Connector | Element ID, endpoint element IDs or free anchors; optional `relationId`, style, control points |
| Drawing | A universal object with stroke collection content; strokes have local IDs, bounds, samples, style and revision |
| Attachment | File object with relative `contentRef`, MIME type, original name, byte length and checksum; original bytes stored separately |

Use immutable values and explicit serialization. A typed value supports text,
number, boolean, date, timestamp, enum, list, and object reference as needed.
Validate properties against the type schema. Preserve unknown namespaced properties
on round-trip. Do not equate a JSON blob column with an unvalidated domain model.

`revision` detects stale local edits only; two devices can both reach revision 8.
Future replication adds operation IDs and explicit ancestry/version tokens.
User content schema versions are separate from SQL schema and workspace versions.

## One content owner

A text-backed project can live in Markdown with frontmatter. A structured-only
object lives in an `.object.json` record. A canvas/drawing object uses the common
envelope in its specialized JSON file. Each object has **one owning file**, not a
generic object file and specialized file with competing titles/properties.

A board card stores `objectId`, placement size/position, and preview settings.
Changing its geometry cannot edit the note body. Two placements of one project
can have different sizes. Deleting a placement leaves the project and other views
intact. Explicitly deleting the object creates a tombstone and visible unresolved
references; it does not silently cascade through all user content.

View queries return object IDs; renderers resolve current data. Repeating an object
in several views is expected. Copy/duplicate is a separate explicit command with
a new ID and documented attachment/reference semantics.

## Relationships, hierarchy, and embedded content

- Notebook/section parent memberships must be acyclic. Collections may overlap.
  A physical file path is storage location, not the sole organizational parent.
- Wiki links are derived from Markdown; resolve by stable identity when known,
  and retain original text/target for unresolved or ambiguous names. Renames must
  not silently bind a link to a different object.
- User-authored typed relations are durable records. Backlinks/search edges are
  derived indexes; removing an indexed edge cannot rewrite source text implicitly.
- Connectors can be decorative. Creating a semantic connector explicitly creates
  or references a relation; moving the connector does not change that relation.
- A Markdown checkbox is initially a derived task occurrence anchored in its owner.
  Do not create a second independently editable task body. Stable occurrence IDs
  and round-trip anchors need design/tests before global task editing. Standalone
  task objects are separate, intentional content.
- Individual ink strokes, block fragments, and every decorative shape need not
  become global universal objects. Promotion is an explicit operation retaining
  provenance and references. Rich-block/anchor syntax remains deferred.

## Candidate local tables, when needed

`objects`, `type_definitions`, `properties` or validated property JSON,
`relations`, `collection_members`, `view_definitions`, `canvas_elements`,
`strokes`, `attachment_metadata`, derived backlinks/FTS tables, and operational
history/outbox tables. Select indexes from actual queries; avoid a universal
entity-attribute-value implementation before it is needed. Enable foreign-key
validation while representing unresolved external references explicitly.

Cross-workspace links require explicit external references and are deferred.
Import collisions must be reported/remapped consistently; never silently overwrite
an existing identity. [Storage formats](storage-formats.md) own serialization rules.
