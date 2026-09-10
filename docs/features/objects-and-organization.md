# Universal objects and organization

Status: planned. Stage: M1–M5.
Sources: S01, S03, S04 in the [source map](../product/conversation-extraction.md).
Architecture: [universal model](../architecture/universal-object-model.md).

## Purpose and workflow

A project is created once, classified with properties, added to University and
Programming collections, referenced from a note and placed on two boards. Those
are different organizational choices around one identity. Users can combine them
or keep a simple folder-and-note workflow.

## Requirements

| ID | Observable behavior |
|---|---|
| ORG-01 | Objects keep stable identity across title changes, file moves, view changes and collection membership changes. |
| ORG-02 | Built-in types grow from notes to tasks, projects, people, concepts, bookmarks, files, events, canvases/drawings and later decisions/assumptions/sessions. |
| ORG-03 | Typed properties support text, number, checkbox, select/list, date/time, URL and object references as needed; invalid values have understandable errors. |
| ORG-04 | Custom type definitions let users model things such as Books with author, rating, genre and finished status; removing a type definition preserves existing data. |
| ORG-05 | Folders and optional notebook → section → page organization coexist with tags, relations, collections and boards; no single hierarchy is mandatory. |
| ORG-06 | Objects can belong to several collections; smart collections query the same workspace objects and do not move/copy source files just to include them. |
| ORG-07 | Rename, move, archive, trash, restore and duplicate are explicit, distinct actions with undo/recovery appropriate to their scope. |
| ORG-08 | A concept/person/project inspector can reveal related notes, tasks, files, decisions and sources without manufacturing separate identities for each presentation. |
| ORG-09 | Users can promote local content into a reusable object explicitly, retaining provenance; not every pen stroke or decorative shape becomes a global object automatically. |
| ORG-10 | Hierarchical tags support rename/merge/reparent with reference-safe updates and cycle/conflict handling; aliases are distinct from tag hierarchy. |
| ORG-11 | Relation autocomplete and contextual related-object suggestions explain intended edge types/targets and require deliberate acceptance for inferred links. |
| ORG-12 | Resources, linkable highlights, bugs and snippets extend the universal model as needed; API/function or domain-specific types are optional schemas, not separate object stores. |

## Data and integration

Built-in and custom type schemas declare capabilities; a file can be attached and
annotated without pretending it is a Markdown note. Custom type changes need explicit
migration/conversion behavior. The phrase “multiple identities” in the brainstorming
chat means multiple roles/contexts around one concept, not conflicting primary IDs.
Aliases improve discovery without requiring duplicate concept objects.

Manual collection membership, semantic relation, physical folder location and
board placement are different relationships. User-facing commands should name the
specific change: “Remove from collection” rather than ambiguous “Delete.” Notebook
hierarchy is acyclic; overlapping collections are allowed. Workspace isolation
remains an ownership boundary; Spaces are contexts within it.

## States and edge cases

Duplicate titles are legal if identity is distinct; selection dialogs must show
enough context to disambiguate. Missing targets remain unresolved references.
Duplicate/import commands need a consistent ID remapping policy, including attached
files and relations. Circular folder/notebook moves are rejected. Removing a schema
field must not silently destroy existing values. Archive/trash presentation and
retention policy must be agreed before their task ships.

## Acceptance scenarios

- ORG-01/06: rename and move a note in two collections and two boards; every reference
  still resolves to the same object while placements keep independent geometry.
- ORG-04: open a workspace missing a custom type definition; inspect/export its
  preserved values through a fallback rather than losing the object.
- ORG-07: remove one collection membership, then explicitly trash/restore the object;
  the two actions have different and predictable effects.

## Delivery

Start with the minimum note/workspace identity needed for M1. Add organizational
features as usable slices; do not instantiate all object types or build a generic
schema designer before a task needs one.
