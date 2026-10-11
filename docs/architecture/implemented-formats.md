# Implemented open formats — v1 subset

## Markdown columns and live object blocks — 2026-10-11

Two or three ordinary Markdown bodies are separated by explicit layout comments:

```markdown
<!-- orbit:columns v=1 -->
Left Markdown
<!-- orbit:column -->
Right Markdown
<!-- /orbit:columns -->
```

The supported region is bounded to 200,000 UTF-16 units and 10,000 lines.
Unfinished fences, nested layouts, unsupported versions and malformed blocks stay
literal. Fence-contained divider/closing examples are content. Source bytes and
individual body endings are retained; explicit layout rewrites use the header's
line ending. Stacking drops layout markers while preserving all body Markdown.

Live object blocks retain a standard source link as their portable fallback:

```markdown
<!-- orbit:object v=1 -->
[Drawing](orbit-object:canonical-object-id)
<!-- /orbit:object -->
```

IDs accept 1–100 ASCII letters/digits/underscore/hyphen. Labels are single-line
without bracket injection. Version-1 links resolve only within the current Vault;
they do not own duplicated object content. Drawing data remains in the existing
canonical Canvas JSON. Removal changes the note only, and missing sources retain
the source link. Print/HTML/Word snapshots stack columns and keep object source
links with warnings. Unsupported forms remain editable Source text; ordinary
note saves/history/backup preserve them without a schema migration.

## Reusable citation libraries and BibTeX interchange — 2026-10-11

A source library is an ordinary `orbit.note` with `citationLibrary: 1` in its
existing portable properties and the source-record comments below in its body.
It retains one canonical object ID, ordinary Markdown/frontmatter authority,
save/history/backup/deletion behavior, and all unknown data. The citation manager
creates a library from current sources and can edit it as an ordinary note.

Reusing selected library records copies an explicit bibliographic snapshot into
the destination note, retaining existing extra fields and adding
`citationLibrary: {objectId: <library UUID>, title: <captured title>}` inside each
source record. This is metadata provenance, not a second library object or a live
embed. The library UUID opens its canonical note; missing/deleted libraries leave
the stored snapshot usable. Library edits never silently rewrite citing documents.

BibTeX import is reviewed before a single owning-note mutation. UTF-8 `.bib` files
and pasted text are bounded to 1 MiB/1,000 accepted sources/100 fields per entry,
16,000 characters per raw field and 64 brace levels. Source-field limits still
apply. Braced/quoted fields, escaped/nested braces, numeric values, literal `#`
concatenation, percent comments, BOM and brace/parenthesis entry delimiters are
supported. Unresolved macros skip their whole entry with warnings. `@string`,
`@preamble` and `@comment` are not evaluated or stored as sources; keep the original
file for these records. Invalid syntax refuses preview. Unsupported metadata
records in the destination note remain untouched.

Imported source extra data includes `bibtex: {key, type, fields, publisherField,
mapped}`. Raw field strings preserve unknown fields and authored TeX; mapped
display values flatten grouping braces/whitespace, preserving escaped literal
braces and showing TeX commands as text with a review warning. Title, author,
year, DOI, ISBN and URL map directly; publisher uses publisher/journal/booktitle
in that precedence. Export retains raw unchanged fields, applies subsequent
metadata edits, and validates retained field values against entry injection.
Export keys use portable source IDs; normalization/truncation is warned on import.
This is a supported BibTeX data subset, not a complete BibLaTeX/TeX/CSL engine.

Identifier/normalized-DOI conflicts use explicit keep/skip, rename incoming, or
replace metadata while retaining the existing key. Duplicate incoming IDs and
ambiguous DOI/key matches require repair or selection changes. Bulk updates parse
the destination once and preserve unmodified source ranges/extra data. Stale
note/workspace changes reject the reviewed plan; cancel/export never changes notes.

## Offline document citations — 2026-10-11

Bibliographic metadata belongs to its Markdown note, not a separate database.
Source identifiers are stable and note-scoped; they are metadata keys, not new
Universal Object identities. Existing note commands/save/history remain authoritative.

```markdown
<!-- orbit:source {"v":1,"id":"source-1","title":"Game Design","author":"Ada","year":"2026","publisher":"Press","doi":"","isbn":"","url":"https://example.org"} -->
Claim <!-- orbit:cite {"v":1,"id":"source-1","locator":"p. 42"} -->(Ada, 2026, p. 42)<!-- /orbit:cite -->.

<!-- orbit:bibliography v=1 style=author-year -->
## References

- Ada. (2026). Game Design. Press. https://example.org
<!-- /orbit:bibliography -->
```

Source fields are single-line strings up to 2,000 characters; a nonblank title is
required. IDs match `[A-Za-z0-9_-]{1,80}`; URLs require HTTP(S) and a host. Locators
are optional single lines up to 200 characters. JSON angle brackets are escaped
to prevent premature HTML-comment closure. Unknown source JSON fields survive
metadata editing; unsupported versions/malformed records remain authored source.

Compact author–year uses the entered author string (or title) and year (or n.d.);
References sorts descriptions alphabetically. Numbered style assigns first-use
ordinals and lists sources in that order. Sources appear once, only when cited.
Known generated bibliography regions are replaced explicitly; duplicate regions
refuse refresh. Duplicate IDs refuse source editing; missing IDs retain their
fallback with a warning. Code spans/fences, indented code, frontmatter and literal
HTML are excluded. Read/Rich hide known metadata; editable source remains intact.

