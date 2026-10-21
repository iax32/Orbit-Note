# Canvas shared presence and structured split editors

Status: validated, 2026-10-20. Scope: SYNC-03/04/05/09/10 existing session
reliability and selected-placement awareness; EDT-04/07 and NAV-03/04 structured
focus, selection, Find/Replace and history ownership across split panes.

## Plan

1. Reproduce table/code focus restoration and stale selection/clipboard behavior
   with independent notes and duplicate-note panes. Verify input-local versus
   document undo, selection-scoped replacement and exact source restoration.
2. Exercise concurrent Canvas placement changes, order/delete boundaries and
   lost acknowledgements with isolated clients/server. Preserve ambiguous edits.
3. Add optional, bounded selected-placement presence and clear-on-leave. Server
   validates grant/session ownership and selection identity. Older presence
   payloads remain supported; no durable data or protocol-version migration.
4. Run format/strict formatting, analysis, focused and full tests, then configured
   Windows/server and standard web builds if available. Record actual evidence
   and limits; suggest one next task and stop.

No personal data, desktop control, external accounts, publishing, shutdown,
dependencies, CRDT guarantees or live new-object/attachment protocol changes.

## Implementation and reproduction

- Reproduced loss of table/code typing focus after primary activation. Restoring
  an active structured field now retains the exact backwards selection. Table
  external updates retain both endpoints and rectangular-anchor direction.
- Reproduced delayed code paste and rectangle grid paste applying after focus
  moved to another pane. Code keyboard/context-menu cut/paste now validates field
  revision, owner focus epoch, document epoch, selection/value and writability;
  grid paste checks original focus/epoch as well. Literal code remains in normal
  shared undo/fence growth handling.
- Expanded Find tests exposed the queued result-focus callback stealing focus
  from the replacement field: `VALUE` replaced the query and produced zero matches.
  Rich navigation now selects/scrolls without requesting input focus. It records
  structured selection after fields update, preserving exact previous/next
  traversal. Same-note split conflicts retain independent drafts during Undo.
- Reproduced false Canvas order conflicts when two agreeing reorders deleted
  different placements. Compare surviving common IDs, retaining real conflicts.
  One-sided duplicate placement IDs previously bypassed merge checks; all Canvas
  merge inputs now validate identities. Order membership checks use sets. A
  3,000-placement fixture preserves canonical identity and opaque scene/item data.
- Added bounded selected-placement presence, server-side grant/session checks,
  cache invalidation by snapshot identity, hidden/missing/offscreen filtering,
  world-camera outlines and Unicode-safe names. Membership cache holds at most
  128 entries; payload limit is 16 KiB with at most 64 selected IDs, avoiding a
  2-KiB rejection for 64 ordinary UUIDs. Metadata is ephemeral, not saved in scenes.
- A separate presence notifier/overlay retains the main Canvas painter and
  gesture/editor state. Heartbeat-only `seen` updates do not repaint. Leave events
  queue a bounded own-session clear; disconnected clients retain normal expiry.
- Reproduced switching rooms causing a grant-bound session collision and access
  denial. Each successful connection now creates a new ephemeral session ID and
  resets cursor timing. Object/workspace identities and document history do not
  change. Two actual local application sessions exercise lost edit acknowledgement,
  later independent edits and exact convergence without a duplicate server edit.

Initial fixtures corrected an offscreen code tap and the HTTP test override being
reset after a transport was constructed. A painter-retention test initially used
an incorrect type name; it was corrected to OrbitCanvasPainter. These failed
fixture attempts are not passing acceptance evidence. The first Find selection
recording attempt also failed existing traversal checks; recording the actual
structured range after navigation corrected that regression.

## Validation

Added **27 regressions** in four files: structured split editing (11), shared
Canvas sessions/permissions/replay (7), presence overlay/integration (5), and
merge identity/order/large-board checks (4). Existing fixture parameters retain
their original defaults for prior split-pane tests.

Final focused matrix: **201 passed**, 42 s. Formatting/strict formatting: **693
files**, clean. Analysis: **no issues**, 7.3 s. Full
`flutter test --no-pub --concurrency=6 --reporter expanded`: **2,655 passed**,
**2 existing skips**, **5 min 26 s**. Windows symlink-permission and manual Google
consent/upload remain skipped, not accepted. Native Python IDE checks used the
configured bundled interpreter. Tracked diff whitespace check found no errors
(existing CRLF normalization notices only). Configured Windows/server and standard
JavaScript web build/verification passed as recorded below.

Ignored evidence: `.local/canvas-split-{reproduction,clipboard-reproduction,
room-reproduction,final-focused,full-test,format,format-check,analyze}.log`.

## Local builds and verification

Configured Windows release built in **100.3 s**, retaining the registered Google
desktop client. Standalone server compiled without starting it or packaging
keys. Standard JavaScript web release built in **108.1 s**. Existing Google SDK
Wasm dry-run incompatibility and missing Cupertino font-family warnings remain;
no Wasm or Android acceptance/build claim is made for this task.

Verification at **2026-10-20 21:56:03 +02:00** confirms required EXE/DLLs, ICU,
server/launcher, four terminal font faces with matching source hashes, compiled
payloads newer than source and different from the preceding build. The server
is separately verified newer than its changed inputs. No app/test/server process
remains running. Ignored evidence: `.local/canvas-split-{windows,web}-build.log`,
`.local/canvas-split-release-verification.json` and
`.local/canvas-split-server-verification.json`.

| Payload | Bytes | SHA-256 |
| --- | ---: | --- |
| Windows `data/app.so` | 24,658,832 | `9404BE2EEE8DE97EE376C84464BE8B3E64C4B63DCB9687D1E98B995726E30083` |
| Web `main.dart.js` | 10,536,291 | `CC33EEACE340BC370718187969BCCB14A64E0D733343E539AB65D534A89114AA` |
| `OrbitNote-Server.exe` | 7,595,008 | `A54B9CB756CF39EA32B6189993E88B9E08363B6D5D8C581F8263A921887EFF5F` |

Run `build/windows/x64/runner/Release/orbit_note.exe` with its runtime siblings.
The rebuilt `collaboration/Start Orbit Server.cmd` launcher uses the normal
private server directory; update/restart a self-hosted deployment separately.
GitHub source/releases and the previously published APK were not changed by this
local feature task.

## Limits and next task

Update both app and self-hosted server for selected-item presence and immediate
clear-on-leave. Older protocol-1 payloads remain supported; old servers may show
only pointers and retain a departed pointer until expiry. Awareness does not lock
placements, grant access or acknowledge edits. No native desktop-control or
physical-device/TLS deployment acceptance was performed; no personal Vaults or
external accounts were used. No publication or shutdown is part of this task.

Next suggested task: review/resolution UI for overlapping shared Canvas edits,
including side-by-side placement differences. Stop before implementing it.
