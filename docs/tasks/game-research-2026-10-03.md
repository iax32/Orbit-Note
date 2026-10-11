# Game development and reverse-engineering implementation — 2026-10-03

## Request and scope

Read the docs and implement the game-development/reverse-engineering features.
This records the first local delivery and the remaining work, not completion of
every requirement. Preserve existing dirty work; no desktop automation, package
installation, binary execution or account requirement.

## Requirement audit

| Requirement | Evidence / current boundary |
|---|---|
| GAME-01 | Existing project scaffolds, specialized Markdown templates, seven scoped views and shared Canvas presets. Dynamic editable type definitions still need the common registry. |
| GAME-02 | Existing finding conversion; this pass makes source/task links ID-based, adds persisted findingTaskIds, rejects missing/read-only sources and retains newer source edits across asynchronous task creation. Decisions/resources can be referenced using existing universal links; no atomic multi-object transaction is claimed. |
| GAME-03 | Existing offline task boards, estimates, deadlines, owners/dependencies and resource links. Existing workflow suite is rerun. |
| GAME-04 | Unfinished: authenticated server-enforced membership/roles, revocation-safe previews/search, shared Canvas/calendar and contextual team review. Google account/sync and descriptive local Persons are not access control. |
| REV-01 | New research-record dialog covers all twelve specified categories as ordinary orbit.note Markdown; opt-in creation menus with disabling preserving content. Custom type/property definitions and extension isolation remain unfinished. |
| REV-02 | New validated 64-bit hex context records binaryId, binaryVersion, moduleId/name, addressSpace, VA/RVA/base. RVA derives only from supplied base; identity separates builds/binaries and survives rebase when context is complete. Legacy incomplete context has no unique address identity. No automatic retargeting, merging or address-only resolution. |
| REV-03 | Existing research Canvas presets and disassembly blocks; new folder action builds reference cards and evidence connectors on the same engine. Call/structure/module layouts are editable Markdown. Typed call edges, interactive memory-map tooling and address-link resolution remain unfinished. |
| REV-04 | New supporting/contradicting ID lists and readable links with confidence/status; existing attachment/PDF/image annotations retained. No automatic screenshot evidence capture or evidence-editing panel yet. |
| REV-05 | Reviewed, versioned manual JSON and robust CSV import, source/tool provenance and original metadata retained. Live Ghidra/IDA/Binary Ninja/x64dbg/WinDbg connectors remain unfinished; manual tool-labelled JSON is not a live integration. |

## Changes

- Research record creation: binary, module, function, address, structure, class,
  import, string, finding, hypothesis, patch, call graph. Empty templates clearly
  invite authored observations. Patch records describe bytes/rollback, never modify
  binary attachments. New function imports no longer invent disassembly or RVA.
- Evidence selectors link existing object IDs, reject dangling/contradictory input,
  and provide bounded searchable lists. Notes remain ordinary editable Markdown.
- Research maps deduplicate requested IDs, reference canonical objects, draw
  green/red evidence links and use existing Canvas placement semantics. Limits:
  1–500 records; only evidence whose endpoints are included is mapped; connectors
  are an editable snapshot of relations, not a live synchronized graph.
- Function imports validate all rows before writes, preview eight symbols plus
  total, preserve quoted/multiline CSV, distinguish RVA from VA, reject future
  envelope versions/non-text address fields and count only successful saves.
  Mid-batch storage failure retains saved records and disables retry in that dialog;
  this is not transactional rollback. Original row/context metadata survives.
- Function table admits Function categories only, searches build/RVA context and
  copies module+RVA only when an actual relative offset and module name exist.
  Missing locations show `Not recorded`; missing modules show an empty-state dash.
  Copy actions cannot invent address 0 or a module name. Action columns now have
  room for all three accessible icon buttons without horizontal overflow.
- Settings opt-in is device-only. Disabling hides creation presets while retaining
  existing research notes/views/maps and all unknown metadata.
- Playtest task/source links are stable IDs; backlink source is flushed using the
  normal history/save contract. A source-save failure still leaves the task's
  sourceNoteId and normal failed-save state; no silent rollback claim.

## Validation

- `dart format lib test`: completed; strict follow-up checked 362 files with zero
  changes. `flutter analyze --no-pub`: no issues (12.5s).
- Focused research/game/settings run: **65 passed**, including 17 new regressions
  (`.local/research-final-focused.log`).
- Final complete suite: **1,183 passed**, 1m38s
  (`.local/research-final-full.log`). Earlier complete run passed 1,182 before
  adding the table regression.
- Normal Windows release rebuilt successfully after final table repairs (55.0s,
  `.local/research-final-windows-build.log`); earlier build also succeeded (56.1s).
  Artifact: `build/windows/x64/runner/Release/orbit_note.exe`, not launched.
- Headless dialog test exposed controller disposal before exit animation completed;
  record/import dialogs now wait for route removal and prevent dismissal during
  writes. All checks reran after repair.
- Initial full run: 1,181 passed, one settings button hit-test failure. Added toggle
  shifted the button below the viewport; test now pumps scroll layout before tap.
  A trial pumpAndSettle timed out on deliberate pulse animation; a single frame
  waits for layout while preserving animation. Final full suite passes.
- Final table widget test caught an existing 24px action-row overflow; widened
  action/header columns from 120 to 144px. Missing addresses/modules no longer
  invent display/copy locations; non-function address records stay out of the
  function table. The regression now passes at a desktop viewport.
- Scoped diff check clean outside three pre-existing trailing spaces in unrelated
  `workspace_views.dart` Markdown template lines; those authored templates were
  preserved. CRLF normalization notices are not check failures.

New tests exercise precise/rebased address identity, quoted imports, validation
before mutation, write failures, unknown metadata, refresh from canonical files,
all record categories, evidence ID links, Canvas reference/deletion semantics,
settings compatibility and headless dialog creation/validation.
No desktop automation/native review window; no hardware crash/power-loss or
live provider/tool acceptance claimed. Persistence checks reload canonical files
through the repository using the failure-injectable memory store.

## Next task

Editable evidence/address inspectors on existing records, followed by the common
type/relation registry; do not treat an ordinary category selector as that registry.
Team/live connector work requires concrete provider/protocol implementation and
authorization boundaries; none is hidden behind a mock interface in this pass.
