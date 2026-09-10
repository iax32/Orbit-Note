# Collections and structured views

Status: planned. Stage: basic collection organization M2; structured views M5.
Sources: S03, S04, S07, S08 in the [source map](../product/conversation-extraction.md).
Architecture: [universal model](../architecture/universal-object-model.md).

## Purpose and workflow

A University collection includes notes, courses, people, PDFs and deadlines. Users
switch how they see it or save purpose-specific views. An Active Projects query
can appear as a table, Kanban board, calendar or embedded view without creating
independent records in each presentation.

## Requirements

| ID | Observable behavior |
|---|---|
| VIEW-01 | A manual collection stores explicit membership/order; a smart collection stores a query. The user can tell which kind they are editing. |
| VIEW-02 | Saved view definitions retain scope, filter, sort, group and display configuration independently from object content and open-pane state. |
| VIEW-03 | List/table views show chosen properties and can edit supported fields through the object commands, validating types and read-only values. |
| VIEW-04 | Kanban groups by a chosen property; moving a card changes that property's value, with visible handling of missing values and unsupported transitions. |
| VIEW-05 | Calendar/timeline views use configured date fields; gallery chooses an available preview; switching views does not fabricate missing dates or image content. |
| VIEW-06 | Multiple views of one collection remain consistent after object edits; changing a view's sort/order never rewrites note bodies. |
| VIEW-07 | Live saved views can be embedded in documents, dashboards and canvases while referencing the same definition and underlying objects. |
| VIEW-08 | Smart Pages expose useful dynamic queries such as inactive active-projects; natural-language creation later previews an explicit editable query before saving. |
| VIEW-09 | Map views, formulas, calculations and richer aggregations are exploratory extensions; their prerequisites and unavailable data are shown honestly. |
| VIEW-10 | A visual query builder exposes scope, predicates, sort/group and supported relations; users can save the result as a Smart View and edit it without AI. |
| VIEW-11 | Later Gantt views use explicit task dependencies/date semantics and can be saved like other views; they are not required for a basic calendar or timeline. |

## Naming

**Smart View** is the user-facing name for a reusable query/view definition. It
does not introduce another database model. Existing “saved view,” “database view”
and “Smart Page” descriptions refer to configurations/presentations of this same
mechanism. Available kinds grow to list, table, gallery, Kanban, calendar, timeline,
graph and later Gantt/map. Smart View embeds in notes and Canvas are VIEW-07.

## Interaction details and data

“Add row” in an editable structured collection creates an object of a known type,
then establishes membership as appropriate. Adding to a smart query requires
explaining which properties make the object match; the UI cannot promise a new
row will remain visible if it fails the filter. Proposed default: offer a small
creation form prefilled only with unambiguous equality constraints.

An object disappearing because the user changed its status is a filter update,
not deletion. Retain a brief path back/undo so the result is understandable.
Duplicating a view duplicates configuration, not its objects. Per-embed transient
scroll/selection can differ; editing a shared saved definition should say it affects
other users of that definition.

## States and edge cases

Distinguish empty collection, no filter matches, unsupported view, missing field,
and failed query. A collection may contain heterogeneous types; missing fields
render as absent and do not silently coerce values. Read-only imports and derived
formula fields cannot be edited as ordinary values. Removed plugins/types preserve
query definitions for recovery. User queries are structured/validated, not arbitrary
SQL injected into the local database.

## Acceptance scenarios

- VIEW-03/04/06: edit status in a table, see the same object move Kanban group,
  and verify no duplicate record or rewritten Markdown body was introduced.
- VIEW-02/07: open two embeds with independent scroll positions; update the saved
  query and observe consistent results without changing object identity.
- VIEW-05: create an undated object and verify the calendar handles it explicitly
  rather than assigning today's date behind the scenes.

## Delivery

Begin with a useful filtered list/table; add one view at a time using the same
query contract. Smart natural-language queries wait for AI, while deterministic
saved queries do not. Map/formula engines are not prerequisites for M5's first view.
