# Calendars and event context

Status: planned. Source: S10. [Tasks](tasks-calendar-and-planning.md) own task
semantics; this spec owns event/calendar behavior, not another task store.

| ID | Observable behavior |
|---|---|
| EVT-01 | Personal and project calendars display configured event dates, deadlines, milestones and scheduled tasks; scheduling a task does not silently replace its deadline. |
| EVT-02 | Events are Universal Objects with linked notes, resources and people. Opening an event reveals its recorded context and history, with backlinks to related work. |
| EVT-03 | Date-only, timed, timezone and daylight-saving behavior is explicit. Dragging a scheduled item previews and saves the affected date fields with undo. |
| EVT-04 | Shared calendars honor membership and object permissions; availability of a calendar never implies permission to read every linked note/resource. |
| EVT-05 | Later Google Calendar, Outlook and CalDAV adapters expose separate read-only/write scopes, source identity, sync state and conflict handling. No duplicate event on retry. |

Example: link lecture notes and a PDF to a course event, then open that context
from the calendar. Undated tasks remain available in an unscheduled list.
Deleting a calendar presentation must not delete all represented events.
External provider disconnect retains allowed local records with visible origin;
revocation and remote deletion need an explicit policy before adapter delivery.

Acceptance: open the same event from calendar and search and observe one identity;
move a scheduled task across a DST transition without changing its due date;
verify a viewer cannot perform a write through a drag gesture. External write
authorization is separate from permission to edit an ordinary local object.
