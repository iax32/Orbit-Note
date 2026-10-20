# Implemented open formats — v1 subset

## Canvas ink transfer compatibility — 2026-10-18

Existing version-1 ink `points` are placement-local samples. Duplicate, paste,
align and distribute offset placement `x`/`y` once and preserve the points verbatim,
including pressure/time and unknown per-sample fields. Connector endpoints
remain world-space and still receive their existing translation/remapping.
There is no schema/version change or automatic rewrite of older boards. Canvas
clipboard data that cannot be represented as supported Markdown retains its full
literal payload, including labelled drawings; partial conversion is refused.

## Technical article metadata — 2026-10-17

The existing leading `orbit:publication` version-1 JSON comment may include an
optional `article` object with `version:1`, string fields `title`, `description`,
`author`, `authorUrl`, `canonicalUrl`, `imageUrl`, `language`, `published`,
`modified`, and optional Boolean `indexable` (default true). Fields are bounded
to 2,000 characters without control characters. URLs use absolute HTTP(S), no
credentials; dates use real YYYY-MM-DD values, with modified >= published when
both exist. Language is a bounded hyphenated language tag. Author/dates are not
invented. Unknown publication/article fields survive updates; malformed/future
article metadata refuses editor replacement and yields an HTML export warning.
Older publication readers retain this optional data without needing a migration.

The original Markdown remains authoritative. Ordinary editor changes/history
own metadata saves. CMS fragments omit document head/script/style metadata;
standalone HTML exposes escaped head metadata and JSON-LD plus visible authored
byline/dates. The handoff is not a CMS API or crawler audit. See the
[workflow](../features/technical-article-publishing.md) for fidelity boundaries.

Research diagrams use schema-1 ordinary rectangles/arrows and explicit placement
references in existing live-object blocks. Optional `researchDiagram` labels
identify a preset; no new rendering engine or object type is required. Export to
Markdown also accepts ordinary technical shapes; relationships resolve only
between included nodes. Address calculations are authored tables, not live
memory handles or canonical bare-address object identities.

## Review workspace commands and Canvas boards — 2026-10-17

Bulk review editing adds no durable format. Annotation notes retain existing
`pdfHighlightVersion:1`, `pdfSource` regions and `pdfReview` state. Edits preserve
unrecognized fields and unsupported region entries. Page comments keep their
kind and cannot become text markup. Results/Undo receipts are immutable runtime
collections of before/after object snapshots; partial commits remain ordinary
revision-checked note saves with recoverable history. They are not a transaction
journal or an extra storage authority.

Create review board writes ordinary Canvas schema 1 `card` placements with new
placement UUIDs and existing PDF/note `objectId`/`referenceTarget` identities.
The PDF card has a page reference, and note cards reference canonical note IDs.
Only title fallback labels and layout are stored; passages/bodies/bytes are not
copied. Optional board property `sourcePdfId` records provenance. Existing folder,
project and course ownership can carry from the PDF. Older readers retain ordinary
card presentation; no migration or alternate rendering engine is required.

## Precise live diagram selections — 2026-10-16

The existing schema-1, three-line Markdown `orbit-object` block can link to
`orbit-object:<canvas-id>#elements=<encoded-json-array>`. The fragment value
is URI-encoded JSON containing 1–1,000 distinct nonempty placement IDs, each at
most 200 UTF-16 units. Parentheses are percent-encoded to keep the Markdown
link unambiguous, including for arbitrary authored IDs. Existing `element`,
section, page, annotation and unknown fragments retain their behavior.

Resolution includes visible/renderable placements with those IDs and current
visible connectors whose two bound endpoints are in the selection. New internal
relationships therefore appear live. Unavailable IDs are reported; resolution
never substitutes the rest of the board. No content, geometry, screenshot,
attachment, migration or new universal identity is stored in the note.
Canvas JSON remains authoritative. Older/external readers retain a usable
source link; publication exports warn that the preview is not embedded.

