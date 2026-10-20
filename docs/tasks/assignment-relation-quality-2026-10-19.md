# Assignment and reference workflow quality

Status: validated, 2026-10-19. Scope: existing ORG-03/05/08/11 tag,
project assignment and deliberate relation workflows.

Plan: reproduce stale picker selections, wrong-document tag assignment,
unlinked-mention edits and pending save ownership. Reuse guarded metadata edits,
live reference pickers and normal local save/recovery boundaries. Preserve unknown
properties, portable content and old workspaces. Add isolated headless regression
and large-list checks; run formatting, analysis, full suite and configured release
builds. No desktop control, personal Vault changes, dependencies, schema changes,
publishing or shutdown. Report evidence and one next task, then stop.

## Implemented

- Three isolated reproductions failed before the fixes: stale repeated mention
  linked the wrong occurrence, a trashed target received a reference, and a
  whitespace/hash/case variant created a duplicate tag. Trash tag protection was
  already effective through the underlying edit boundary; retained explicitly.
- Tag commands preserve unknown list entries/future formats. The tag route owns
  its text controller, guards duplicate submit and captures document/generation
  before awaiting input; switching tabs cannot redirect the tag.
- Project metadata writes patch only intended fields, check field presence and
  deep equality, and verify owner/generation plus durable save before success or
  project Undo. Assignment optionally verifies its reviewed membership snapshot.
- Project/reference choices update live; source/target/assignment workflows reuse
  the reference picker. Current type/project/deletion and Vault generation are
  checked at selection. Enter never substitutes a disappearing choice, duplicate
  selection is guarded, and unused row keys are released as filtering changes.
- Shared route-owned connection editor retains conflicting drafts and offers a
  guarded retry after write failure. Retry preserves newer unrelated metadata
  and cannot replace a newer relation list or append the same connection again.
- Unlinked mentions verify the reviewed body and target; their UI prevents
  duplicate linking and reports save/conflict failure accurately. Project panel
  feedback/drafts reset with project/Vault ownership, and pending assignment
  cannot act on a newly selected project.

## Validation

19 new regressions: 9 controller, 9 widget, 1 native. Focused matrix including
existing project, backlinks and tag checks: **65 passed**, 4 s. New coverage
includes 5,000 synthetic objects, alias search beyond the first page, current
membership checks, source tab changes, failed-save retry without duplicate edges,
newer relation-list rejection and 360px/200% text. Native temporary Vault verifies
exact CRLF source, identities, unknown metadata, tags, assignment, precise
connections and Undo across reopen. It never initializes a personal/default Vault.

Initial analyzer reported eight brace-style infos; corrected. Final formatting
and strict formatting check: **681 files**, clean. `flutter analyze --no-pub`:
**no issues**, 5.7 s. Full `flutter test --no-pub --concurrency=6 --reporter
expanded`: **2,576 passed**, **2 existing skips**, **4 min 13 s**. The existing
Windows symlink-permission boundary and manual Google account consent/upload
acceptance remain skipped, not passing acceptance. The native Python IDE cases
ran with the configured interpreter.
No claim of manual native desktop or real-account acceptance.

The first full-suite launch omitted the configured native Python environment and
started skipping IDE acceptance cases. It was stopped, its log retained as
`assignment-relation-full-test-missing-python-aborted.log`, and restarted with
`ORBIT_IDE_TEST_PYTHON` pointing to the installed bundled interpreter. The aborted
run is not reported as passing validation.

## Releases and remaining limits

Configured Windows release built in **76.2 s**, with the registered Google
desktop client. Standalone server compiled without starting it or packaging
server keys. Standard JavaScript web release built in **72.7 s**. Existing Google
Identity WebAssembly dry-run incompatibility and missing Cupertino font-family
warnings remain; no Wasm or Android acceptance claim is made.

Ignored evidence: `.local/assignment-relation-{windows,web}-build.log` and
`.local/assignment-relation-release-verification.json`. Verification at
2026-10-19 21:55:55 +02:00 confirms required EXE/DLLs, ICU, server/launcher and
four terminal font faces/hash matches. Both compiled payloads are newer than
source inputs and differ from the previous release. No app/test/server process
remains running. Runnable app: `build/windows/x64/runner/Release/orbit_note.exe`;
keep its runtime siblings. No ZIP, publishing, desktop control or personal Vault
mutation was used.

| Payload | Bytes | SHA-256 |
| --- | ---: | --- |
| Windows `data/app.so` | 24,609,680 | `3548EE09DED70F41631234A1269BE8D872FA6AB0DCFCE1AD075808671C2F968C` |
| Web `main.dart.js` | 10,522,404 | `1A8E214B76F69426BEEF8FE52871115233E65F0718E3856E88B7F20B9738015E` |

Next suggested task: split-pane tab switching and keyboard focus restoration
after dialogs, especially with several long documents. Stop before implementing it.
