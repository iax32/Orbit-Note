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
