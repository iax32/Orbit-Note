# Metadata dialog quality

Status: validated, 2026-10-19. Scope: ORG-01/03/05/07 and DES-08 existing
Explorer/shell renaming, property editing and folder/object color dialogs.

Plan: reproduce stale-field overwrites and retained callbacks; use current
controller/repository edit boundaries to compare touched fields and preserve
unrelated content. Validate color input and compact/enlarged-text layouts.
Add isolated headless regressions, persistence/reopen checks, formatting,
analysis/full suite and configured Windows/server plus standard web builds.
Preserve unrelated work, unknown metadata and old workspaces. No schema change,
new dependency, personal Vault mutation, desktop control or shutdown. Stop after
this batch and one next suggested task.

## Changes

- Added a synchronous controller metadata command that compares only touched
  fields (including absent versus null and explicitly watched legacy keys),
  rejects retired Vault generations/deleted/read-only owners and preserves newer
  body/title/data/other properties. Normal edit/autosave/conflict recovery still
  owns durability. No schema/dependency/architecture change.
- Explorer and shell share a route-owned rename editor, with Enter submission,
  duplicate-submit protection, validation and retained input on stale-title
  conflicts. The old fixed-delay controller disposal is no longer needed there.
- Inspector property edits, removes, tag edits and date selections use guarded
  patches. Conflicts retain dialog input and show feedback; disposed/retired
  callbacks cannot mutate content. New keys cannot overwrite concurrent additions
  or create managed internal properties. Number forms reject NaN/infinities.
- Object color/reset applies only the styling keys, compares legacy accent state
  and retains the selected draft on conflict. Folder color dialogs check explicit
  color, owner/panel and target existence. Retained folder menus reject retired
  Vaults; folder rename rejects changed member/descendant paths before moving.
- Custom hex input accepts only an optional leading # and six hex digits; invalid
  input disables Apply. Preview row heights respect enlarged text. Cancel/reset
  remain available; the existing optional color-selected callback remains usable.

## Validation and limits

17 new regressions (12 widget, 5 controller/native) plus existing note/color
checks: final focused matrix **47 passed**, 9 s. Includes 360px/200% text with
140px simulated keyboard inset, stale/add-key conflicts, retired callbacks,
same-Vault generation retirement, missing/null comparison, failed-save retry,
legacy styling conflicts and native save/reopen with exact source/identity.

The initial test helper used a void menu callback as a Future, then awaited a
fake-clock flush during teardown; those fixture errors were corrected. Initial
color reproduction showed a real overwrite of newer nested metadata. Later
focused assertions passed but cleanup timers needed cancelling before widget
invariant checks. The native expectation was corrected to retain the existing
rename alias behavior (`Before` is kept as an alias), not remove it. A transient
mapped-file lock blocked an initial formatter write; targeted retry succeeded.
Failed/stalled fixture attempts are not reported as passing acceptance checks.

Formatting and strict format check: **676 files**, clean. Final
`flutter analyze --no-pub`: **no issues**, 7.6 s. Initial analysis found eight
brace-style lint infos in the new handlers; corrected before this clean run.
Full `flutter test --no-pub --concurrency=6 --reporter expanded`: **2,557 passed**,
**2 existing skips**, **5 min 7 s**. Skips are the existing Windows symlink-permission
boundary and manual real-account Google consent/upload acceptance. Those are not
reported as passing acceptance.

Configured Windows release built successfully (**81.3 s**) with the registered
Google desktop client. Standalone server compiled without starting it or packaging
server keys. Standard JavaScript web release built successfully (**95.2 s**);
existing Google Identity Wasm dry-run and missing Cupertino font-family warnings
remain. No WebAssembly or Android acceptance claim is made.

Ignored evidence: `.local/metadata-dialog-{windows,web}-build.log` and
`.local/metadata-dialog-release-verification.json`. Runtime EXE/DLLs, ICU, compiled
Dart payload, server/launcher, and four terminal font faces/hashes verified. Both
payloads are newer than inputs and differ from the previous build. No
app/test/server process remains running. Runnable Windows app:
`build/windows/x64/runner/Release/orbit_note.exe`; keep its runtime siblings.

| Payload | Bytes | SHA-256 |
| --- | ---: | --- |
| Windows `data/app.so` | 24,609,680 | `4A3E382C2D548EBB80F343C9DAE11E554988ACB3FB9F9D6BEF76197183D78790` |
| Web `main.dart.js` | 10,521,337 | `201D79BD1183846F93ADA8587182B1837557D652D0EF1AB05615DF9F730670C2` |

After the full run, the native fixture's bootstrap adapter was tightened to always
use its generated temporary root, including default initialization. Production
code did not change. Formatting/analysis and the five controller/native tests are
clean after this fixture-only change; the five controller/native tests passed
again (0 s reported). The full suite covers the final production implementation.
Evidence uses ignored `.local/metadata-dialog-*.log`.
All fixtures use synthetic memory/temp sources; no desktop control or personal
Vault data. Physical-device/real-account/native OS UI acceptance is not claimed.
Existing autosave/history limits remain; passing these checks does not establish
that every hard-use bug is gone. Unrelated changes and unknown data are preserved.

## Suggested next task

Audit bulk tag/project assignments and retained relation pickers under concurrent
metadata changes, including large selections and failed saves. Stop before
implementing that follow-up.