Saving metadata refreshes citation labels and any existing generated bibliography;
inserting citations refreshes an existing bibliography. After ordinary prose edits
or citation deletion, use a bibliography button to refresh. Publishing automatically
refreshes an immutable snapshot and strips recognized metadata for PDF/HTML/Word.
No automatic network lookup, Zotero adapter, CSL engine or full APA/MLA formatting
is claimed. BibTeX and reusable libraries are delivered above. Existing image-source chips
and PDF quote provenance are unchanged. No storage migration is required.

## Markdown image-and-text sections — 2026-10-10

Figure details optionally appear at the beginning of a media section's body:

```markdown
<!-- orbit:figure -->
Caption: The figure's descriptive caption
- [Source label](<https://example.com/source>)
- [Local note](<orbit-object:canonical-uuid>)
<!-- /orbit:figure -->
```

Captions are single-line plain text (up to 2,000 characters), escaped for Markdown;
at most 20 sources have labels up to 200 characters and destinations up to 2,048.
Labels retain Markdown punctuation via escaping. Supported source schemes are
HTTP, HTTPS, orbit-object and relative local paths; spaces in paths use percent
encoding. UUID note links survive renaming, with authored labels kept explicitly.
No lookup, upload or bibliographic metadata is generated. Rich/Read show a caption
and source chips under the image. Text editing preserves the complete figure-detail
prefix; layout/image changes retain details. Dialog Apply checks captured source
and note identity; Cancel is inert. Clearing fields removes only figure metadata.
Malformed/unfamiliar forms remain in ordinary prose/source, without partial repair.
Caption/source links remain readable outside Orbit. Metadata is part of the owning
Markdown note; attachment bytes and object identity remain unchanged.

Layout comments enclose ordinary Markdown:

````markdown
<!-- orbit:media left width=200 -->
![Image description](<Attachments/photo.png>)

### Heading

- Detail with **formatting**
<!-- /orbit:media -->
````

Exact supported opening forms use left/right and width 160/200/260. The immediately
following line is an ordinary image; angle destinations, simple destinations and
optional double-quoted titles are supported. The closing comment is on its own
line outside fenced code. Nested sections, unfamiliar markers and incomplete groups
remain literal/source-editable. Other Markdown readers ignore comments and retain
the image, headings and text in vertical order. Existing image conversion preserves
its original Markdown line. Layout changes preserve body bytes; source parsing is
lossless for LF/CRLF. No new objects, copied attachment bytes or schema migration.
Inline text uses the existing rich editor and owning note's save/undo callbacks.
The section moves/deletes as one outer block; native text selection across the image
boundary remains the structured-block fallback. Read renders normal Markdown;
specialized nested widgets and global reference-definition resolution inside the
section are not claimed. Narrow/enlarged-text layouts stack vertically.

## Gantt work schedules — 2026-10-10

Working calendars are canonical orbit.note objects with properties.workingCalendar:
`{version:1, weekdays:[1,2,3,4,5], exceptions:{"2026-10-12":{working:false,label:"Holiday"}}}`.
Weekdays use ISO Monday=1 through Sunday=7, must be unique/nonempty; up to 1,000
dated exceptions override the week. Labels are optional, at most 200 characters.
Unknown sibling and exception fields are retained by calendar editing; removing an
exception explicitly removes that entry. Unsupported versions remain unedited.
Calendar UUIDs are reused, not copied: a view's workCalendarId supplies a default
for a reviewed schedule; task workCalendarId binds that task independently. An
explicit null task binding selects calendar days; absent bindings can inherit a
view default in the schedule form. Applying a view default never changes tasks.
Optional task workDurationDays is an integer 1–3,660 working-day effort, inclusive.
Moves derive it from an existing range if absent, then preserve it. Civil date
arithmetic uses UTC date components across DST; forward/backward planning snaps
to working dates. Without a calendar, existing elapsed-day move behavior remains.
Calendars do not encode hours, capacity, timezone recurrence or automatic holidays.
Editing a calendar leaves dates untouched; audit warnings identify endpoint and
effort mismatches. Scheduling checks captured calendar/task versions before save;
missing/unsupported calendars require explicit recovery or a calendar-days choice.
Unrelated task edits preserve unsupported calendar bindings. No migration required.

Ordinary orbit.view objects store viewType: gantt, optional ganttVersion: 1 (absent
means current), ganttDays: 14/28/56 (default 28), and existing scope/folder/smartQuery
fields. Unsupported versions are preserved and not edited by the Gantt surface.
Task objects optionally add scheduledEndDate, a YYYY-MM-DD inclusive work finish
paired with existing scheduledDate. No finish means a single day; dueDate remains
a deadline. ganttMilestone: true denotes a single-day milestone, independent of
legacy named milestone stages. blockedBy continues referencing canonical task IDs.
Unknown properties survive scheduling commands and restart; invalid legacy ranges
remain visible. No schema migration, copied tasks or generated dates. Schedule
mutation uses existing durable saves/recovery and guarded session-only undo.

