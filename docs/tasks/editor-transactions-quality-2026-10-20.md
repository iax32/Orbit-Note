# Editor transaction and split-pane reliability

Status: validated, 2026-10-20. Scope: existing Markdown/Rich/Source Find/Replace, undo/redo,
clipboard ownership and local draft/save recovery. This is a broader reliability
batch under EDT-02/04/06/07/10 and HIST-01/03; no new storage format or dependency.

Plan: reproduce wrong-input undo, stale history replay, reused-editor history,
read-only replacements and split-pane draft hazards. Fix shared boundaries and
retain recoverable edits. Exercise mixed markup, Unicode/CRLF, long notes and
failed/interleaved saves with isolated headless tests. Run format/strict check,
analysis, focused/full tests and configured Windows/standard web release builds.
Preserve unrelated work, unknown data and ordinary originals. No desktop control,
personal Vault changes, external account acceptance, publishing or shutdown.
Report evidence and one suggested next task; stop before implementing it.

## Changes and reproductions

- Find/Replace text fields previously sent Ctrl+Z to document history. Native
  input undo and Windows-style Ctrl+Y now remain in the input; explicit document
  Undo/Redo controls preserve the existing Read-mode replacement workflow.
- Reused editors retire history when note/controller/Vault opening/format changes.
  Shared history checks the complete expected source, splice bounds and content
  before undo/redo. Stale chains are discarded without replacing another version
  or throwing on shortened content. Selection snapshots preserve both endpoints.
- Composition and document focus checks are pane-local. A second pane's IME
  composition cannot block the active pane's undo. Conflicting same-note drafts
  retain their independent history without overwriting the winning source.
- Delayed Source clipboard and writing-tool commands capture a monotonic revision.
  Edit-then-undo to identical text cannot revive an earlier operation. Retained
  read-only/view-only replacement and history callbacks reject mutation.
- Large replacement-review excerpts no longer split UTF-16 surrogate pairs.
  A 1,000-match fixture pages at most 30 previews and applies/undoes/redoes once;
  selected-scope expansion remains inside the original selection.
- Concurrent recovery requests for an identical retained note/Canvas draft share
  one future/copy. Newer versions and different panes remain distinct. Failure
  clears the pending slot for retry; old completion cannot clear a newer request.

Six initial editor reproductions failed before fixes, including wrong-input undo,
reused-note history, a retained read-only command, stale-source corruption and a
shortened-source RangeError. A separate duplicate-recovery reproduction also
failed before its fix. An expanded replacement test found the invalid UTF-16
preview render failure. Initial fixture casts were corrected to target IconButton
instead of RawTooltip; input undo fixtures wait for the initial native history
value before typing. Failed attempts are not passing validation evidence.

## Validation

Added **34 regressions** in six test files: editor transaction widgets (14),
shared history integrity (8), draft recovery/save boundaries (6), split panes (2),
delayed clipboard/review commands (3), and a native temporary Vault (1).

The native fixture performs six undo/redo/save/reopen rounds on 750 sections with
mixed markup, CRLF and emoji; 1,500 visible replacements preserve link targets,
identity and unknown metadata. Recovery fixtures also exercise 80 interleaved
edits/flushes behind a write gate, a failed final save, retry and reopen. Native
tests allocate only their own temporary Vaults and close storage before cleanup.

Initial focused matrix: **174 passed**, 14 s. The first complete suite found five
older code/table/callout Find/Replace expectations that sent Ctrl+Z to the
document while a search input owned focus. They now use explicit document
controls; keyboard history coverage for focused code/callout/table editing is
retained. The full log is preserved as
`.local/editor-transactions-full-before-input-expectations.log` (2,623 passed,
2 existing skips, 5 failures); it is not passing full validation evidence.
Final expanded focused matrix: **214 passed**, 22 s. Final formatting and strict
formatting check: **688 files**, clean. Final analysis: **no issues**, 6.4 s.
Fresh full `flutter test --no-pub --concurrency=6 --reporter expanded`:
**2,628 passed**, **2 existing skips**, **4 min 37 s**. The Windows symlink
permission boundary and manual real-account Google consent/upload check remain
skipped, not accepted. Python IDE checks used the configured bundled interpreter.
`git diff --check` on touched tracked files found no whitespace errors (existing
CRLF normalization notices only). Configured Windows and standard web releases
and artifact verification passed as recorded below.

Ignored evidence: `.local/editor-transactions-{reproduction,recovery-reproduction,
validation-focused,full-test,analyze,format,format-check}.log`.

## Releases

Configured Windows release built in **72.8 s**, retaining the registered Google
desktop client. Standalone server compiled without starting a process or
packaging server keys. Standard JavaScript web release built in **68.6 s**.
Existing Google Identity SDK WebAssembly dry-run incompatibility and missing
Cupertino font-family warnings remain; no Wasm or Android acceptance claim.

Ignored evidence: `.local/editor-transactions-{windows,web}-build.log` and
`.local/editor-transactions-release-verification.json`. Verification at
2026-10-20 **17:20:26 +02:00** confirms required EXE/DLLs, ICU, server/launcher,
four terminal font faces with matching source hashes, fresh compiled payloads
newer than source and different from the preceding release. No app/test/server
process remains running. Run `build/windows/x64/runner/Release/orbit_note.exe`
with its runtime siblings; no ZIP or publishing was performed.

| Payload | Bytes | SHA-256 |
| --- | ---: | --- |
| Windows `data/app.so` | 24,626,064 | `A5545DEEAB7EDF184A4494449BA1BFA383CD619BDCC9B9CB61455AB0C8AAD65C` |
| Web `main.dart.js` | 10,527,366 | `BE9686DB1EB6AD15D509702D167BD4B330B9741EEF299F98DADE3C2BFABE69F3` |

## Limits and next task

Headless synthetic tests only; no desktop control, personal Vault changes,
cloud-account acceptance, publishing or shutdown. These tests do not replace
native two-device/IME/OS clipboard acceptance. No zero-bug or complete-roadmap
claim is made.

Next suggested task: structured table/code-block selection and command ownership
across split panes. Stop before implementing it.
