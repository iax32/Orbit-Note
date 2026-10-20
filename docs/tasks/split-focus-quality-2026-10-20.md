# Split-pane navigation and focus quality

Status: validated, 2026-10-20. Scope: NAV-03/04/08/10 existing tab shortcuts, pane
ownership and focus restoration after modal dialogs.

Plan: reproduce hidden/read-only pane shortcut targeting and stale tab cycling;
check dialog focus and independent long-document positions with synthetic
headless fixtures. Fix the smallest existing boundaries, preserve identity and
portable data, then run formatting, analysis, focused/full tests and configured
Windows plus standard web builds. No desktop control, personal Vaults, new
dependencies, publishing or shutdown. Report evidence and one follow-up, then stop.

## Changes and reproduction

- Hidden split close/cycle shortcuts used the saved secondary ID even after
  responsive layout hid that pane. Commands now require a rendered split and
  reset hidden pane ownership. Read-only panes also participate in focus/pointer
  ownership; existing mutation protection remains in place.
- Tab cycling filters live candidates, deduplicates IDs and avoids the unsupported
  same-object split for non-note types. It does not delete stale stored data.
- Pane-local focus scopes retain modal return ownership. Explicit activation,
  cycling and split closing request typing focus in Source/Rich/LaTeX while
  preserving selection. Deferred requests are serial-, view-, route- and
  Vault-generation guarded; ordinary rebuilds do not activate them.
- Independent source selections/scroll positions, duplicate note views and
  modal cancellation are covered by regression checks. A 400-paragraph fixture
  switches its other tab 16 times at 16 ms intervals without changing the retained
  view's backwards selection, scroll or source.

The initial fixture used the displayed Source label as its internal mode name;
the existing enum uses `write`, so it was corrected. The read-only editor renders
Read mode and therefore has no editable body field: its fixture now clicks the
actual read-only surface rather than accidentally clicking the primary editor.
The stale cycling and hidden-pane failures were reproduced before their fixes;
the corrected read-only target is covered after the fix. Fixture failures are
not passing acceptance evidence.

## Validation

Final focused matrix: **40 passed**, 25 s (18 new widget regressions plus existing
navigation/bookmark checks). Formatting and strict formatting check: **682 files**,
clean. Final `flutter analyze --no-pub`: **no issues**, 6.4 s.
Configured release checks are recorded below. No desktop control, personal Vault mutation
or cloud-account acceptance is claimed.

The added LaTeX activation check exposed a raw/preamble-block focus gap: index 0
need not have a visible editor field. Restoration now uses the active available
field, or the first rendered prose focus node, without changing source or
selection. The focused LaTeX recheck passed. The final matrix also includes a
pending tab activation followed immediately by a modal; the modal retains focus.

Review narrowed the Canvas duplicate-view filter to secondary cycling: primary
cycling must still activate a Canvas retained in the other slot, including when
that split is hidden. A further regression covers this. The initial full run was
stopped before completion to make that adjustment, with its log retained as
`split-focus-full-before-primary-canvas-adjustment.log`; it is not passing full
validation evidence. Final checks were restarted after the change.

Final focused matrix after the Canvas adjustment: **40 passed**, 25 s, including
**18 new widget regressions**. Full `flutter test --no-pub --concurrency=6
--reporter expanded`: **2,594 passed**, **2 existing skips**, **4 min 31 s**.
The existing Windows symlink-permission boundary and manual Google consent/upload
check remain skipped, not passing acceptance. Native Python IDE checks used the
configured bundled interpreter. `git diff --check` on touched tracked production
files reported no whitespace errors (existing CRLF normalization notices only).

## Releases and remaining limits

Configured Windows release built in **79.0 s**, preserving the registered Google
desktop client. Standalone server compiled without starting it or packaging
server keys. Standard JavaScript web release built in **74.5 s**. Existing Google
Identity WebAssembly dry-run incompatibility and missing Cupertino font-family
warnings remain; no Wasm or Android acceptance claim is made.

Ignored evidence: `.local/split-focus-{windows,web}-build.log` and
`.local/split-focus-release-verification.json`. Verification at
2026-10-20 16:08:57 +02:00 confirms required EXE/DLLs, ICU, server/launcher and
four terminal font faces/hash matches. Both compiled payloads are newer than
source inputs and differ from the previous release. No app/test/server process
remains running. Runnable app: `build/windows/x64/runner/Release/orbit_note.exe`;
keep its runtime siblings. No ZIP, publishing, desktop control or personal Vault
mutation was used.

| Payload | Bytes | SHA-256 |
| --- | ---: | --- |
| Windows `data/app.so` | 24,609,680 | `809F99E38BB5622BAB82C446FA71EF8FBA528D8716B303A8635B3C776670B235` |
| Web `main.dart.js` | 10,523,866 | `7A5F454D93DD11468E09BFB9FFA8B1C2B537F2DBF2974B90C91D2DD05313D289` |

Next suggested task: find/replace and undo/redo ownership while switching split
panes. Stop before implementing it.