## Research collections and decision records — 2026-10-10

No object/scene format migration. Research collections are orbit.view objects with
viewType: research, researchVersion: 1, researchLayout (Gallery/Table/Compare/Decisions)
and referenceEntries (up to 5,000 maps containing objectId UUID). Optional entry
boardId/placementId UUIDs reuse live placement commentary. Optional referenceCaption,
referenceTags, referenceStatus and referenceSourceUrl use existing reference detail
rules; localCommentary: true selects an independent collection override. Optional
briefId links an existing note. researchSearch/researchTag/researchType/researchStatus/
researchProject store simple filters. Missing memberships are retained. New creative
briefs optionally store researchViewId, linking their ordinary saved view.

Records remain orbit.note Markdown files with researchVersion: 1 and researchKind:
decision/assumption. researchState is Proposed/Accepted/Superseded/Rejected for
decisions, Unverified/Confirmed/Disproved/Superseded for assumptions. confidence and
importance are Unspecified/Low/Medium/High. evidenceIds, assumptionIds and supersedesIds
are UUID lists limited to 100 each. recordedAt and reviewedAt use UTC ISO timestamps.
evidenceVersions maps source UUIDs to revision:updatedAt:checksum:payloadHash fingerprints. The SHA-256 payload hash includes title/body/properties/data, so external edits with unchanged frontmatter are detected; immutable object fingerprints are memoized.
Missing sources remain referenced rather than deleted. Facts are user-authored;
review reasons are mechanical version comparisons, not factual contradiction claims.

The existing revisions list retains up to 30 before-edit/review checkpoints with
title/body/date/label/revision/wordCount and an optional researchFields map containing
state/confidence/importance/relationship lists/acknowledged versions. Existing note
history restores title/body only. New commands preserve unrelated metadata; future
research versions remain preserved and non-editable. Source bytes are never copied
or changed by adding/removing membership or writing research records.

## Creative project metadata — 2026-10-09

Creative planning reuses ordinary notes, tasks, Canvas data v1 and views. Optional
creativeProject/projectName metadata marks scaffold members. project/scope retain
the brief UUID. The brief stores projectBoardId, referenceBoardId and milestoneViewId
UUID links; tasks store existing milestone/resources fields and Markdown links.
Milestone views optionally store milestoneStages as a list of stage strings.
Missing/invalid/empty stage lists use existing game defaults. No migration, new
object identity, scene schema version or copying of canonical source content.
## Feedback compatibility — 2026-10-09

Canvas data v1 optionally stores `canvasPresetApplied: true` after an editable
emission to prevent starter preset regeneration on an emptied board. Unknown keys
and ordinary object references remain preserved; no migration or new identity.
New editor width defaults are 1080 logical pixels; legacy saved widths remain
honored, with the supported preference range extended to 520–2000.

The native recent-Vault registry retains its version-1 format and unknown fields.
Confirmed missing/non-directory paths are pruned on listing, with an unavailable
selection cleared to the chooser. Unavailable volumes or filesystem access errors
retain their entries. No Vault folder or knowledge file is removed by this action.
Creative briefs and code drafts become ordinary Markdown in their owning notes,
using existing note save/history; there is no separate code/brief storage format.

## Calendar planning metadata and export — 2026-10-09

Optional `properties.calendarPlan` is `{version:1,kind,estimateMinutes,resources}`
on ordinary tasks/events. Kind is assignment for tasks, or exam/study/lecture/meeting
for events. Estimate is an integer 0–10,080; resources is up to 100 UUID strings.
Course, priority, dueDate, scheduledDate and event intervals reuse existing fields.
Unknown metadata keys survive planning updates. Changed invalid/future metadata
rejects; unchanged future metadata survives unrelated commands and authoritative
file rebuilds. Resource links add planning-resource backlinks, without copying content.

Device `noteViews.calendarPlanning` stores `{version:1,mode,date,course,kind,search,
completed}` only when Remember view is used. Modes are Agenda/Week/Day/Unscheduled;
date is a civil date. Unknown siblings survive saves; future versions are not
overwritten. This remains the ADR 0022 device-settings boundary.

ICS snapshots contain UUID-based UIDs, VEVENT UTC/date intervals and VTODO dates.
If work is scheduled on/after a deadline, `X-ORBIT-SCHEDULED-DATE` retains that
civil date instead of emitting an invalid DTSTART/DUE interval. No import,
subscription, authentication or synchronization protocol is introduced.

## Study Resume device descriptors — 2026-10-09

Existing `spaces.items` records (`version:1`, `kind:space`) may carry
`studyVersion:1`, `studyCourse`, `studyContinuation` (up to 4,000 characters),
`studySavedAt` (UTC), `studyRevisions`/`studyTitles` keyed by object UUID, and
`studyDismissed` UUIDs. Their `context` holds only course tabs and view positions,
plus the existing permitted layout fields. Course names are existing property
values, not a new object identity. One saved continuation per exact course value;
the existing 30-context bound applies. These are device settings, not shared
knowledge or a second durable document copy. Unknown fields survive updates;
unsupported/invalid study records are not overwritten. ADR 0022 still governs.

