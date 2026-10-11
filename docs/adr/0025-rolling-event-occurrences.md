# ADR 0025 — Rolling event occurrences

Status: accepted direction, 2026-10-09. Delivery evidence is in the current task.
Extends ADR 0022's single-object recurrence and guarded planning commands.
Future calendar projection and individual overrides extend this model in
[ADR 0026](0026-calendar-occurrence-projection.md); the original limits below
describe the rolling-only stage.

## Decision

A recurring event remains one canonical orbit.event. Its current schedule is the
active occurrence across calendar, search and export. Explicit completion or skip
records the schedule, outcome, UTC action time and rule snapshot on that object,
then advances once. No generated objects or duplicate resource content. Missed
dates are not fast-forwarded. Count/end limits retain the last schedule as finished.

Optional version-1 eventRecurrence metadata reuses daily/weekly/monthly/yearly
civil-date arithmetic, including anchored month-end clamping. Timed repeats use
the current device's local start clock and retain elapsed duration. Explicit
earlier/later repeated-hour policy selects a valid UTC candidate. A nonexistent
time refuses the whole action, retaining history and schedule; the user edits the
event time before retrying. This is device-local policy, not a named-zone series.

Existing recoverable repository saves atomically persist schedule and history.
Stale/read-only checks and guarded session undo remain unchanged. Unknown keys
survive; unchanged future metadata survives unrelated edits, unsupported controls
refuse changes. History is bounded at 10,000 entries with an explicit refusal.

## Limits

The calendar displays the current occurrence; the editor previews six starts.
There is no expanded future-occurrence calendar, per-instance override object,
RRULE import/export, provider synchronization, reminder scheduler or IANA timezone
database. ICS remains a snapshot of the current schedule. Changing device timezone
changes the local clock used for subsequent advances. No migration or SQL change.
