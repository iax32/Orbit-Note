# Bulk lifecycle quality

Status: validated, 2026-10-19. Continue the authorized hard-use audit.
Scope: ORG-01/05/07 and HIST-01/03/09 existing bulk move/duplicate, Trash,
restore, permanent cleanup and guarded planning Undo. Preserve all unrelated work.

Plan: reproduce mutable selections, queued commands after Vault reopen, partial
cleanup failure and retained confirmation handlers. Fix only demonstrated
boundaries, using existing commands/journals and ordinary files. Add isolated
memory/native regression and recovery fixtures; run format, strict format,
analysis and full tests, then configured Windows/server and standard web builds.
No personal Vault mutations, desktop control, dependencies, schema changes,
publication or shutdown. Record actual evidence and one next task, then stop.

## Changes

- Folder/lifecycle repository commands capture Vault identity and opening
  generation before joining the serial queue. Reopening retires old intent,
  including reopening the same Vault. Bulk moves freeze/deduplicate the caller's
  selection before waiting. Existing native journal/preflight remains authoritative.
- Batch duplication freezes/deduplicates IDs, skips trashed/read-only owners,
  stops on a failed copy or retired context and retains successful copies.
- Permanent cleanup stops after failed draft saves/conflicts. Empty Trash captures
  its intended identities, excludes newly trashed items and flushes pending work.
  Partial success reconciles actual durable removals and purges only those IDs from
  navigation/bookmarks; remaining objects and failure feedback stay visible.
- Explorer confirmation/move/copy actions capture original selection and Vault.
  Trash checks expected objects, counts actual successes and retains failed
  selections. New selections survive completion; disposed/retired panels cannot
  continue a batch. Workspace ownership changes clear stale selection state.
- Shell Trash/restore/delete actions validate their reviewed object; permanent
  cleanup confirmations cannot target another Vault or a changed Trash inventory.
  Folder delete/move confirmation callbacks also reject a retired panel/Vault.
- Planning Undo already rejects later edits and retains its operation after a
  storage failure. Regression coverage verifies this boundary without replacing
  existing Undo with a new history mechanism.

## Validation and limits

Initial reproduction: 8 actual failures plus one invalid fixture that attempted
normal editing of a trashed note. Corrected draft-save fixture uses an active
note; it verifies preservation on failed flush. Initial ten regressions then
passed. A native stress fixture exceeded the default 30-second test timeout;
its explicit budget is now three minutes. Widget full-controller reinitialize
stalled in the fake-clock fixture; the replacement uses two actual isolated
in-memory repository Vaults, testing pending-dialog ownership without claiming
full native controller switching acceptance. Initial attempts are not passing
acceptance evidence. A transient mapped-file lock blocked one formatter write;
the targeted formatting retry succeeded.

New coverage includes 120 native mixed owners, repeated moves/Trash/restore and
reopen, queued retirement for seven command variants, mutable/deduplicated
selections, cleanup partial failure/recovery, failed draft saves, guarded Undo,
and pending Explorer confirmations. These are bounded correctness/recovery
fixtures, not frame-rate or throughput benchmarks.

Formatting/strict formatting check **673 files**, clean. Final analysis with
`flutter analyze --no-pub`: **no issues**, 7.3 s. The default analyze invocation
spent time in dependency resolution; it was interrupted and rerun against the
already resolved package set. The first actual analysis found seven lint infos
in the new code; those were corrected before the clean final analysis.

The 15 lifecycle regressions passed, including the native stress case (1 min
41 s); that command's overall exit was failure because the companion widget file
had a misplaced import, now fixed. A separate final boundary matrix passes
**45 tests** in 3 s, including all four corrected widget scenarios. Final full
suite: `flutter test --no-pub --concurrency=6 --reporter expanded`, **2,540 passed**,
**2 existing skips**, **4 min 54 s**. This includes all **19 new regressions**.
The skips are the existing native Windows symlink-permission boundary and manual
real Google-account consent/upload acceptance. They are not passing acceptance.
Logs: ignored `.local/bulk-lifecycle-{format,format-check,analyze-final,tests}.log`
and `.local/bulk-lifecycle-final-boundaries.log`.

Configured Windows release built successfully in **88.0 s**, retaining the
registered Google desktop client. Standalone server compiled without starting
it or packaging server keys. The first concurrent web startup failed with
`Could not determine engine revision` before compiling; a serial retry after
Windows completed succeeded in **91.4 s**, using the same SDK/resolved packages.
The standard JavaScript build retains existing Google Identity Wasm dry-run and
missing Cupertino font-family warnings. No WebAssembly claim is made.

Ignored evidence: `.local/bulk-lifecycle-windows-build.log`,
`.local/bulk-lifecycle-web-build{,-retry}.log` and
`.local/bulk-lifecycle-release-verification.json`. Runtime EXE/DLLs, ICU, compiled
Dart payload, server/launcher, and all four terminal font faces/hashes verified.
Both payloads are newer than their inputs and differ from the previous build;
no app/test/server process remains running. Runnable Windows app:
`build/windows/x64/runner/Release/orbit_note.exe`; retain its runtime siblings.

| Payload | Bytes | SHA-256 |
| --- | ---: | --- |
| Windows `data/app.so` | 24,609,680 | `7F899F04FC8B941A5A8A4E5FE5CB874D5E34364D4A756F28A2FC9DF7752E76A4` |
| Web `main.dart.js` | 10,518,540 | `1306800F296A2ED85F807C5C37A1C3860D1C04FF0AB47DAB829E3ABDDCF37CC1` |

All fixture data is synthetic, in memory or isolated temporary directories.
No desktop-control, physical-device, real-account, Android or native full-controller
switch acceptance is claimed. No personal Vault data, unknown properties, formats,
dependencies or unrelated changes were removed. Existing deletion/folder recovery
journals still govern interrupted durable commands; grouped atomic cleanup and
durable grouped Undo remain outside this batch. Passing automated checks do not
establish that every hard-use bug is gone.

Two synthetic temp directories from interrupted native runs remain in the OS
temporary folder (`orbit-bulk-stress-41163973`, `orbit-bulk-stress-90b40a6d`).
Automatic approval review rejected their cleanup; no deletion was performed.
Completed native fixtures clean up through their normal test teardown.

## Suggested next task

Audit Explorer rename/property/color dialogs under concurrent edits and retained
callbacks, including external refresh and narrow/large-text recovery paths.
Stop here; that follow-up is not implemented by this batch.