Resume merges saved view state into current tabs without switching Space scope,
layout or appearance. Changed revisions reset that source's view offsets; missing
objects are skipped. Missing attachment bytes use normal reader recovery. Manual
save and dismissal are explicit; no passive focus/activity inference is added.

## Study cards — 2026-10-09

An `orbit.note` title is its question; body is its Markdown answer. Frontmatter
`properties.studyCard` is `{version:1,due,intervalDays,suspended,history,source?}`.
Due/review instants are ISO timestamps with explicit time zone, written in UTC.
History entries: `{at,rating,previousDue,previousIntervalDays,due,intervalDays}`;
ratings are `again|hard|good|easy`. Source: `{objectId,title,revision,capturedAt,
passage,page?,checksum?,pdfSource?}`. UUID/page refs reuse existing PDF navigation.
Unknown siblings and history fields survive; changed unsupported/invalid records
are rejected, unchanged future records remain portable and readable.

`properties.studyUnderstanding` is explicit `uncertain|learning|understood` on
original material; course membership uses existing `course`. Reviews do not
rewrite understanding. Export is `{format:"orbit-note-study",version:1,cards:[...]}`;
each card contains its existing object envelope, body, formatVersion and
documentExtra, including unknown card versions. Ordinary Vault backup/restore
preserves owning Markdown files and native recovery history. No migration or
SQLite authority change. See [ADR 0024](../adr/0024-portable-study-cards.md).

## Local OCR evidence — 2026-10-09

File `properties.ocr`: `{version:1,path,checksum,language,pages:[...]}`. Path equals
contentRef; checksum is actual-byte SHA-256. Each page has `text`,
`lines:[{start,end,x,y,width,height}]` and optional `corrected`. Ranges are UTF-16
offsets in original text; rectangles use normalized top-left source coordinates.
Corrections preserve original text but use page-only navigation. Limits: 500
pages, 2 Mi UTF-16 characters across original/corrected text, 20,000 lines.
Unknown siblings/page keys survive; future formats refuse recognition changes.
Validated saves verify bytes and retain recoverable history. UUIDs/original files
stay intact; ordinary backups carry evidence.

Passage notes contain quoted Markdown/UUID page links and `ocrSourceId`,
`sourceChecksum`, `sourcePage`; PDF notes additionally use existing
`pdfSource:{objectId,page,checksum}` navigation. They are authored snapshots.
Embedded-text cache remains version 1/schema 4; OCR overlays rebuild from verified
portable metadata and never enter raw property search. See [ADR 0023](../adr/0023-local-ocr-evidence.md).

## Smart Views, Spaces and task planning — 2026-10-08

All extensions are additive; existing object/file envelopes and SQLite schema stay
unchanged. Unknown sibling keys are retained. See [ADR 0022](../adr/0022-smart-views-spaces-and-task-planning.md).

- `orbit.view.properties.smartQuery`: `{version:1, match:"all"|"any", rules:[],
  sort:"updatedAt", descending:true, group:null, columns:["title",...]}`.
  Rules contain `field`, `op`, scalar `value`; operations are equals/notEquals,
  contains, empty/notEmpty, before/after/on and gte/lte. `relation:property` reads
  stored object IDs. Dates accept valid `YYYY-MM-DD`, today, tomorrow or week-end.
  At most 32 rules/20 columns. Membership/folder/scope refine candidates before
  predicates; absent values sort last. Stable ID breaks sorting ties.
  `viewType` selects list/table/board/gallery/calendar/timeline. Legacy definitions
  without smartQuery keep their existing presentation. Unsupported queries fail
  visibly without rewriting the definition or original knowledge.
- `orbit.task.properties.recurrence`: `{version:1, frequency:"daily"|"weekly"|
  "monthly"|"yearly", interval:1, anchorDate:"YYYY-MM-DD"}`. Interval is 1–366.
  Due dates are civil dates. `occurrenceHistory` is an append-only list of
  `{date:"YYYY-MM-DD", completedAt:"UTC ISO instant"}` through normal completion;
  future series edits preserve old entries. At 10,000 entries completion refuses
  explicitly. Undo restores the prior snapshot rather than appending another entry.
  `blockedBy` accepts legacy string or up to 100 task IDs; `parentTaskId` is one
  task ID. New edges reject invalid/deleted targets and cycles. Existing unresolved
  edges/unsupported planning metadata survive unrelated edits.
- Device settings `spaces`: `{version:1, items:[], activeId:null, base:{...}}`.
  Each of up to 30 records has version/id/name/kind (`space` or `layout`), optional
  project/folder/appearance, context and dashboard. Context captures view state,
  never object bodies, content references or attachments. Missing/deleted restored
  tabs are omitted; descriptors and unknown keys remain. Layouts retain active tabs
  and scope. Space scope applies to explorer/tasks/default calendar/search/Home;
  explicitly saved queries and object references retain their own semantics.
- Device settings `dashboard`: `{version:1, widgets:[{id,kind,span,viewId?}]}`.
  Up to 16 widgets use tasks/recent/projects/inbox/views/view and spans 1–3.
  Empty settings restore the existing temporal Home; unknown kinds render a
  placeholder. A missing saved view offers customization, not content deletion.
  Device settings remain excluded from portable knowledge backups as before.

