# Use-case multiplicities and obstacle routing — 2026-10-24

**Superseded after owner review:** the owner rejected bundled automatic paths.
The later independent-line correction removes the search/shared lanes while
retaining label spacing, endpoint guidance and manual-route preservation. Full
suite evidence below applies to the earlier revision only. Current behavior and
validation are recorded in [current task](current.md) and the spatial-board spec.

Owner reported indistinguishable actor-end `2`/`2..*` multiplicities and lines
crossing use cases. The authorized chat **Aufgabe 1 Schritt für Schritt lösen**
confirmed the From/actor-end example and supplied a crowded two-actor diagram.
Chat contents were read as context; no homework records or messages were changed.
Scope: CAN-04/05/07/14/15/16, existing diagrams and their Markdown/export path.

## Changes

- Shared pure-Dart derived use-case layout, cached per scene/revision. Default
  automatic links route around visible node bounds with 16-unit clearance.
  System/fragment frames and lifelines are not solid obstacles.
- A bounded rectilinear search balances path length, bends, existing crossings
  and overlapping segments. Alternate actor-side escape routes handle a previous
  line directly in front of an actor. Fan-out ports separate associations.
- Endpoint label placement preserves authored multiplicities/roles and searches
  for space beside its own path, avoiding nodes, prior endpoint labels and lines.
  Canvas paint, hit testing and portable SVG use the same positions.
- Unrelated obstacle changes refresh all affected automatic-link index bounds;
  Undo/Redo and scene reopening derive the same routes without storing them.
  Temporary endpoint edits do not reuse a stale committed route.
- The relationship form explains the named From/To endpoint and includes `2..*`
  in examples. Swap direction swaps endpoint multiplicities. Label edits retain
  manual routing/anchors when relationship endpoints/kind are unchanged.
- Canvas, Rich/Read diagrams and publication snapshots share the existing
  renderer. Selected SVG exports include actual route/label extents.

No new packages, architecture, universal identities, storage schemas or authored
content are introduced. Existing class/sequence connectors and explicit manual
curves, orthogonal routes and anchors keep their existing geometry.

## Validation

**Full suite: 3,059 passed, five existing environment/manual skips, 13:32
(concurrency 2).** Eleven new regressions cover the crowded two-actor example, distinct
`2`/`2..*` labels, obstacle avoidance, hit/index bounds, move/remove/undo/reopen,
manual-route preservation, hidden nodes/system frames, reversed To-only labels,
crossing-pair detours, transient endpoint edits, selected SVG bounds, repeated
large-scene navigation and direction swapping. Light/dark real-font preview PNGs
are generated under `.local/uml-routing-preview/` and visually inspected.

The five skips are three existing native Python acceptance checks without their
configured interpreter, native symlink OS permission, and interactive Google
consent/uploads. Full log: `.local/uml-routing-full-tests.log`. The 18-link stress
fixture plus 450 repeated route/query lookups took 153 ms in this run; this is a
headless diagnostic, not a native frame-rate guarantee. All 907 frozen source,
test, tool, dependency and asset inputs remained unchanged through the full run.

Initial checks found a genuine actor-side escape crossing; alternate-side search
fixed it and the full run covers that case. Test-only corrections removed an
assumption about which side a detour must choose and a nonexistent SVG test
filename. No passing result is claimed for those initial failing attempts.
Format/strict clean across 763 files; final analyzer clean (18.4 seconds).
Configured Windows app and matching standalone server built successfully
(117.4-second Windows compile). Log:
`.local/uml-routing-final-windows-20261024.log`. All 907 frozen inputs unchanged
through final build; seven runtime/server files and new endpoint guidance/
multiplicity examples in release AOT verified. Previous PDF retry control remains
present. Runnable output: `build/windows/x64/runner/Release/orbit_note.exe` with
its sibling files. No app/host launch, private Vault modifications, archive,
GitHub publication, Android build or web build in this task.

Automatic routing is best effort and has a 12,000-expansion bound per search.
It cannot promise a crossing-free drawing for arbitrary topology or overlapping
placements; unsolved layouts retain their editable original route. Native mouse,
touch and physical screen-reader acceptance are distinct from headless tests.

Suggested next task: user-adjustable waypoints for intentionally arranged
use-case connections. Stop before implementing it.
