# Large-project collection quality

Status: validated, 2026-10-18. Owner requests hidden issues that become apparent in large
or specialized projects. Scope: existing VIEW-01/02/03/05/06 collection tables,
timeline membership, progress and related desktop interactions. No new feature
layer, dependency, migration or change to legacy folder-versus-scope precedence.

Plan: reproduce stale table-property saves, delayed dialog/creation ownership,
manual collection cross-view disagreement, imported-value failures and narrow
large-text layouts. Reuse canonical queries and validated object/folder commands;
index membership once, keep rows lazy, preserve unknown properties and protect
newer edits. Verify large fixtures, failures, source changes, read-only states and
save/reopen behavior; format/analyze/full tests and configured releases. No
desktop-control testing, personal Vault changes or shutdown.

## Changes

- Table sorting previously wrote column/direction independently from a retained
  definition, losing one field or newer properties. Saves now merge latest data
  atomically; unknown column entries are retained alongside supported columns.
- Tag edits merge current tags/properties; competing rename/folder edits keep the
  unapplied form draft and explain the conflict. Forms own their text controllers
  through route disposal, rather than disposing during the exit animation.
- Popup states are tied to their owning definition and row snapshot. Flutter can
  reuse a popup's latest callback after its route closes; changing the owner now
  invalidates the old popup. Dialog actions also check controller, collection,
  workspace generation and read-only/deletion state.
- Delayed Add Item keeps its original collection context and merges current
  membership. A view switch cannot add the new object to an unrelated collection.
  An unavailable original collection leaves the created object intact with notice.
- Folder editing uses the validated durable move command, including flush/error
  handling. A failed move retains its draft and original source path.
- Table, timeline and progress use the canonical query. Manual collections no
  longer include unrelated deadlines/completed tasks; explicitly empty manual
  lists stay empty. Malformed scope/membership/presentation settings show an
  explanatory state without rewriting their definitions.
- Membership uses one Set lookup per object rather than repeatedly searching a
  List. Scoped query caches have distinct keys, refresh with canonical object
  changes and do not contaminate shared-view results. Table view lookup is cached
  per controller/object snapshot instead of rescanning the Vault for each cell.
- Rows remain lazy. Horizontal table navigation accommodates enlarged text;
  long paths/tags and creation menu labels are bounded. Timeline cards now supply
  their Material ancestor, repairing an assertion exposed by the new fixture.

## Validation

`test/collection_quality_test.dart` covers atomic sorts, concurrent tags/renames,
manual progress/timeline agreement, empty/malformed membership, unsupported view
settings, imported column/status values, read-only definitions, stale popups,
delayed creation, trashed sources, narrow 200% text, lazy search, invalid folder
moves and native file move/reopen with body/unknown metadata intact.

The 10,000-object/5,002-membership fixture resolves 5,000 unique real objects;
missing/duplicate IDs do not fabricate copies. Observed headless debug query time
was 3 ms in the focused run; this is a local observation, not a device performance
guarantee. The 160-record widget fixture mounts fewer than 80 rows, then locates
the last record through search. A rendered 390×844 / 200% text fixture was inspected
at `work/ui/collection-large-text.png`; the table remains horizontally navigable.
All storage fixtures use memory or isolated temporary roots, never personal Vaults.

Focused collection/productivity checks: **54 passed**, including **20 new
regressions** in the collection-quality file. Strict formatting checks all **668
files** without changes; `flutter analyze --no-pub` reports **no issues** (10.3s).
The captured narrow-table test passed separately. Logs:
`.local/collection-quality-{format,format-check,analyze,final-focused,capture}.log`.
Scoped `git diff --check` passes, with existing CRLF normalization notices only.

Full suite: `flutter test --no-pub --concurrency=6 --reporter expanded` passes
**2,485 tests**, with **2 existing skips**, in 4m49s. Skips remain native Windows
symlink permission and manual real-Google-account consent/synthetic-upload
acceptance. `.local/collection-quality-tests.log` records the run. The IDE fixture
uses the existing bundled Python runtime; no system packages were installed.

## Releases and boundaries

- Configured Windows release: **passed**, 105.8s. Existing Google desktop
  registration retained. Standalone collaboration server rebuilt without starting
  a server or packaging keys. `.local/collection-quality-windows-build.log`.
- Standard JavaScript web release: **passed**, 96.3s. Existing Google Identity
  Wasm dry-run incompatibility and missing Cupertino font-family warnings remain;
  this is not a Wasm release. `.local/collection-quality-web-build.log`.
- Runtime files verified: EXE, Flutter/PDFium/SQLite DLLs, ICU/Dart/assets and
  standalone server/launcher. Both payloads are newer than Dart/manifest/writing
  inputs and differ from the prior build. Windows and web each retain all four
  OrbitTerminal faces, with packaged font hashes matching source assets.
  `.local/collection-quality-release-verification.json` records SHA-256:
  Windows `data/app.so`, 24,560,528 bytes,
  `D31A82AB5F80FDA60FD1BA5078B67C8FECC02DE00D9C940A2B49CFDE3B10BE19`;
  web `main.dart.js`, 10,508,435 bytes,
  `E9DDB751DC57C7D39D3B1C5FEF1A037F28F7ADF87057892E9636BC731E1A83CA`.
- No app, test or standalone-server process remains running. Runnable Windows
  release: `build/windows/x64/runner/Release/orbit_note.exe`, with adjacent files.

Platform pointer/touch and physical-device acceptance remain outside this headless
audit. No desktop-control testing, personal Vault changes or shutdown occurred.
No claim that all application bugs are eliminated.

Suggested next task: Kanban cross-view edits and large-project board interactions.
Stop here; do not begin the next batch without approval.