Calendar rescheduling updates only the selected task dueDate/scheduledDate or the
event start/end fields. All-day exclusive duration and timed elapsed duration are
retained. Commands are source-revision guarded and journaled by the repository;
one session undo is available until another command or intervening edit.

## Research record metadata — 2026-10-03

Research remains `orbit.note` Markdown/frontmatter. Additive properties include
`researchSchemaVersion: 1`, `category`, status/confidence, `supportingIds` and
`contradictingIds` (canonical object IDs), `binaryId`, `binaryVersion`, `moduleId`,
`module`, `addressSpace`, `address`, `rva`, `moduleBase`. Addresses remain normalized
hex strings to retain 64-bit precision on web. `researchProvenance` stores manual
import version/method/tool/source plus original `record` and `context` metadata.
Patch records carry `appliesToBinary: false`; no attachment bytes are modified.
Research maps use ordinary Canvas-v1 reference cards/connectors. Playtest source
notes optionally carry `findingTaskIds`; task `sourceNoteId` remains unchanged.
Device settings optionally carry `reverseEngineeringEnabled`, false by default.
No migration rewrites old objects; unknown properties and existing data survive.

## Precise-reference extensions — 2026-09-30

Existing WikiLinks optionally carry a block `#^block-id`, heading, Canvas
`#element=UUID`, LaTeX `#label=...`, annotation `#annotation=UUID`, or existing
`#page=N` fragment. Unknown fragments survive. Stable explicit prose suffixes
` ^orbit-UUID` are created lazily, not on Vault open; rich edits preserve them.
An optional Canvas-v1 card `referenceTarget` string addresses the same object as
`objectId`. Source text remains in its note, not copied into placement data.
These are additive v1 extensions; existing envelopes and SQL schema are unchanged.
See [references](references.md) and [ADR 0020](../adr/0020-precise-reference-composition.md).

## Paragraph alignment — 2026-09-16

An exact standalone `<!-- orbit:align=center -->` / `right` / `left` comment,
followed immediately by a paragraph or heading, decorates that one block. Its
original marker, Markdown prefix and LF/CRLF ending remain part of its source
slice. Left alignment removes the marker when explicitly selected. A marker at
EOF, or followed by one blank line, represents an editable empty aligned paragraph.
Enter preserves alignment on the newly created paragraph. Unknown values and
comments before unsupported block types remain literal source. Other Markdown
readers can ignore comments without losing text. There is no storage migration.

This describes current code, while [storage and formats](storage-formats.md)
describes the broader target. Authority: `ObjectCodec`, `UniversalObject` and
`WorkspaceRepository`; preserve unknown fields when evolving these formats.

| Path | Current representation |
|---|---|
| `workspace.json` | JSON `format: orbit-note-workspace`, integer `version: 1`, UUID `id`, `name`, UTC `createdAt` |
| `Notes/<optional folders>/<title>-<uuid>.md` | UTF-8 Markdown, YAML frontmatter with `orbit` object envelope and `properties`; filename is not identity and stays stable on title rename; explicit folder moves change its path |
| `Objects/<uuid>.object.json` | `format: orbit-note-object`, `version: 1`, `object` envelope, `body`, `data` |
| `Boards/<uuid>.board.json` | Same envelope with `format: orbit-note-board`; `data` has `schemaVersion: 1` and `elements` |
| `Attachments/<checksum>/<name>` | Ordinary original bytes; an `orbit.file` object carries `contentRef`, MIME type, byte length and checksum. Relinking adds additive `attachmentSourceHistory` entries that retain previous immutable paths. |
| `.orbit/device/settings.json` | Versioned device layout/preferences; excluded from content export |
| `.orbit/history/`, `.orbit/recovery/` | Retained previous bytes and native interrupted/conflicted write recovery records |

The settings data map may contain `searchWorkspace`: an additive version-1 map
with `saved` recipe entries (`version`, `name`, `query`, kind/project/folder/tag/
matchKind filters, hideCompleted and order) and `recent` query strings. Recipes
are view preferences, not content references or result snapshots. Old settings
default to an empty library. Unknown library/entry fields survive edits; a future
library version blocks library mutation. Existing settings save/error handling
and device-only scope apply. No canonical object or index schema changes.

Object envelopes carry stable `id`, `typeId`, `schemaVersion`, `title`, timestamps,
revision, properties and optional deletion timestamp. Workspace membership comes
from the manifest on decode. JSON formats also carry an outer version. Unsupported
versions are read-only. Markdown without an Orbit identity is preserved and reported
for future import/adoption; it is not silently rewritten into an Orbit object.

Canvas elements contain UUID `id`, `type`, world coordinates and dimensions plus
type-specific properties. Cards use `objectId`; images use `contentRef`; ink retains
vector samples. Unknown scene fields/elements survive round-trip. Scene camera and
per-pane reading positions are device state, not duplicated object content.

A backup has `format: orbit-note-backup`, `version: 1`, `workspaceId`, `createdAt`,
`encoding: base64`, a `files` map from safe relative paths to encoded bytes, and
optional `directories` for empty Notes folders (see [ADR-0010](../adr/0010-notes-folder-moves.md)).
It includes implemented canonical files and retained recovery/history, not the
rebuildable index or device preferences. Desktop import into a new folder is implemented; see [ADR-0008](../adr/0008-backup-import-and-workspaces.md) for limits and journal quarantine.
Round-trip import tests verify canonical bytes; do not equate these with hardware power-loss validation.

