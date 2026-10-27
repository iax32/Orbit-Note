# University modeling and engineering lab

Owner-approved 2026-10-26, based on the supplied TU Wien UML, Software Engineering
and Distributed Systems material. This extends existing offline Canvas, Markdown,
Code workspace and publication boundaries; it does not add an account/service.

| ID | Delivered behavior |
|---|---|
| STUDY-06 | Editable state hierarchies/regions, events, guards, assignment actions, entry/exit, internal/external transitions, deep-history restoration and bounded completion. Replay generates active-state/variable/action evidence. |
| STUDY-07 | Activity control-token replay with explicit schedules, fork/join, decisions/merges, activity/flow finals, send/receive, named lanes, exception edges, interrupted regions and nested subactivity models. |
| STUDY-08 | Class/object/association-class/n-ary placements and declared structural checks: endpoints, slots, multiplicities, composition owner bound, inheritance cycles, declared/inherited operations. Sequence trace checks cover the explicit supported operators. |
| STUDY-09 | Authored CFG/test paths, reaching definitions/DU pairs, block/edge/atomic-condition observations, boundary partitions, expected/actual records and bounded JUnit XML import. |
| STUDY-10 | Java/Dafny snippets and optional language tools; explicit Java 21 source, Maven/Gradle JUnit and Dafny profiles; optional assignment protected-path save warnings. |
| STUDY-11 | Lamport/vector event traces, send/receive/drop/crash/restart, comparable per-client version observations and reachable-membership Bully/single-initiator ring election traces. Offline SMQP checking plus explicit native TCP sessions. |
| STUDY-12 | Editable Dafny contracts and explicit installed local verifier, bounded output, timeout/cancellation and source-ownership checks. No fabricated verification result. |

## Entry points

- Canvas toolbar: school icon **University Lab**. Also in the UML diagram menu.
  Select one existing university frame (or a member) to reopen it. With no model
  selected, existing classes/lifelines can seed connected UML checks.
- Markdown Rich toolbar: **+ → University Lab**. Reopen from the compact model
  card, or the same command. Source remains ordinary editable Markdown.
- Code workspace: **Code actions → University Lab**. Use **Run & build profiles**
  for Java 21/Maven/Gradle/Dafny commands and Configure for installed executables
  and optional Java/Dafny language servers. Opening a workspace starts nothing.

Choose a workspace, edit its example through item forms or Advanced model JSON,
then Next step or Run/check. A vector preview reuses the production Canvas painter;
active state/control-token nodes are highlighted. The report lists exact steps.
Save inserts native editable placements or replaces the note's generated report.
Copy Markdown includes both the portable model and its readable report. Restart
is possible by reopening/running the same model; Reset to example discards only
confirmed unsaved dialog changes. Switching workspace/closing prompts for drafts.

## Persistence and ownership

One model per note is stored as a single-line JSON header followed by generated
Markdown and an end marker. Unsupported versions, malformed/nested markers and
multiple models refuse mutation. Literal examples inside fenced blocks are not
interpreted. Appending refuses unfinished literal blocks. Read/search/publication
hide recognized metadata without changing authoritative Markdown. Reports are
readable outside Orbit; known metadata does not appear in PDF/HTML/Word output.
Generated report edits may be replaced when explicitly regenerating the model.

Canvas frames store the same versioned model in `universityModel`, plus tracked
generated placement IDs. Nodes/edges retain semantic keys across regeneration;
existing node geometry and unknown placement/model fields survive. Only tracked
generated members are replaced; free additions remain. Locked members refuse the
replacement. Canvas history owns the single change. Source/Vault/scene changes
while dialogs are open refuse late apply. Live diagram embeds/export reuse the
existing stable Canvas/object references, vector SVG and PDF theme handling.

## Explicit teaching subset and limits

- Models: 500 KB, 100 state/activity/CFG nodes, 150 UML items, 300 edges,
  499 state events / 500 activity/network steps. Completion: 100 transitions;
  subactivities: eight nested models. Reports cap at 1 MB. Bounded expressions
  support numeric/boolean literals, variables, arithmetic, comparisons, &&/||/!,
  parentheses; actions support assignments/increments only, with atomic failure.
  No eval, shell, arbitrary Java interpreter or unbounded program execution.
- State `do` is documentation, not a running task. Region initials are explicit.
  Equal-priority overlapping enabled transitions refuse ambiguity; independent
  transitions execute deterministically in entered order. This is a teaching
  operational subset, not UML certification or a general model checker.
- Activity object nodes are explicit model items; general object-token typing,
  parameter binding and external asynchronous activity execution are not inferred.
  Guards use entered variables. A schedule controls interleaving. A missing signal
  blocks receives, joins require one token from each incoming control flow.
- Sequence trace checks use entered message order and supported
  opt/assert/neg/strict/par/consider/ignore/break constraints; alt/loop alternatives
  must be expanded into distinct occurrences. Structural warnings are not proofs
  of domain correctness or automatic derivation from arbitrary source/PDF images.
- Coverage is calculated from authored execution evidence, not automatic Java
  instrumentation. Condition observations are explicitly entered booleans;
  JUnit import reflects actual testcase records, not grading points. No inferred
  successful test, mutation score or proof. JUnit XML: no DTD/entities, 2 MB import
  limit, 5000 cases (the persisted full model still has the 500 KB limit).
- Distributed read/write checks assume a comparable version order per key. They
  can flag monotonicity/read-your-writes observations; they do not prove global
  causal/eventual/sequential consistency or linearizability. Election assumes the
  entered reachable, responsive membership, not arbitrary-partition consensus.
- SMQP requires entered C>/S> transcript lines and validates greeting, command
  order/arity and acknowledgments. Native TCP is explicit desktop-only, eight
  seconds to connect, 8 KB incoming line/1000 lines and a 300 KB dialog transcript
  cap. Disconnection/cancellation closes owned sockets. No automatic remote access.
- Dafny is separately installed. Explicit verification writes one owned temporary
  source, passes separated arguments without a shell, captures bounded output and
  exit status, stops after 45 seconds and cleans up. Missing tools/errors are
  visible. Java/JUnit also require installed toolchains/project configuration.
  No compiler/language server was downloaded or silently installed by this update.

## Validation

See current task for actual checks and limitations. Synthetic model, GUI, native
loopback, file-reopen and PDFium export checks are separate from real Java/Dafny
compiler/verifier acceptance. User Vaults and original lecture PDFs are untouched.