UML surfaces use one pure palette derived from the rendering background and
foreground in native painting and SVG. Stored class accents remain unchanged.

## UML Canvas presentation — 2026-10-16

Canvas schemaVersion 1 remains unchanged. A class is an ordinary `rectangle`
placement: `text` holds its name; optional `uml` map contains `attributes` and
`operations` (arrays of authored strings), `stereotype` (string) and `abstract`
(boolean). Unknown nested/root/placement fields survive edits and save/reopen.
Readers without UML support show a named rectangle and preserve the extra fields.

UML relationships are existing `connector` placements with bound `startId` /
`endId`, `umlRelationship` (association/dependency/generalization/realization/
aggregation/composition), ordinary style/routing/marker fields, and optional
`startMultiplicity`, `endMultiplicity`, `startRole`, `endRole` strings.
`startAnchorOffset` / `endAnchorOffset` are finite fractions along their resolved
attachment side (default .5, clamped 0..1). Finite `routingOffset` shifts an
orthogonal middle lane in world units (default 0; rendering clamps ±10,000).
New marker spellings: `hollowTriangle`, `hollowDiamond`, `filledDiamond`; legacy
`diamond` keeps its existing filled appearance. Hollow markers cover the line
behind them with the surface color. Marker, label and bound geometry is shared
by painting, hit testing/culling and SVG where appropriate. No class object IDs,
file sidecar, migration or database-only data are introduced.

JSON is the lossless editable transfer; SVG/PNG are presentation exports. Existing
Mermaid output remains a flowchart, with a visible UML fidelity warning.

## Personal Drive sync operational formats — 2026-10-15

Bulk transfers reuse these per-Vault formats; no batch file or authored migration
is added. A first batch connection persists folder/pending IDs with `enabled:
false` until reconciliation completes (including a retained conflict needing
review). Cancellation/failure retains the interrupted plan without newly enabling
automatic sync. Existing opt-ins stay enabled. Native `selected-workspace.json`
version 1 now retains up to 50 recent locations. Adding downloaded recents keeps
the active `path`, `closed` state and unknown optional fields unchanged.

No authored Vault migration. `.orbit/device/sync/drive-settings-v1.json` uses
`format: orbit-drive-settings`, `version: 1`, Vault `workspaceId`, Google `subject`,
display `email`, boolean `enabled`, remote `folder` and optional `pendingFolder`.
The generated pending folder ID is saved before creation. This file is device-only;
portable import does not silently opt a new device into uploading. Unknown optional
settings survive edits; unsupported versions remain untouched and block setup.

`.orbit/device/sync/drive-uploads-v1.json` uses `orbit-drive-uploads`, version 1,
opaque `bindingId`, `operations` and immutable `records` cache. Each operation stores
its exact SyncEntry/parent IDs, generated blob/record IDs and optional resumable
session URL before use. Cached records retain provider MD5 plus decoded protocol
data. These are operational capabilities/state, excluded from exports and content
sync; account tokens stay in the existing secure adapter. Both files use repository
serialization, expected-hash writes and Vault-opening guards. The existing engine
state-v1 file additionally supports optional `resolutions` intents and conflict
`alternatives`; old version-1 state without those fields remains readable.

Drive owns a `sync-vault` folder with `orbitProtocol: 2` and canonical Vault UUID.
Immutable raw binary blobs use role `sync-blob`; immutable JSON records use role
`sync-revision` and key-routing SHA-256 `orbitKey`. A record has format
`orbit-drive-revision`, version 2, `workspaceId`, exact SyncEntry, `blob` ID, byte
`size`, `parents` and `operation`. Local logical paths/IDs never become Drive IDs.
Blob verification precedes record publication. A full paginated graph requires
existing same-key parents and no cycles; every unreferenced head remains visible.
Records are limited to 64 KiB, graphs to 10,000 records and resolutions to 64 parents.
Local checkpoint files retain the 16 MiB bound. No cloud deletion/GC is performed.