Saved query views, explicit relation files, custom type definitions, portable
Space/layout presets and standalone annotation consumers remain planned formats.

## Schema references

[Workspace](../schemas/workspace-v1.schema.json),
[object envelope](../schemas/object-envelope-v1.schema.json),
[structured document](../schemas/structured-document-v1.schema.json),
[Canvas data](../schemas/canvas-data-v1.schema.json), and
[backup](../schemas/backup-v1.schema.json) document emitted v1 shapes. They are
interchange documentation, not a runtime schema-validation dependency. Code also
validates type-specific values and safe paths. These broad schemas deliberately
permit unknown fields; future import must validate paths, total size and references
in addition to JSON shape. Round-trip and compatibility fixtures live in the
storage/domain tests. Recognition of a drawing envelope does not mean a standalone
drawing UI has shipped.

Device note views include per-pane mode, selection and preview position, plus
folder collapse paths and note sorting. Renaming adds a readable alias. Authored
wiki links stay exact during autosave; `properties.orbitLinkBindings` maps readable
targets to stable IDs. Explicit ID syntax remains supported. These are additive
v1 fields; unknown fields remain preserved. See [ADR-0009](../adr/0009-audit-and-incremental-local-state.md)
for current mixed-backup, native event and completed-history retention contracts.

Rich editing adds no canonical format or migration. Device note views accept
`mode: rich` (legacy `write` still means Source), `splitRatio` clamped to 0.2–0.8,
and nested `rich` block/base/caret/scroll restoration state. These are disposable local
view preferences. Equations use portable dollar-delimited TeX in the Markdown body.
Visual table commands rewrite only the edited table; unknown constructs elsewhere
remain exact. See [ADR-0011](../adr/0011-source-preserving-rich-markdown.md).

## Calendar events

Events use `typeId: orbit.event` in `Objects/<uuid>.object.json`; there is no
separate calendar database or duplicate event content. Existing envelope version 1
is retained. Calendar projects these objects and task `dueDate` / `scheduledDate`
properties; deadlines and scheduled work stay distinct.

Event `properties` contain either:

- `allDay: true`, `startDate: YYYY-MM-DD`, `endDate: YYYY-MM-DD` (exclusive).
- `allDay: false`, `startAt` and `endAt`: UTC ISO timestamps ending in `Z`, with
  seconds and optional fractional seconds. The end must be after the start.

`contextId` optionally references a Universal Object UUID. Unknown properties and
unavailable context IDs survive event form edits. The device's local time zone is
used for timed input/display, never for interpreting all-day dates as instants.
Unchanged timed fields preserve their original sub-minute precision. Nonexistent
local clock times are rejected; new ambiguous fall-back times follow the platform
choice. Explicit IANA time-zone selection, recurrence and external providers are
not implemented. Invalid imported schedules remain intact and available outside
the date projection; the form does not silently initialize them to today.

The controller submits complete create/save operations through the existing
repository, checks the original revision after flushing pending edits, and keeps
the form open on failure. No new storage schema or migration is introduced.

## Derived search index

Native SQLite index schema 3 adds an FTS5 trigram external-content table and transactional triggers. It remains rebuildable from authoritative files; see [ADR-0012](../adr/0012-fts5-derived-search.md). Object/Markdown/Canvas envelope versions are unchanged.

Schema 4 adds disposable `pdf_text` rows (object ID and versioned JSON with
attachment path, actual checksum and complete ordered page strings). It retains
schema 3's FTS/object contracts and rebuilds from original attachments if lost.
Browser page cache is memory only. Search offsets are transient and do not extend
portable object/reference formats. See [ADR 0021](../adr/0021-checksum-bound-pdf-search.md).

## PDF reading and research links

Original PDF bytes stay in ordinary Attachments files, referenced by `orbit.file`.
`properties.pdfBookmarks` is a list of positive one-based page integers; editing
bookmarks preserves all other properties. `[[uuid#page=N|label]]` resolves the
same object for backlinks/graph and opens page N in Rich/Read. Renaming the file
object does not change the target. Viewer page navigation clamps to actual bounds.
The session's `noteViews['pdf:<pane>:<uuid>']` stores `page` and `zoom`.
It may also contain `annotationId` and a numeric `request` counter for repeated
source navigation. These are device/session navigation hints, not durable note
content. Annotation geometry is used only when the note's source checksum matches.

Extracted quotes are ordinary notes with quoted Markdown, a page wiki reference
and `properties.pdfSource: {objectId, page, checksum}`. Source bytes remain exact;
the checksum records provenance but this batch does not implement automatic
revision re-anchoring. See [ADR-0013](../adr/0013-local-pdf-reader.md).

Research/game-design/playtest document starters use the same ordinary note and
`pdfSource` fields. Headings and prompts are authored Markdown content, with no
template version or additional schema. When selected text spans multiple pages,
the source link records the first page. Starters do not imply extracted facts or
automatic task creation; users edit the document normally.

## Canvas columns and website cards

