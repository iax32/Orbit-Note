# Home, context restoration and work sessions

Status: planned M5 onward; AI summaries later M8.
Sources: S03, S04, S06 in the [source map](../product/conversation-extraction.md).
Architecture: [UI/layout](../architecture/ui-layout.md),
[AI boundary](../architecture/ai.md).

## Purpose and workflow

Home should become a useful starting point for the user's work, not simply a list
of files. A returning user can see outstanding tasks, resume the relevant project
and recall the question they left unresolved. A work session can connect recorded
activity with an intentional continuation note.

## Requirements

| ID | Observable behavior |
|---|---|
| CTX-01 | Home can show today's tasks, recent objects, active projects, upcoming events and quick capture once those features exist; empty states remain honest. |
| CTX-02 | Supported dashboard widgets eventually include Inbox, bookmarks, daily note, graph summary, knowledge health, clock, habits and plugin/AI views; users choose which appear. |
| CTX-03 | “Continue where I left off” can reopen a saved project/Space and its relevant tabs/views plus a user-written continuation note. |
| CTX-04 | Users can explicitly start/end a work session associated with a project/context and inspect its local recorded activity. |
| CTX-05 | A session can reference notes opened/created, tasks completed, decisions made and files added; distinguish deliberate records from inferred relevance. |
| CTX-06 | Session summaries can show supported counts, changes, duration and unresolved work; AI-assisted prose is optional and cites its activity/content sources. |
| CTX-07 | Users can pause/disable activity recording, edit a continuation note and control retention; no system-wide screen/keyboard monitoring is required. |
| CTX-08 | Contextual panels and resurfacing offer relevant sources with a reason; dismissing a suggestion should be respected rather than nagging on every launch. |
| CTX-09 | Resume Context restores supported Space, tabs/splits, active document, selected project, note scroll/cursor/collapse, Canvas camera/zoom, PDF page/zoom/highlight and Smart View filter/sort/scroll state. |
| CTX-10 | Continue Session, Where Was I?, Continue Writing and Continue Reading are purpose-specific entry points to recorded context, with a recent navigation trail and valid-position fallbacks. |
| CTX-11 | A resumption summary can show unfinished prior tasks, recent decisions/resources and a suggested next step only from recorded context; inferred AI prose is labelled and grounded. |
| CTX-12 | Work/study/reading sessions can have optional time tracking and summaries without requiring system-wide activity monitoring or inventing unrecorded focus time. |

## Behavior details

An initial Home dashboard may be fixed and simple before customization exists.
“Six remaining tasks” must use the selected project's actual query; fabricated
counts or arbitrary completion percentages undermine trust. Calendar widgets need
local event/task data before any external calendar integration is proposed.

A restored session reopens references to current objects, not automatically old
snapshots. “Show what changed since then” is a separate history comparison.
Unresolved questions can be written explicitly by the user; AI may suggest one
but cannot present it as something the user said without evidence.

Activity metadata is personal workspace data, with opt-in scope and explicit
retention when introduced. Measure elapsed versus active time honestly; do not
claim exact focus time from an open window. Suggestions should support snooze,
dismiss or disable as appropriate. Exact resurfacing cadence is unresolved.

## Restoration state contract

Resume Context restores **view state around current content**. It is distinct from
HIST historical restoration. A deleted block, changed PDF or removed field cannot
be recreated merely to satisfy an old cursor/filter. Retain a meaningful fallback
and explain missing sources. Personal view state belongs to device/session settings
unless a user explicitly shares a layout; it must not overwrite another person's
cursor, camera or reading position during sync. Context snapshots need a versioned
descriptor format before arbitrary views/plugins can join this mechanism.

## Failure and acceptance scenarios

- CTX-03: save a context containing a note and plugin view, then remove the plugin.
  Continue restores the note and a recoverable placeholder for the plugin.
- CTX-04/05/07: pause recording, do work, resume and inspect the session; paused
  actions must not appear as tracked events.
- CTX-06: with AI disabled/offline, display recorded counts and the user's continuation
  note without waiting for a provider. Missing data appears unknown, not zero.
- CTX-08: dismiss an irrelevant resurfaced note; the user is not repeatedly shown
  the same suggestion without a new reason or an explicit reset.

## Delivery

M0 Home is only a welcome screen. Add real local recents/tasks after their data
exists. Implement manual continuation/context restoration before inferred summaries;
activity aggregation and AI are later independent enhancements.