Retained `.orbit/sync-conflicts/<digest>/{local,remote,conflict.json}` copies remain
portable recovery data. A branch with no local object stores only remote bytes and
a nullable `local` descriptor. The digest includes remote identity/version so
separate branches cannot collide merely because their bytes match. Recovery does
not create a duplicate live universal object. Review/selection does not execute
imported recovery records; explicit resolution uses normal guarded apply/history.

## Project launch configuration — 2026-10-13

`.orbit-ide/config/launch.json` version 1 contains `profiles` (up to 30). Each has a
stable string `id`, `name`, project-relative `cwd` and 1–8 ordered `steps`. A step
uses `tool` (`python`, `compiler`, `custom`, `program`), an `arguments` string array
and optional custom `executable`. `{output}`/`{buildDir}` are runtime substitutions;
device interpreter/compiler paths remain private tool settings. Root/profile/step
unknown fields survive editing. Duplicate IDs, malformed/future data and unsafe
working folders refuse replacement. Configuration is limited to 128 KiB.

Expected-hash saves share the project's save lock and retain flushed
`.orbit-ide/config-history/<timestamp>-<uuid>.json` checkpoints with version 1,
`before` and `after` configuration. The picker offers the latest 20 compatible
prior settings. A checkpoint can represent an interrupted attempt. No settings
auto-start a tool or become duplicate Vault objects; no Vault migration is needed.
Preview address, cookie/token and reload revision are ephemeral memory only.
See [ADR-0029](../adr/0029-code-launch-and-loopback-preview.md).

## External code project recovery — 2026-10-13

Normal UTF-8 source files in an explicitly selected native folder are authoritative;
they are not duplicate Vault objects. Up to 1 MiB is editable, retaining authored
line endings and a UTF-8 BOM when present. `.orbit-ide/save.lock` coordinates Orbit
saves; this does not lock out unrelated external editors.

`.orbit-ide/drafts/<path-sha>-<session-uuid>.json` contains version 1, relative
`path`, nullable source SHA-256 `baseHash` and `text`. A session clears only its own
draft. The latest candidate is recovered with conflict review when the base differs;
older/other-session drafts remain intact. Malformed/future records remain intact
and generate a warning rather than replacing current source. Recovery text is
bounded to the same 1 MiB source limit and rejects NUL.

`.orbit-ide/history/<path-sha>-<timestamp>-<uuid>.json` contains version 1, `path`,
`before`, `after`, `beforeHash`, `afterHash`, `hasBom` and UTC `savedAt`. The flushed
checkpoint precedes source replacement, so it can represent an attempted save.
The picker reads the latest 50; underlying history is retained. `.orbit-ide/build`
holds generated single-file binaries and debug artifacts. Source browsing skips
this operational folder. Code projects/history are outside automatic Vault backups.

Private application-support `code-tools.local.json` version 1 stores `python`,
`compiler`, `debugger`, `debuggerArguments` (JSON-array text), and a `servers` map
with HTML/Python/C++ `executable` and `arguments` arrays. Same-directory flushed
replacement preserves unknown root/server fields; future settings versions refuse
replacement. These device-specific paths are outside Vaults, synchronization and
exports. There is no Vault storage migration. See [ADR-0028](../adr/0028-scoped-code-workspace.md).

## Technical evidence and comparison snapshots — 2026-10-13

Ordinary note properties optionally contain `sourceCapture` version 1 with method
`working-tree-capture`, repository label/path, relative file path, startLine/endLine,
language, excerptSha256, optional sourceSha256 and UTC capturedAt. Exact source
text remains in a Markdown code fence. This metadata is not a filesystem access
grant or a verified Git revision. Resource IDs retain canonical project context.

Build Comparison notes use researchComparisonVersion 1, binaryId, baselineBuild,
candidateBuild, comparisonCounts, resourceIds and sourceVersions. Markdown retains
a readable snapshot and original UUID links. Build Investigation tasks use the
normal task format with those build/source references and an editable checklist.
Unknown properties and authored records remain preserved. No dedicated database,
source authority change or workspace migration is introduced.