Schema 1 gains `column` and `link` element types using existing IDs/geometry/style.
A column has a `text` heading; direct child placements hold `columnId`. Geometry
remains world coordinates. Columns do not contain copied Universal Object content.
Dragging the header moves children; dropping an item inside arranges members by
vertical position. Columns cannot nest. Locked children block parent moves and
automatic arrangement. Removing a column clears child membership and retains the
items; cutting a column cuts its placements together. Undo restores the whole command.
Copy/paste remaps placement and column IDs while preserving object IDs. Cross-Vault
object remapping is still unsupported. New types remain opaque in older readers.

A `link` element stores `text` and `url`. Creation accepts only HTTP/HTTPS URLs;
opening requires an explicit gesture. No remote preview fetching or embedded scripts.
Links are board-local bookmarks, not new Universal Objects or semantic relations.

## PDF review metadata — 2026-09-14

Extends PDF highlight notes below with optional fields, without changing object
identity, envelope version, storage authority or SQLite schema:

- `pdfSource.kind: "pageComment"` denotes a page-level comment. `quote` may be empty
  when its Markdown body contains a nonempty comment. Its valid rectangle is an
  automatically placed marker, not claimed text-selection geometry.
- `properties.pdfReview: {"version": 1, "resolved": boolean}` stores review state.
  Missing state is open. Unsupported review versions are not overwritten by the
  review command. Unknown property/source/region fields are retained.
- Existing region `style` values are `highlight`, `underline`, `strikeout`; color
  remains ARGB. Updates preserve geometry and require the matching source checksum.
- The application command checks the exact current note snapshot before editing,
  preventing a stale review dialog from overwriting a newer pane edit. Normal
  `edit`/`flush`, conflict recovery and history persist the note; failures retain
  dirty drafts. No annotation editor writes the original PDF bytes.
- Review summaries are ordinary Markdown notes with UUID links and `pdfSource`
  provenance. They are snapshots, not annotation objects. No `pdfHighlightVersion`
  flag is set on summaries. A 2,000,000-character approximate construction budget and
  a 10,000-item create limit prevent unbounded summary allocation.

## Annotated PDF copies — 2026-09-15

Annotated-copy export (2026-09-15) reads these notes and creates a separate ordinary
PDF attachment through the existing importer. It introduces no source-side format.
PDF `/NM` contains `<note-uuid>:<region-index>`; `/T` is the note title; `/Contents`
contains Open/Resolved, the Markdown body and a readable UUID note reference. Each
region gets a Highlight/Underline/StrikeOut or Text annotation; text markup has
quad points in PDF page coordinates, converted from normalized display coordinates
with rotation/crop handling. Colors use region RGB; highlight opacity is 90/255.
These are editable, printable annotations, not flattened page content. Source
notes, unknown fields and original attachment bytes are retained unchanged.

Bounds: 64 MiB input, 80 MiB output, 2,000 notes, 10,000 regions, approximately
2,000,000 repeated comment/title characters. Actual byte checksum and current
source/note snapshots guard export/save. Unknown review versions/kinds/styles and
invalid geometry reject the whole export. No native PDF review-thread mapping or
import round-trip into Orbit is claimed. Export runs on PDFium's owning worker,
using a separate document without a JavaScript/action execution environment.

## Named PDF bookmarks — 2026-09-24

PDF attachment properties retain legacy `pdfBookmarks: [1, 2, ...]`. Optional
`pdfBookmarkNames` maps decimal page-number strings to user labels (trimmed,
maximum 200 UTF-16 code units). Empty names remove only that page's name entry.
Unknown string keys/values and other properties survive renames. Unsupported
non-map values are preserved by refusing the rename. Names without a matching
page bookmark are dormant; toggling membership does not erase them.

Rename uses the ordinary validated controller edit/flush boundary, checks the
expected attachment checksum, and reports success after persistence. Read-only,
deleted objects, missing bookmarks and stale sources are rejected. Failed saves
retain the dirty object and dialog draft through the existing recovery contract.
No automatic migration or PDF-byte modification is performed.

## PDF highlight notes — 2026-09-11

An ordinary orbit.note with properties.pdfHighlightVersion: 1 contains a Markdown
quote, stable page reference and optional editable comment. Its properties.pdfSource
has objectId, checksum, page, quote, and regions. Each region uses existing Canvas
rectangle fields id, type: rectangle, x, y, width, height, color plus one-based page.
Geometry is normalized to the displayed page, top-left origin. Bounds must be finite
and inside [0,1]. Creation limits are 10,000 regions and 100,000 selected characters.

Only matching-checksum regions are painted; stale versions retain all metadata and
show source-review status. Unknown versions remain readable ordinary notes.
Deleting/restoring a highlight uses ordinary note Trash/restore. No PDF writes,
object-envelope migration or SQLite schema change. See ADR-0014.

Source-file preview is disposable: extension mapping, strict UTF-8, 1 MiB limit,
binary/invalid-encoding fallback, existing syntax renderer (plain text above 50,000
characters). Copy Code retains decoded source and original line endings. No code
execution, compiler or executable web preview is invoked.

## Rolling event recurrence

