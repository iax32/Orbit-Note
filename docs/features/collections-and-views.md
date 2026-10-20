# Collections and structured views

Status: delivered subsets below; broader planned behavior remains. Stage: M2/M5.
Sources: S03, S04, S07, S08 in the [source map](../product/conversation-extraction.md).
Architecture: [universal model](../architecture/universal-object-model.md).

## Purpose and workflow

A University collection includes notes, courses, people, PDFs and deadlines. Users
switch how they see it or save purpose-specific views. An Active Projects query
can appear as a table, Kanban board, calendar or embedded view without creating
independent records in each presentation.

## Delivered task Gantt — 2026-10-10

Folder menu > New Gantt Timeline and the command palette create a saved orbit.view.
Smart Views offer Gantt presentation using the same filters; orbit-view note embeds
render the live definition. Canonical tasks stay shared with other views. Folder and
project scope are combined when both are configured. The chart has 14/28/56-day
windows, previous/next/today/first-scheduled navigation and 50-row pages. Text and
open-only filters, viewport and page are private to each presentation; day-window
size persists. Horizontal scrolling keeps long ranges available on narrow panes.

Work bars use scheduledDate and optional inclusive scheduledEndDate, never dueDate
as an invented start. Without a finish, a scheduled task is one day. Undated or
malformed ranges remain listed with editable dates/warnings. Explicit ganttMilestone
marks single-day milestones; legacy named milestone stages are not reinterpreted.
Deadlines remain independent markers. Dependencies connect visible rows and appear
by name in scheduling details, including sources outside the view/window/page.
Missing/undated blockers, overlapping unfinished blockers and deadline overruns are
visible. Completed blockers do not constrain suggested dates.

Drag previews a date move in a confirmation form; the same form supports keyboard
date entry, resize and clearing dates. After-blockers suggests the day after the
latest unfinished dependency finish only when those sources have valid work ranges.
Saving moves one task, preserves its deadline/occurrence history and provides
guarded session undo. It does not move downstream tasks or assert critical paths.
Read-only sources remain readable, unsupported Gantt versions remain preserved.

Calendars opens reusable working weeks with Mon–Fri, Sun–Thu and every-day presets,
individual weekdays, named holidays and extra working-date exceptions. View defaults
apply when reviewing schedules; already bound tasks retain their chosen calendar.
Calendar-aware effort, forward finish calculation, backward deadline planning and
after-blocker snapping are available in the schedule form. Changing a calendar
does not move tasks. Schedule audit lists unscheduled work, dependency warnings,
non-working endpoints and mismatching effort in 25-item pages with per-task review.
The view calendar shades non-working dates; mixed-calendar tasks retain their own
semantics. Enlarged text increases row height and connector positions together.

## Delivered research workspace — 2026-10-10

Folder menu > New Research Workspace or the command palette creates an ordinary
saved view. New creative projects include one linked from their brief. Add existing
objects from any project or reuse a Canvas board's references; membership remains
explicit rather than automatically including later board captures. Sources keep
their original UUID and content. Rename/duplicate through the explorer; duplicate
definitions retain source links, not copies of source objects.

Gallery shows available local images with retry and bounded decode width, or text
previews. Table is paginated in groups of 50. Compare displays up to four selected
sources (stacked on narrow panes). Tags, source type, review state, project and
Enter-submitted text filters persist on the definition. Selection and table page
are private to each presentation. Read-only definitions allow transient layout
switching. Unsupported research versions/layouts show a preserved-data state.

Imported board references follow current placement captions/tags/state/URL while
the placement exists. Edit collection details creates an independent commentary
override; Use board details restores live placement commentary. Removed boards or
placements show captured details with an explicit unavailable indicator. Removing
membership never removes original files or source objects. Reference source/project
changes are visible in all embeds. Copy live embed uses the existing orbit-view
fence with view: UUID; Canvas cards link to the same full saved view.

An optional existing brief appears beside evidence in wide panes and in a dialog
on narrow panes. Decisions mode opens linked records in the same project (or exact
collection folder when no project is recorded). It is not filtered by the reference
search controls. This is a manual local research workflow, not citation scraping,
semantic comparison, an automatic board-membership query or remote monitoring.

## Collection quality refinement — 2026-10-18