## Private desktop Google registration — 2026-10-13

Windows secure-storage key `orbit.google.desktop-client.v1` optionally stores JSON
`{version: 1, clientId: string, clientSecret: string}` for an unconfigured preview.
Only validated native Desktop app configuration is accepted. A compiled client
always takes precedence; it cannot be replaced by import. Unknown stored versions
are rejected. This device-only record is outside Vaults and exports, contains no
account tokens and does not change the durable knowledge/save authority. Existing
account credential records retain their separate client/account binding.

## Note print settings — 2026-10-12

A note body may start with one `<!-- orbit:publication JSON -->` line. JSON has
`version: 1`, `style` and `blocks`. Style fields are `letter`, `serif`,
`numberHeadings`, `titlePage`, `contents`, `pageNumbers`, `margin` (24–90 points),
`fontSize` (9–18 points), `author` and `header` (each at most 500 characters).
The record is at most 256,000 UTF-16 units, with at most 1,000 block settings.

Block keys are SHA-256 hashes of canonical parsed Markdown node content: tag,
sorted authored attributes and recursively encoded text/children. Generated
`orbit-*` attributes are excluded. Only unique top-level tables and paragraphs
containing one standalone image receive overrides. Duplicate or changed content
is reported rather than silently retargeted. Stale/orphan settings remain stored.

Each block may contain integer `width` (25–100 percent), `alignment`
(`left`, `center`, `right`), `caption` (single line, at most 2,000 characters),
Boolean `pageBreakBefore`, and Boolean `repeatHeader`. Defaults are 100 percent,
left alignment, no caption/break and repeated headers. These are print settings;
the source image bytes, table cells and ordinary Markdown remain authoritative.

Known settings are validated before hiding or rewriting the leading record.
Unknown fields are retained when saving settings; resetting a block removes known
layout fields while preserving unfamiliar fields. Future/malformed versions
remain literal and cannot be overwritten by Save settings. Fenced examples are
not treated as a leading record. JSON escapes HTML delimiters; presentation
exports do not execute comment contents. No storage migration or new content owner
is introduced. Settings edits use existing recoverable note commands/history.

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
and `properties.pdfSource: {objectId, page, checksum, quote?}`. New extracted notes
retain the optional quoted text for citation dragging; older notes without it
remain valid. Source bytes remain exact;
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

2026-10-15 reader controls expose that existing Trash lifecycle directly, with
revision-checked deletion and Undo of the exact returned trashed snapshot. Comment
text, unknown metadata, source-version anchors and UUIDs are retained. Page lookup,
decoded-region reuse and pending-save previews are disposable view state; they
are never persisted as an alternate annotation authority. Ordinary highlight
creation no longer implicitly opens the review panel or changes the page viewport.

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

## Connected project context and relationships — 2026-10-12

Device settings `projectContext` is version 1 with optional selected project ID,
panel pin and `projects` map (maximum 30). Per-project records retain continuation
`draft`/`nextStep` (maximum 4,000 UTF-16 units), supported WorkspaceContext descriptor,
source version map, saved/resumed times, recording flag and newest-first activity
(maximum 300 records: object ID/action/UTC timestamp). Unknown fields round-trip;
unsupported versions/shapes are not mutated. Private descriptors are not knowledge
content and remain excluded from portable knowledge backup.

Objects own optional `orbitConnections: {version: 1, items: [...]}` metadata,
maximum 200 entries. Authored records contain stable relation ID, supported kind,
ObjectReference target string, reason (2,000 units), observed versionToken and
created/reviewed UTC timestamps. Normal Markdown frontmatter/object envelopes own
these records. No separate relation repository/index authority is introduced.
Unknown record kinds/fields are preserved; future envelopes refuse mutation.
Creation accepts 1,000-unit targets, rejects self/duplicate/missing targets and
checks an expected source version when a dialog is open. Missing/future precise
fragments remain references and cannot silently bind to another object.