Optional properties.eventOccurrenceOverrides: version 1, items map keyed by
occurrence:N (zero-based ordinal). Each item has status cancelled/rescheduled,
updatedAt UTC and, when rescheduled, EventSchedule allDay/startDate/endDate or
startAt/endAt fields. Bounds: 1,000 records; unknown siblings retained. Restore
removes the selected override through recoverable history. Keys remain stable
across advancement; rule edits retain anchorDate and processed. Projection values
are transient and cannot be persisted as objects. See [ADR 0026](../adr/0026-calendar-occurrence-projection.md).

Optional event properties.eventRecurrence: version 1, frequency
(daily/weekly/monthly/yearly), interval (1–366), anchorDate (YYYY-MM-DD), processed
(0–10,000), paused bool, overlap (earlier/later), optional count (1–10,000), until
(inclusive last start date), and finished bool. Unknown siblings remain intact.
properties.eventOccurrenceHistory is a list (max 10,000) of recorded schedules,
completed/skipped outcome, recordedAt UTC, rule snapshot, deviceZone and
offsetMinutes. All-day records use startDate/endDate exclusive; timed records use
startAt/endAt UTC. These are event context records, not new universal identities.
Unchanged unsupported metadata survives unrelated edits. Saves atomically update
the active schedule and history. See [ADR 0025](../adr/0025-rolling-event-occurrences.md).

## PDF form drafts

The file object's properties.pdfFormDraft contains version: 1, checksum and values.
Values maps page:annotation-index identifiers to bool checkbox states or String
text. These coordinates identify fields only within the exact source checksum.
Edits preserve unknown sibling properties. Unknown draft versions/source mismatches
are retained and rejected for editing. Save filled copy imports new PDF bytes as a
separate orbit.file; it never replaces original attachment bytes. No envelope or
SQLite migration. See [ADR-0015](../adr/0015-pdf-form-drafts.md).

## Reference-placement metadata — 2026-10-09

Canvas data v1 card placements may contain referenceCaption (string),
referenceSourceUrl (HTTP/HTTPS string), referenceTags (string list) and
referenceStatus (Inbox/Review/Chosen/Archived string). Details use normal Canvas
history; unknown fields remain preserved. Captured file objects optionally record
referenceBoardId plus existing folder/project/projectName metadata. Their original
contentRef/checksum/ownership fields remain authoritative. Summary notes are normal
Markdown with sourceBoardId and optional existing project/folder metadata.
No new scene/object version, migration, durable capture job or auto-fetch protocol.
## Gameplay evidence and development continuation — 2026-10-10

Gameplay evidence uses ordinary `orbit.note` Markdown/frontmatter. New records use
`gameplayVersion: 1`, `gameplayKind` (`code`, `playtest`, `verification`), canonical
`mechanicId`, optional `project`, `folder`, `category`, `resourceIds` (up to 40 UUIDs)
and `sourceVersions` (UUID → saved object revision). Code records store `codeReference`
with `repository`, repository-relative `path`, full lowercase `commit` (40/64 hex),
positive inclusive `startLine`/`endLine`, optional descriptive `branch`, and exact
`excerpt` (up to 100,000 characters). The Markdown body also retains readable source
context and an appropriately sized code fence. These references are never executable.
Playtests/verifications include `build`, `expected`, `observed`; verification adds
`verificationTaskId` and `verificationOutcome` (`passed`, `failed`, `blocked`).
Each result is a separate note. Tasks converted from findings carry `mechanicId`,
origin `sourceNoteId` and captured `build`. Existing source `findingTaskIds` is reused.
Mechanic specs optionally add `gameplayVersion: 1` and `gameplayResourceIds` (up to
100 explicit UUIDs). Unknown properties are preserved; unsupported gameplay versions
cannot be overwritten by gameplay commands. Ordinary body edits remain ordinary edits.

Device-local Space records reuse the existing `version: 1` context envelope and
add `gameplayVersion: 1`, `gameplayMechanic`, `gameplayNextStep` (up to 4,000 chars),
`gameplayRevisions` (UUID → revision). The existing `context` stores related tabs,
positions, note views and cameras, never object bodies/attachment bytes. Unsupported
or malformed gameplay descriptors are retained and cannot be replaced by Save session.
Resume preserves unrelated state and discards saved positions of changed sources.

## Live linked note sections — 2026-10-10

An ordinary owning note may contain:

```markdown
<!-- orbit:section {"target":"NOTE_UUID#^BLOCK_ID","section":true} -->
> # Captured heading
>
> Readable insertion-time snapshot.
<!-- /orbit:section -->
```

Only `target` (precise block/heading ObjectReference) and Boolean `section` are
recognized. Unknown fields, malformed quoting and unmatched markers remain source
text, preserving compatibility. Every snapshot line starts with `> `, so nested
markers cannot end an outer embed. New picker references use explicit source
anchors saved through existing note commands; no migration/second content owner.
`section: true` extends a heading through its subordinate content. `false` refers
only to the exact fragment. Missing or duplicate anchors never silently retarget.
Source edits update live previews; the snapshot changes only through deliberate
replacement. Detach copies current content (or fallback), recursively resolves
nested references with conservative cycle/depth/count guards and leaves fenced
examples literal. Removal changes only the owner note, with existing undo/history.
Live previews: 100,000 characters per section, note-identity depth five, maximum
24 nested cards per root. Oversized fallbacks expose open/copy actions rather than
silently truncating durable text. Same-note transclusion is conservatively rejected.
