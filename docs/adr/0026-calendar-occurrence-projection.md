# ADR 0026 — Calendar occurrence projection and overrides

Status: accepted direction, 2026-10-09. Extends ADR 0025; current task owns evidence.

## Decision

Keep one canonical event. Calendars project its bounded future schedules without
creating persistent objects. Each projection references the source UUID and an
ordinal key `occurrence:N`, where N is the series processed count before that
occurrence. Advancing the series does not renumber future keys. Rule edits retain
the anchor and processed count. Projected objects are read-only presentation
values; repository writes reject them and commands target the original snapshot.

Versioned eventOccurrenceOverrides on that event stores cancellations or complete
replacement schedules by occurrence key. A change affects one occurrence, never
the cadence. Calendar windows include moves whose original dates fall elsewhere.
Cancelled entries are omitted from calendars but remain listed with Restore in
Repeat & history. Restore removes that override; document history retains the
change. Rescheduled completion records actual dates, while advancing by the base
cadence. Cancelled current occurrences must be recorded as skipped.

Validated guarded saves and undo reuse the existing repository boundary. No new
UUID, SQLite migration, owned attachment or copied linked-resource content. Unknown
fields survive edits; unsupported override versions refuse modification. Old
workspaces without this optional metadata use their existing dates.

## Bounds and limitations

Projection visits at most 10,000 occurrences per series/window; truncation,
unsupported data and clock gaps show visible coverage warnings. Changed schedules
are bounded at 1,000 stored overrides. Occurrence controls use device-local time,
the saved overlap policy and unchanged duration. Paused series show only the
current occurrence; finished series retain their last schedule with its recorded
ordinal's override. A cancelled final occurrence stays hidden after skipped recording.
ICS exports the current schedule with its supported current change, not future
RRULE series. Provider sync, notifications and named-zone recurrence remain later.
