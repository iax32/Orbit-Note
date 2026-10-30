# Motion system

Status: planned, delivered with the affected features. Source: S10.
Motion should explain state changes and relationships, not compete with content.

| ID | Observable behavior |
|---|---|
| MOT-01 | Normal / Reduced / Off settings respect OS reduced motion. Off removes nonessential transitions while retaining direct input feedback and visible state changes. |
| MOT-02 | Panels, tabs, splits, docking, Space/theme switching, command palette and contextual toolbars use consistent brief transitions that preserve focus. |
| MOT-03 | Canvas pan/zoom, object creation, selection, drag settling, image insertion, graph expansion and semantic zoom explain spatial continuity without blocking input. |
| MOT-04 | Task completion, calendar drag settling, text-to-task/object conversion, undo return and delete-to-trash transitions make the resulting state and recovery path understandable. |
| MOT-05 | Resume Context restoration, graph-node-to-Canvas transfer, PDF highlighting, ink smoothing and auto-layout avoid surprise camera jumps and misleading persistence feedback. |
| MOT-06 | Subtle sync feedback and later collaboration cursors communicate useful activity. An optional orbital relationship reveal is experimental, never a constant background effect. |

## Defaults and acceptance

No constant decorative animation, pulsing chrome, excessive particles, bouncing
buttons or distracting galaxy effects. Proposed preference rule: OS reduced
motion caps Normal at Reduced; choosing Off is always honored. Reduced uses
minimal opacity/state changes without large travel/zoom. Exact durations/easing
are token decisions for a design task, not hardcoded requirements here.

Direct stylus/mouse movement remains responsive in Off mode. Ink smoothing is
input processing, not a reason to delay strokes or alter stored samples without
a defined contract. Sync animation must never imply a successful save before it
is durable. Interrupted/reversed transitions land in the actual current state.

Test all three modes, OS preference changes, keyboard focus during transitions,
rapid repeated actions and a representative large Canvas. Information and undo
remain available with animation disabled. No bespoke motion framework in M0.

## Initial implementation and timing (S12)

Current tokens use 110 ms for micro feedback, 180 ms for panels and 200 ms for
palette/dialog transitions. Aim for roughly 100–200 ms for small state changes;
use longer motion only when spatial continuity requires it. Normal, Reduced and
Off preferences honor OS reduction. Initial support suppresses nonessential theme
and dialog motion; not every planned MOT interaction is implemented yet.

Direct text, pointer, pen and camera input must remain immediate. Never postpone a
save, selection or accessible announcement to let an animation complete. Orbit-like
relationship reveals may be tested later as brief, optional explanations.

## Visual identity pass — 2026-09-11

OrbitMotionScope separates the app preference from the OS cap. Normal uses shared
durations; Reduced uses 110ms state/opacity and immediate spatial camera changes;
Off uses zero-duration custom transitions. Graph fit/focus stops after a finite
ease-out, and direct manipulation interrupts it. Existing nodes keep positions
across filters. Graph entry, Calendar headings, Task text, tabs and Copy Code use
bounded feedback. See observatory-pass-2026-09-11.md for unimplemented transitions.

## Quiet interaction motion — 2026-09-27

Delivered another MOT-01/MOT-02/MOT-04 subset using existing Flutter animations:

- Workspace destinations and document tabs use a 220ms arrival: opacity .88–1
  and four logical pixels of vertical travel. Only the current content is mounted;
  no outgoing editor or duplicate focus tree remains. Navigation and input are
  immediate, and successive changes restart from the actual latest destination.
- Inspector opening uses the existing brief opacity entrance.
- Explorer calendar expansion/collapse uses 180ms size easing. Its chevron rotates
  in 140ms; month changes use the same small content arrival. Day selection eases
  its background rather than flashing. Collapsed dates are removed immediately.
- PDF review and connected-note disclosures resize in 180ms while preserving their
  existing state. Hidden controls are excluded from keyboard focus.
- Shared controls ease their selection underline and a small icon-size change;
  explorer rows ease selected backgrounds. Completed task rows gain a quiet tint.
- Explorer drop feedback, task hover and outline hover now use preference-aware
  timing instead of fixed local durations.

Reduced (including the OS cap) has no travel, rotation, scaling or size animation;
state/opacity feedback lasts 110ms. Off uses zero-duration custom transitions.
Changing the preference settles an active content arrival immediately. These
transitions do not animate canvas cameras, ink, PDF page rendering, text input,
or persistence. No repeating decoration, spring overshoot, or staggered input delay.

Validation covers all three modes, OS reduction during a transition, repeated
navigation, focus and typing during arrival, and disclosure state/focus recovery.
This does not claim completion of all planned MOT requirements or a large-canvas
frame-time benchmark.

## Motion studio and authored presentation — 2026-10-23

The supplied animation guide is implemented as selectable alternatives and real
workflow feedback, using Flutter's existing finite animations and the shared
Canvas painter. Settings has a motion studio with 70 clearly labeled inspiration
samples, three personalities, bounded speed/category controls and optional focus
and reading aids. Notes present authored text read-only; Canvas replays stored
placements/strokes without content/history/export mutation and supports an
unsaved laser pointer. PDF adds controller-based navigation, perspective page
effects, a rendered-content lens and optional page progress. Review/format/grammar
feedback, revision scrubbing and actual graph path reveal preserve input focus.
No per-keystroke delay, idle particle loop, new AI/handwriting backend, mandatory
Markdown scroll progress, physical page-curl simulation or claim of full MOT
completion. [Exact coverage and validation](../tasks/motion-studio-2026-10-23.md).

## Cohesive interface pass — 2026-10-30

Dialog entry points share showOrbitDialog, preserving Flutter's modal barrier,
focus traversal, anchors, navigator choice, results and route settings.
Normal adds a restrained 5–8 px / .985–1 surface arrival; Reduced uses only the
brief route fade; Off and disabled Navigation & surfaces open immediately. Popup
menus, context menus and mobile editing sheets use shared duration/easing and
speed, with spatial growth disabled in Reduced/Off. Draft confirmations and
progress dialogs use the same boundary; operation results are never held for an
exit animation. Specialized authored presentation remains separate.

Desktop explorer opening, Settings category/search-mode arrival, category
selection, tab actions and save/sync labels use finite transitions. Search does
not replay on each keystroke. Status feedback shows the actual new label at once,
keeps one semantics tree, and never infers a save or transfer success. Hidden tab
actions fade while losing pointer, keyboard and semantics access immediately.

Entrance/fade-scale wrappers now retain the same child hierarchy when motion
preferences change; typing/focus/local controller state survives. Existing active
focus/status ambience stops its controller in Reduced, Off, hidden TickerMode or
disabled navigation, and resumes only when allowed. No new ambient loop, shader,
particles, backdrop blur, delayed pen input or outgoing duplicate editor is added.
The static child is passed outside per-frame builders. Physical device frame
latency remains a separate acceptance check.

[Scope, failures and validation](../tasks/cohesive-motion-2026-10-30.md).

2026-10-30 explorer follow-up: form controllers may use the shared dialog's
onDisposed cleanup boundary, retaining resources through exit while returning
results immediately. Folder inputs no longer guess a 250 ms disposal delay.
[Tablet explorer validation](../tasks/tablet-explorer-2026-10-30.md).