## Optional course metadata — 2026-10-13

Ordinary orbit.note overview records retain isCourseOverview and legacy course,
folder, semester, lecturer, courseCode and ects. Optional courseDisplayName is
presentation metadata; it never rewrites Markdown/path labels. courseStatus is
active/passed/archived; finite numeric ects accepts 0–120 including fractions.
courseBoardId optionally references an ordinary Canvas. Material/view properties
can record courseId as the overview's universal UUID. An explicit empty courseId
excludes membership even when a legacy folder matches; absent IDs use legacy
folder/name membership. Existing unknown data is retained, with no destructive
migration or new object/scene format. Hub course continuations use the UUID as
the existing studyCourse key; legacy name keys remain supported.

## Precise live object-card targets — 2026-10-13

The existing three-line orbit:object v=1 Markdown marker accepts an optional
ObjectReference fragment in its orbit-object URL: orbit-object:UUID#fragment.
No fragment preserves the existing representation. UUID remains canonical source
identity; the fragment is navigation/presentation metadata. Supported fragments
use the existing ObjectReference contract (page, block, heading, label, annotation,
element); unknown fragments are retained. Malformed/unsupported markers remain
literal authored Markdown. Older readers that do not recognize a precise card
can retain its readable link as source. Canvas placements use existing objectId,
referenceTarget and presentation fields; no scene-version change.

Derived reference caches are non-durable and rebuildable. Objects own all
reference metadata, normal repository history retains mutations, and no separate
reference database becomes storage authority. Authored orbitConnections kinds
also support references, part of, depends on and inspired by; unknown records
still survive edits. Canonical courseId now participates in project context and
legacy saved-view scope matching; selected canonical courses give newly created
objects courseId/course ownership. Explicit ownership wins, legacy course labels
remain compatible, and no existing object is migrated or renamed automatically.

## Callout block folding — 2026-10-14

Existing quoted callouts additionally recognize an optional immediate `+` or `-`
after the type bracket: `> [!BTW]- Optional title`, followed by ordinary quoted body
lines. BTW is the By the way preset. The marker sets the initial view state only;
body content stays ordinary authored Markdown. Default-setting edits change one
header, while local folding does not serialize. Unknown alphabetic types/body
source/line endings survive title and body editing. Read search expands callouts
transiently. No new workspace format version or object migration is required;
other Markdown tools retain a readable quoted header and the complete body.

## Math Lab portability — 2026-10-14

Calculated results and 20 mathematical templates use existing ordinary display
TeX. Markdown uses $$ blocks with readable calculation/parameter/approximation
text; rich LaTeX uses a standard equation environment before end{document}.
Variables are retained in TeX as well as Markdown descriptions. Plot placement
uses existing grouped sticky/line/ink/text JSON (finite coordinates and local ink
points); its expression, parameters and window are visible source text. Plots are
editable snapshots and serialize/export through existing Canvas JSON/SVG paths.
No object/format version change, new engine or persisted calculator cache. Unknown
existing scene/object data remains untouched. Numerical tools do not execute TeX.

## Live plot recipe v1 — 2026-10-14

An ordinary fenced code block labelled orbit-plot holds JSON:

```json
{
  "version": 1,
  "title": "Wave comparison",
  "functions": ["a*sin(x)", "cos(x)"],
  "variables": {"a": 2},
  "window": {"xMin": -5, "xMax": 5, "yMin": -5, "yMax": 5}
}
```

One to four nonempty single-line expressions use the bounded real arithmetic
parser. At most 12 ASCII named parameters are finite numeric values; x is reserved
for the horizontal axis and pi/e are constants. Windows follow existing ±1,000,000,
increasing/distinct-sample bounds. The optional title is at most 120 UTF-16 units.
Recipes are at most 65,536 UTF-16 units and 32 JSON nesting levels. Out-of-range
numbers, integers beyond JavaScript's exact safe-integer range, and decimal
metadata that would change value when re-encoded are refused before decode;
unfamiliar data cannot silently become Infinity/zero/rounded values.
Unknown metadata/window fields remain deeply immutable in memory and survive
explicit edits. Unknown versions or malformed/unsupported recipes remain literal
editable fenced code; they are not rewritten automatically. Known-field edits
serialize JSON inside the original fences and preserve CRLF without doubling CR.