Legacy tables, timeline membership and saved-view task progress resolve the same
canonical collection query. Explicit manual collections without member IDs are
empty; duplicate/missing IDs do not duplicate objects. Membership lookup builds
one ID set per evaluation. Optional presentation scopes have separate cached
results, invalidated after object changes. Existing folder-before-scope semantics
remain unchanged. Unsupported membership/scope formats show a preserved-data
state instead of falling back to unrelated Vault content.

Table sorting saves both direction and column together; supported property edits
merge current data, retaining unknown settings and concurrent unrelated changes.
Text forms keep drafts on validation failure or competing renames. Dialogs and
popup choices retain their originating collection/workspace; an old popup cannot
apply to a different collection after switching. Delayed creation attaches to the
original manual collection, preserving newer members. If that definition becomes
unavailable, the created source remains recoverable and a notice explains why it
was not attached.

Folder cells use the existing validated file-move command and require an existing
destination, rather than only changing a display property. Read-only sources and
definitions disable editing. Empty status values and unknown column settings
remain readable without rewriting imported data. Tables retain lazy vertical rows
and horizontal navigation at narrow widths/enlarged text; long paths and tags are
bounded. These refinements do not add schema, full property editing or query-based
creation defaults. [Checks and limits](../tasks/collection-quality-2026-10-18.md).

## Kanban quality refinement — 2026-10-19

Legacy collection boards now share canonical query membership with tables and
progress. Manual membership takes precedence over derived course membership;
unsupported grouping/preset/query definitions retain their data and show a useful
state. Actual project/folder names such as `none` and `root` are distinct from the
unassigned columns; only private presentation keys change.

Drops recheck the originating board/workspace, current membership and source
availability/read-only state. Completion merges current properties, and unchanged
drops avoid redundant saves. Folder drops use durable validated file moves instead
of changing only metadata. Object type remains immutable through dragging.

Inline creation rejects repeated submissions, keeps titles on save failure and
retains original collection ownership through delayed completion. Concurrent
members and unknown entries survive. External regrouping retains an unfinished
title and requires choosing a new column. Read-only definitions disable mutation.
Columns as well as cards are lazy; narrow/enlarged-text layouts bound the toolbar
and preview to the actual pane. Escape closes the focused preview. These changes
do not introduce new storage or automatic query-based creation defaults.
[Actual checks and limitations](../tasks/kanban-quality-2026-10-19.md).

## Creation edge cases — 2026-10-19

Type-grouped boards offer inline creation only for Note, Task and Canvas. The
heterogeneous Other bucket directs users to New/Import instead of silently
creating a task in another column. Tasks-only type boards disable creation of
hidden note/Canvas types until that filter is removed. Retained Add, keyboard
submit and Cancel callbacks check their original board/workspace before touching
the shared draft, including after switching or disposing the presentation.
[Checks and limits](../tasks/file-workflow-quality-2026-10-19.md).

## Requirements

Implemented readability refinement, 2026-10-03: generic collection boards explicitly
show All objects, with optional Tasks only and Hide empty columns controls stored
on the view. New Game Project boards default to Tasks only; existing views keep
their membership unless the user changes the filter. Both board presentations
map known status aliases onto available preset columns (for example todo to
Planned in Game Dev). This is a presentation mapping, not a content migration;
unknown statuses and object IDs are preserved. Collection boards retain No Status
for unsupported values. Dragging still edits the canonical object's status.

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

Implemented 2026-10-08: version-1 deterministic Smart Views with shared predicates,
sort/group/custom table columns and a visual builder; lazy table/board/list/gallery
presentations plus existing calendar/timeline projections. Scalar cells edit the
canonical object with type/date/read-only checks; board moves update its grouping
property and task completion/recurrence consistently. Saved definitions can be
renamed/duplicated and reused by note embeds, Home widgets and Canvas previews.
Query edits leave bodies untouched; unsupported definitions retain a visible
recovery state. Canvas previews open the full view for interaction. Gallery uses
available text, not fabricated image content. Date presentations apply their own
chronological ordering. Full polymorphic property editing, creation forms that
prefill query membership, nested predicate trees, formulas/map/AI queries
remain separate. See [formats](../architecture/implemented-formats.md) and
[current evidence](../tasks/current.md); this is a working subset of the full IDs.

Begin with a useful filtered list/table; add one view at a time using the same
query contract. Smart natural-language queries wait for AI, while deterministic
saved queries do not. Map/formula engines are not prerequisites for M5's first view.