The source recipe is authoritative; no raster attachment or database-only graph
cache is introduced. SVG export is standalone escaped vector data with the recipe
in its description. XML-incompatible characters are sanitized in the derived SVG
text; the authored recipe stays unchanged. TSV/CSV value exports are sampled numeric snapshots with
undefined domain cells labelled. LaTeX/table output stays ordinary TeX; Canvas
comparison output uses existing grouped sticky/line/ink/text JSON. No workspace
format/version change or mandatory migration. Publication formats currently keep
the fenced source as code rather than promising an embedded graph export.

## Private sync continuity v1 — 2026-10-15

OS-protected device key `orbit.drive.schedule.v1` stores JSON with format
`orbit-drive-schedule`, version 1, enabled boolean, Google subject, minutes
(1/5/15), and vaults (id/path/name). At most 50 unique UUID selections and 256 KiB
of configuration are accepted. Supported unknown root/entry fields survive
updates; malformed/future configurations freeze until explicit Forget. This is
local scheduling intent, never a sync binding or authority to re-enable a paused
Vault. Per-Vault native bindings/outboxes remain in their existing guarded stores.

Device key `orbit.shared.connection.v1.<SHA-256 of Vault UUID>` optionally stores
JSON with format `orbit-shared-connection`, version 1, workspaceId, server, room
and token. Maximum 16 KiB; endpoint uses existing HTTPS/loopback rules; room/token
are 43 base64url characters. Explicit Remember preserves supported unknown fields;
future/malformed formats cannot be replaced without Forget. No root owner key,
cached role or auto-join flag is stored. Reconnect uses live permissions and local
divergence checks. Neither private format enters Vault files, exports, content
sync or logs. No authored version change or migration is introduced.

## Device-local writing appearance v1 — 2026-10-14

Existing session noteViews may contain writingAppearance with version 1, design
(orbit/pixelBook/classicBook/crt/retro/command/blueprint/fieldJournal/typewriter/
amberTerminal), paper (plain/ruled/grid/dots), spacing (finite 20–64 logical pixels),
details, styledFont and quiet booleans. Optional pixelSnap defaults true; false
opts the pixel font out of display-aligned sizing. Existing raw unknown fields
remain preserved, and no older preference needs rewriting on open.
Missing/invalid/future preferences use Orbit/plain with defaults; unrelated view
updates retain the raw stored value. Explicit Apply retains unknown fields while
setting the supported fields/version. Note/pane keys remain the existing identity.
This is private view presentation, never part of Markdown, object properties,
ordinary exports or recovery history. No workspace version or migration changes.

Optional writingAppearance.photo v1 contains id (64 lowercase hex SHA-256 of the
normalized bytes), name (at most 120 UTF-16 units), opacity (0–1), x/y (-1–1), fit
(cover/contain), and readingSheet (default true). Unknown/future photo recipes are
not loaded but remain in raw preferences through unrelated changes. Explicit
Remove/Reset removes this reference; other unfamiliar fields remain preserved.
Bytes are static normalized PNGs at .orbit/device/writing-backgrounds/<id>.png,
at most 2 MiB and 1,600 px per side. Repository serial writes use the captured Vault
identity and existing guarded atomic store; reads are size/stream/header/hash
checked. Identical images reuse the same private file. The device path is excluded
from content sync and bytes are never embedded in repeatedly saved noteViews JSON.
These are presentation copies, not ordinary attachments or authored object IDs.
Unused copies remain until device state is deliberately cleaned; no migration,
automatic garbage collection, live external-file reference or image deletion command.
