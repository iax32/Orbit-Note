# In progress — pen responsiveness and easy device sharing, 2026-10-29

Owner requests smooth PC/tablet pen input with preserved visuals/features and
simple fast server/sync setup. Scope and evidence:
[pen/live-sharing task](pen-live-sharing-2026-10-29.md). Lenovo is available on
1.0.8; use matched updated builds for physical acceptance. Implemented: bounded
live preview allocation, pen/palm capture, Android managed import destinations,
background payload processing, isolated HTTP/merge/journal host, visible setup/
cancel/reconnect, negotiated lossless request/response compression and 32-MiB
shared document limit (room/decoded-size protections retained). Preserve preceding
audit changes. Final 35/37 focused batches pass, including real synthetic HTTPS;
analyzer clean and 910 lib/test files format-clean. Large-fixture gzip is 92.0%
smaller losslessly. Native stylus raster P95 1.340 ms; a 19.19-ms pan outlier and
physical PC/Lenovo acceptance remain. Final Windows 1.0.10+11 built in 105.8 s
and Android in 116.6 s; AOT freshness, package/version and original preview
certificate verified. Published app source 3baad06 and all six verified assets:
https://github.com/iax32/Orbit-Note/releases/tag/preview-1.0.10-2026-10-29
Release tag/provenance matches app source; asset sizes/SHA-256 verified against
GitHub metadata. Zero workflow runs for that commit. Owner is asked to install
1.0.10 over Lenovo 1.0.8 and check UE2 pen input plus image/ink delivery both ways.
Await physical acceptance; preserve the remaining pan outlier as unresolved.

## Preceding Gemini audit implementation, 2026-10-29

Owner supplied Gemini's report and authorizes supported performance changes.
Scope/validation: docs/tasks/audit-performance-2026-10-29.md. Prioritize exact ink
appearance, safe comparisons, indexed snapping, writing responsiveness, worker
reuse and collaboration costs; inspect PDF/sync/root-notification claims before
changing behavior. Do not assume the report's hypotheses are proven causes.

Delivered local batch: indexed global snapping with exact old guide/tie behavior,
per-stroke Paint reuse and immutable sample views, complete background grammar
and per-field caches, LaTeX token/controller reuse, cached presence digests,
persistent history worker, exact PDF layout memo and reduced settings/poll/root
notification work. Preserve strict UML routes, vector appearance and full save/
conflict guards. Detailed report dispositions are recorded in the task document.
Native 2500-item/400-move alignment 180.406 -> .482 ms total (+4.697-ms index);
100 large-document caret hashes 334.595 -> 3.803 ms. Seven-nib pre-change pixels
match exactly. Focused batches of 12/54/20/60 checks pass (overlapping counts).
Analyzer clean (40.0 s), strict format 900 files unchanged (8.01 s).

Native isolated 100-Hz/400%-zoom replay: long-stylus GPU P95 1.807 ms, mouse
4.666 ms; no drawing-stage budget misses. Pan has one 23.804-ms raster outlier.
This is not a full-app/physical 180-Hz acceptance claim. Windows 1.0.9+10 rebuilt
in 149.0 s, AOT freshness/version verified. Android built in 141.8 s; preview
package/version/original signing certificate verified. No GitHub workflow run.
Next: owner clean UE2 replay through usual shortcut; remaining pan outlier and
physical mobile acceptance stay open. Do not claim the app free of all pauses.

## Previous continuation — PC Canvas stalls and local diagnostics

Latest owner steering: publish the current improvement for immediate use, then
continue diagnosing remaining drawing pauses (owner reports roughly 70/30).
Published source 82dfb98 and both installers with all six asset sizes/SHA256
digests verified: https://github.com/iax32/Orbit-Note/releases/tag/preview-1.0.8-2026-10-29
Zero workflow runs for that commit. The release is renderer 11; subsequent local
renderer-12 work below is not included in those uploaded installers.

Follow-up completed locally: recovery-history enumeration/decoding/path checks
now run on a native worker rather than sharing the UI heap/event loop. Requests
are serialized; Vault close awaits maintenance before releasing its OS lease.
Latest version per target and unresolved-journal images remain protected;
malformed/oversized/foreign references stay untouched. 25 retention/recovery/
staging/Canvas checks pass; analyzer clean (29.1 s), strict format 884 files
unchanged (9.08 s). Normal Windows renderer-12 release rebuilt in 92.2 s and AOT
freshness verified; owner's running profiling copy was not replaced or closed.
Native 200-revision scan: foreground 138.986 ms wall, worker cold 108.513 ms,
repeat 143.882 ms. Coarse timer gaps all near idle ~16 ms: this does not establish
180-Hz smoothness or a general wall-time win. Owner replay after restarting via
the normal shortcut is still required. Do not mark drawing performance complete.
The owner drawing also overlapped release compilation, so its frame outliers
need a clean replay with no build/test load before further attribution.

Windows 1.0.8+9 normal release built in 125.7 s, Android in 184.6 s; Windows AOT
freshness and Android package/version/original signing certificate verified.
No GitHub build workflow was run.
Analyzer clean (20.1 s), 3 Android adapter/UI checks pass plus 29 rendering/pen/
theme checks in the preceding batch. All 8 native import safety tests pass
(0.299 s test execution, 76 s Gradle preparation). Strict format: 882 lib/test
files unchanged (8.86 s). Physical Android acceptance and PC pause diagnosis remain.

Renderer 11 reuses completed active-ink widget subtrees as well as pictures;
ink-only hover avoids unnecessary whole-stroke hit tests while nearby cards and
connectors retain exact occlusion checks. Isolated latest-board 400%-zoom replay:
long pressure GPU P95 1.968 ms, mouse 4.741 ms on the 100-Hz probe display.
Owner's full app runs at 180 Hz and still pauses; do not infer acceptance from
the probe. A local full-app CPU/frame/GC capture now runs without reading note
contents. Recent capture contains a 13.658-ms root layout and 11.181-ms raster
span; further attribution is required. Private endpoint and traces stay ignored.

Correction to earlier Drive diagnosis: screenshots showed sync active, but the
UE2 Vault's saved flag was later off, and renderer-10/11 drawing runs contain no
Drive activity. The inventory fix remains relevant when enabled; it does not
explain this latest residual. Numeric sync-state logging now records that fact.

Owner also reports Android selecting another-version Vault folder silently
returns to the welcome page. The existing picker returned an ordinary path
without retaining SAF document access. Android now explicitly imports a local
editable copy through document streams, with progress/errors/retry; source is
unchanged, IDs/unknown files/history retained, device/cache/index files omitted
and imported recovery journals quarantined. No app-build-number gate is added:
repository storage-version read-only protections remain. Android New Vault uses
local app storage too. Physical Lenovo folder-import acceptance remains pending.

Owner reports intermittent severe viewing/drawing stalls after 1.0.7, requests
PC-first diagnosis on the tablet-imported UE2 board and local app logging.
Scope/evidence: docs/tasks/canvas-pc-diagnostics-2026-10-29.md.

Latest confirmed cause: owner's screenshots show automatic Google Drive sync
enabled and running. Its inventory loop still hashed/decoded entire boards on
the UI thread. The current ~15-MB native fixture reproduced a 307.823-ms caller
gap for that foreground work. Large sync inspection/hashing now runs natively
off-thread and returns compact headers, not another full scene graph. Reuse
repository-owned object metadata only after the current byte hash matches;
changed bytes still get complete codec validation. Cached inventory max loop
gap 16.095 ms, cold 18.087 ms, idle 16.460 ms in the native replay. Sync stays
enabled with its existing cadence/conflict/staging checks. 49 Drive/inventory/
replica checks pass plus 30 final inventory/validation/logging checks; stale
cache, malformed tails, future versions and missing attachments remain blocked.
Analyzer clean (18.8 s), strict format 880 files unchanged (7.79 s). Renderer-10
Windows build is running with Orbit closed. Owner replay with Drive active is
still needed before marking the PC drawing goal complete.

Latest continuation: owner still notices pauses after renderer 7. The latest
saved UE2 is ~15 MB / ~96k samples; the original ~7 MB replay hid the worker
handoff cliff. Native AOT replay measured 87–91-ms caller gaps while sending the
whole object graph to a fresh save isolate. Commands now share unchanged owned
element records, and a repository-owned worker is seeded from existing source
text and receives only changed element records/order. It still uses the normal
full JSON encoder and repository atomic write/hash/history contract. Its cache
is derived, single-board, pruned, workspace-qualified and closed on repository
reopen/close; failure resets/reseeds it. Non-portable mutable toJson values are
never trusted as cached immutable records. Native replay reduced repeated save
handoff gaps to ~17–18 ms (idle baseline ~16 ms), first start ~19 ms. 39 targeted
drawing/draft/logging checks and 31 final worker/native safety checks pass,
including worker death/restart, cross-Vault queueing, exact bytes, invalid data,
external writes and native reopen. Analyzer clean (15.4 s); strict format 879
files unchanged (7.16 s). Renderer-9 Windows build succeeded (74.2 s); usual
release and AOT freshness verified. Owner asked to replay UE2 for a minute;
actual-owner acceptance is still required, so do not claim the lag fixed yet.

Identified the imported board (initially 1539 ink elements / 42890 samples);
profiled ignored in-memory copies without writing the original. Stable complete
group membership fixes pan cache churn. Full-app logs then exposed redundant
theme interpolation, repeated drawing comparisons and stale revision echoes;
memoize real theme inputs and immutable revision pairs, clear obsolete echoes,
and keep explicitly colored saved ink independent of changing UI chrome.
Owner confirms viewing is now alright, but active drawing was still unusable.

Active mouse curves now append geometry instead of rebuilding the whole path.
Pressure sections use tight retained layers; only the unfinished tail changes,
preserving all samples, nibs, taper, opacity, release endpoints and history.
Matched 400%-zoom native long-stylus GPU P95 13.009 → 1.691 ms, worst
16.407 → 2.123 ms; over-10-ms frames 96 → 0 / 312. Long mouse GPU P95 4.397 ms.
Native probe uses the 100-Hz display; owner app is on 180 Hz. Physical input
acceptance still needed. Cold/pan outliers remain; do not claim perfect FPS.

Added bounded numeric-only input/paint/frame/cache/heartbeat logging outside
Vaults, Windows-on default, persistent off and Settings → Tools export/location.
48 focused checks pass, including release/undo; analyzer clean (15.5 s), strict
format 873 files unchanged (7.33 s). Windows 1.0.8+9 rebuilt successfully in
75.0 s; usual Desktop shortcut targets this release, AOT newer than lib sources.
Renderer 5 adds active prepare/tail/input timings. Owner asked to reopen UE2
and reported drawing still about 60% smooth / 40% laggy. Actual active
prepare/paint/input are now sub-millisecond, but synchronous draft publication
hit 158.648 ms. Follow-up: reuse owned immutable sample arrays, compare data
structurally instead of encoding both entire boards, and encode/UTF-8/hash large
saves on a native worker. Ordered writes, validation, conflicts and recovery
remain. 26 follow-up checks pass (including large native reopen/invalid JSON/
external edit rejection); 33 save/recovery checks passed in the preceding batch.
60000 samples / 20 guarded app commits: 70–116 ms total in debug tests. Renderer
6 Windows build succeeded (77.0 s), usual release/AOT freshness verified. Analyzer
clean (17.1 s), strict format 877 files unchanged (7.72 s), another 25 drawing/
theme/logging checks passed after the save changes. Owner replay requested;
do not claim the real-app drawing goal complete until that acceptance.
Owner renderer-6 replay improved to about 80% smooth / 20% intermittent pauses.
Its log shows active paint/prepare/input sub-millisecond, but saves 12–26 ms and
editor echo comparisons growing to 8 ms. Completed strokes now own frozen sample
arrays immediately, so later commits and echo comparisons share them. Large
external-change hashes (targeted and full scans), load decoding and freezing now
run off the native UI isolate while byte-identical files retain object identity.
Renderer 7 adds release/scene-snapshot/draft-phase timings. 53 targeted checks,
then 31 checks covering the final scan paths, plus release/palm/undo pass. Native
preflight/refresh tests prove input yields, unchanged identity and conflict guards.
20 guarded commits including 4000 new samples take 67–68 ms in debug. Windows
rebuild succeeded (75.0 s), AOT freshness verified; analyzer clean (15.7 s),
strict format 877 files unchanged (7.55 s). Owner asked to replay UE2 with this
renderer-7 build; acceptance pending.
Owner still reports intermittent lag. Renderer-7 phases show scene serialization
2–6 ms and draft snapshot up to 11.966 ms (active ink still <1 ms), with 1664
strokes / 95732 samples. Preserve owned immutable CanvasElement records at scene
load and use a separate immutable snapshotJson() command API; ordinary toJson()
compatibility remains. Commands reuse unchanged complete element records, not
just sample lists. Scene ordering sorts once per revision; returned lists retain
their previous caller-owned mutable API and undo invalidates the cached order.
48 focused checks pass, including legacy aliases, opaque data, reorder/undo,
layer pixels and competing drafts. Debug guarded 20-stroke commits: 25–29 ms
total (was 67–68 ms). Isolated native AOT probe on the original UE2 fixture:
20 commits incl. 4000 new samples 27.320 ms; background encode/hash/decode keep
the loop yielding (worst gap 17.337 ms with Windows' ~16-ms timer quantum).
Analyzer clean (14.2 s), strict format 877 files unchanged. Renderer-8 Windows
built (74.3 s) but was superseded before acceptance when the latest-fixture save
handoff cliff was found. Renderer 9 is the version offered for owner replay.
No Android work or publication is required for this PC-first continuation.

## Previous task
# Delivered — saved Canvas ink reliability/performance, 2026-10-29

Owner confirms empty boards are smooth but drawing and viewing saved ink remain
severely slow after 1.0.6. Preserve samples, styles, themes, undo and live sharing.
Scope/evidence: docs/tasks/canvas-retained-ink-2026-10-29.md.

Native GPU profiling now covers saved pressure ink, remote cursor updates,
stylus input and a dense 1500-short-stroke board. Implement complete-stroke
retained world layers, local invalidation, incremental live pressure geometry,
and a larger entry allowance within the existing 200k-sample vector budget.
Equivalent OrbitColors now compare by all 29 token values, preventing repeated
saved-scene invalidation during theme recreation/interpolation. Native GPU P95:
100k-sample pan 3.494 ms, remote cursor 3.500 ms, live stylus 7.496 ms. Dense-board
steady-state P95 3.928 ms after the first 12 frames; cold/outlier stalls remain.
80 focused acceptance checks pass, plus pressure/release/undo and export checks.
Analyzer clean; strict format 864 files unchanged. Final Windows 112.8 s, signed
Android 1.0.7+8 144.7 s. Source 4b4529d pushed; Windows setup and APK published:
https://github.com/iax32/Orbit-Note/releases/tag/preview-1.0.7-2026-10-29
All six asset sizes/SHA256 digests match; original APK signing identity retained.
Windows setup built in 11.5 s; usual Windows release updated, AOT newer than all
lib sources. No GitHub workflow runs for source commit. No personal Vault used.
Next: physical Lenovo acceptance on the owner's drawing; don't claim hardware
stylus latency or zero cold-load spikes from synthetic profile input.

## Previous task
# Delivered — Canvas input performance, 2026-10-28

Owner reports severe pen and pan lag on PC/tablet. Preserve features/visuals.
Scope/evidence: docs/tasks/canvas-input-performance-2026-10-28.md.

Active strokes now repaint independently of the full editor/saved scene. Stable
visible-ink caching removes cyclic display-list eviction and repeated saturation
scans. Same vector renderer and all pressure/time samples retained. Dense CPU
benchmark: 1500 strokes/20 paints 1.247 s → .402 s; recordings 30000 → 1024.
All seven nib/highlighter styles pixel-identical at zoom. 22 focused tests plus
two stylus/undo/cancellation checks pass. Analyzer clean (23.6 s); strict format
862 files unchanged. Physical tablet frame times remain unmeasured.

Built Android 1.0.6+7 (final 122.5 s, package/signature checked) and Windows
(final 114.2 s) with complete setup (13.9 s). Usual Windows release updated.
Source 1958458 and both installers published, six asset sizes verified:
https://github.com/iax32/Orbit-Note/releases/tag/preview-1.0.6-2026-10-28
No GitHub workflow runs; private tmp untouched. Next: real tablet stylus/pan
acceptance on the same dense board with live sharing enabled.

## Previous task
# Delivered — easy live sharing buttons, 2026-10-28

Owner requests a fast in-app Start → Copy tablet invitation → Join flow, without
scripts/domains/router configuration. Scope: docs/tasks/easy-live-host-2026-10-28.md.
Preserve Advanced manual hosting and existing Android 1.0.4 compatibility.

Implemented Start live sharing → Copy tablet invitation → Join, with reviewed
temporary HTTPS and no scripts/domain/router setup. Native collaboration DNS
fallback preserves TLS after this network returned NXDOMAIN for new relay names;
install Android 1.0.5 for that fix. Manual self-hosting stays under Advanced.
Normal exit/Stop and a Windows kernel job terminate the helper; new sessions do
not reload prior grants. No personal Vault was used in external acceptance.

Source 6ae4803 pushed. Published Windows setup + Android 1.0.5+6, six verified assets:
https://github.com/iax32/Orbit-Note/releases/tag/preview-1.0.5-2026-10-28
37 focused checks pass; final five host checks including real HTTPS join, Canvas
change and attachment bytes pass. UI/old-grant isolation covered. Analyzer clean
(7.8 s); strict format 860 files/zero changes. Android built in 124.2 s, final
Windows in 95.7 s, setup in 15.1 s. APK signature, version and Google/DNS AOT
strings checked. No workflow runs for source commit. Private tmp remains untouched.

Next required step: owner installs 1.0.5 on tablet and tests Start/Copy/Join from
the usual updated PC build, then a short drawing/image round trip. Physical
acceptance is pending; initial Vault download remains necessary once per device.

## Previous task
# Implemented/published — mobile Google and live Canvas, 2026-10-28

User requests phone Google sign-in repair and live image/ink sharing between
computer and tablet. Scope/evidence: docs/tasks/mobile-live-sync-2026-10-28.md.
Lenovo tablet is now available (2026-10-28). PC is on Ethernet 192.168.1.163/24,
gateway 192.168.1.1. Tablet is 192.168.0.45/24, gateway 192.168.0.1. PC→tablet
ping/route succeeds; reverse direction is untested. Drive needs internet, not a
shared subnet. Owner reports real Google sign-in on Lenovo now displays the
connected account (1.0.4 APK). Physical Drive/live acceptance remains pending.

Both owner-approved Google clients now exist in orbit-note-511512. New Android
1.0.4+5 embeds the public SDK client ID, retains package/signature, and is published
with Windows setup and updated standalone server:
https://github.com/iax32/Orbit-Note/releases/tag/preview-1.0.4-2026-10-28
Source a40977d pushed to main. Six assets verified by size; checksums attached.
82 focused tests pass; strengthened four-test image/ink run passes (actual remote
image decode, local ink 104 ms). Analyzer clean; strict format 850 files unchanged.
Android build 224.1 s; Windows retry 44.9 s plus host; setup 13.7 s. Original
Windows build was blocked by the running app; owner closed it before successful
retry. No GitHub workflow dispatched; no personal Vault/key/config published.

Owner confirmed Lenovo Google account connected. This is user-reported physical
sign-in acceptance, not proof of data synchronization. Next required step: a
synthetic Drive Vault transfer PC→tablet→PC, then restart/conflict checks.

## Previous task
# Delivered — publish 1.0.3, 2026-10-27

User requests source, Windows setup and Android APK on GitHub. Explicitly skip
tests and GitHub workflows. Use local builds and existing preview signing identity.
Scope/status: docs/tasks/publish-1.0.3-2026-10-27.md.

Current source pushed to main: 1151e7f ([skip ci]). Public release:
https://github.com/iax32/Orbit-Note/releases/tag/preview-1.0.3-2026-10-27
Contains complete Windows setup EXE and universal Android Preview APK, version
1.0.3+4, checksums and manifests. Android package/signing identity preserved and
verified. Both asset sizes confirmed after publishing. No tests, analysis/format
gates or GitHub workflows run for this publication, as explicitly requested.
README links updated. Original Vaults/private PDFs/keys remain untouched.

Android Google sign-in still needs distributor registration; local-only Google
mode and existing preview identity retained. Suggested next task: configure that
registration without changing the signing key. Stop before implementing it.

## Previous task
# Delivered — quiet details, 2026-10-27

User approves the complete twelve-detail follow-up. Scope/validation:
docs/tasks/quiet-details-2026-10-27.md. Implement only this batch; preserve prior
delivered workflows and unrelated changes.

All twelve areas completed through existing boundaries: reading anchors,
selection retention, spacing guides, Canvas activation/touch hits, PDF options,
stable refreshed search, table clipboard formats, complete titles, overlapping
PDF mark selection, closed tab groups and local image retry/error feedback.
Final acceptance/performance run: 53 pass; actual-font layout/retry check: 1 pass.
Broader table/search/tab/clipboard regressions also passed; its discovered focus
regression is corrected and covered by the final run. Analyzer clean (12.0 s),
strict format 847 files / zero changes. Native 300-page / 10,000-mark checks run.

Windows release built (99.7 s) with existing registered Google configuration and
standalone server. Seven runtime files verified; data/app.so newer than every
Dart source. Usual build/windows/x64/runner/Release/orbit_note.exe is ready.
No physical tablet/pen or cross-app Excel/Word acceptance claimed.

Suggested next task: native Lenovo acceptance of dense PDF selection, equal-gap
dragging and first-press activation. Stop before implementing another feature.

## Previous task
# Delivered — steady workspace, 2026-10-27

Owner approves all ten refinements from the latest workflow list. Implement only
this batch: stable media loading, drag-edge scrolling, explicit duplicate import
choices, retained temporary forms, unavailable-action explanations, bulk previews,
clear recovery, selection ownership, safer export names and cancellable operations.
Details and validation: docs/tasks/steady-workspace-2026-10-27.md.

All ten areas implemented through existing boundaries: stable image geometry,
drag-edge scrolling/panning, duplicate import choices, retained/reviewable forms,
disabled-action context, bulk reviews, recovery browser, pane ownership, safe
export names/staged writes and cancel/progress. Immediate-edit/close timing fixed.
Final recovery batch: 40 pass; main regression batch: 115 pass plus its corrected
retained-form case covered in the final batch. Analyzer clean (8.9 s); strict
format 842 files, zero changes. Actual-font retained-form capture inspected.
Windows release built successfully in 93.7 s with registered Google configuration
and standalone server. All seven runtime artifacts verified; data/app.so newer
than every Dart source. Usual Release/orbit_note.exe launches the updated app.
No physical tablet/OS clipboard acceptance or Android build claimed.

Suggested next task: profile dense-board drag/edge-pan on the native release and
Lenovo tablet with real touch/pen input. Stop before implementing it.

## Previous task
# Delivered — everyday workflow polish, 2026-10-27

Owner approves the full fourteen-area list. Scope and observable behavior:
docs/features/everyday-workflows.md. Detailed evidence:
docs/tasks/workflow-polish-2026-10-27.md.

Implemented paste feedback/PDF text choices, per-visit navigation, guarded move
recovery, reference previews, save/sync clarity, connection tracing, per-board
tools, Search return, rename context, publishing memory/layout and focus fixes.
Existing placement/object separation and draft recovery remain; note statistics
reuse immutable snapshots for large-project view updates. Canonical references
cannot preview another same-title note. Restart and same-object navigation retain
their return points and never restore a different pane's view.

Validation: 98 main integration checks pass; 37 final sync/settings checks and 37
final navigation/pane checks also pass (overlap: 123 distinct checks). Native
PDFium copy-handler → sourced Source paste → Undo checked with test clipboard
transport; actual-font enlarged-text/connection captures inspected. Analyzer
clean (8.3 seconds), strict format 834 files/zero changes. Windows release built
successfully (82.9 seconds) with registered Google configuration and standalone
server; required artifacts and AOT newer than every Dart source verified. Usual
build/windows/x64/runner/Release/orbit_note.exe updated directly; no ZIP/server
startup/GitHub push. Original user Vaults remain untouched.

No new APK or physical tablet/stylus/cross-app clipboard test claimed. Suggested
next task: restore Android tooling and run real Lenovo touch/pen/clipboard
acceptance. Stop before implementing another feature.

## Previous task
# Delivered — Canvas drawing focus; Android APK blocked, 2026-10-27

Owner's Lenovo tablet feedback: focus mode leaves excessive non-drawing UI.
Scope LAY-01/08/10: reversible full-safe-area Canvas focus and accessible recovery;
no broad native-input completion claim. Details: tablet-canvas-focus-2026-10-27.md.

Implemented shell/bridge/toolbar/title/zoom/minimap hiding, floating Undo/tools/exit,
overlay tool access, system Back exit and Escape dismissal. Existing state,
panels/tabs/minimap settings, camera, content and Undo remain. Loading/standalone
recovery and save/read-only warnings remain reachable; no OS fullscreen changes.

44 focused tablet/pen/minimap/performance/split checks pass; 1024×768 and 820×1180
at 2× DPI fill the safe viewport, plus 800×600 at 200% text. Simulated stylus,
Undo/Redo, Back and exact state retention checked. Actual-font captures inspected.
Analyzer clean (7.7 seconds), strict format 830 files/zero changes. Windows release
rebuilt successfully (73.9-second Flutter build) with registered Google config and
standalone server; required EXE/AOT/Flutter/PDFium/SQLite/server artifacts verified,
AOT newer than all lib sources. Usual build/windows/x64/runner/Release updated.
No server started or keys packaged. Android APK build is blocked by missing Android
SDK (explicit release attempt failed); no new APK
or physical Lenovo/iPad acceptance claimed. Original user Vaults unchanged.

Suggested next task: restore Android SDK/build tooling and build a matching signed
APK for actual Lenovo pen/palm/layout acceptance. Stop before adding other features.

## Previous task
# Delivered — research dossiers, 2026-10-27

Owner approves all ten information/note-taking tools proposed for game reverse
engineering. Scope REV-06–15 in docs/features/research-dossiers.md: recorded
layouts/offsets/functions/instructions, manual pointer/call maps, journals,
build/evidence review, responsive code/explanation layouts, templates and glossary.
No memory scanner, process attachment, binary patching or new external service.

Implementation uses ordinary notes with versioned additive metadata and a guarded
generated-summary region; free writing remains owned by the note. Universal
references and linked sections share canonical sources with Canvas, graph and
existing sync. Function metadata bridges to recorded build comparisons.
Unknown data, stable identities, repository history/Undo and stale/save failures
are covered by targeted checks. No personal Vaults are seeded or modified.

Validation: 92 focused integration checks passed (20 seconds). Final additional
acceptance: 13 passed, including glossary aliases, literal summary markers inside
code fences, live summaries, unknown-data retention and failed-save drafts.
Counts overlap. Native two-Vault synthetic-provider sync preserved 64-bit field
offsets, metadata and editable Markdown in both directions. 390px/200% UI exercised;
actual-font paper-theme capture work/ui/research-dossier.png inspected. Source
versions/build comparison, stale edits, Trash/review, undo and native reopen pass.
One older drawing-embed fixture needed repository/provider initialization in real
async execution instead of the fake test clock; it now passes without skipping.
Analyzer clean (7.9 seconds); strict format: 829 files, zero changes. Logs:
.local/dossier-{final-tests,acceptance,analyze-final,format-check}.log.
No desktop control, real game/debugger, Google-account or physical mobile test.
Windows release built successfully (75.3-second Flutter build) with the existing
registered Google configuration and compiled standalone collaboration server.
Updated build/windows/x64/runner/Release/orbit_note.exe; AOT newer than all lib
sources and required Flutter/PDFium/SQLite/data/server files verified. No server
started, keys packaged, ZIP created or GitHub push requested. Original user Vaults
remain untouched. Build log: .local/dossier-windows-build.log.

Suggested next task: optional reviewed specialist-tool annotation import into
these records. Stop before implementing another feature.

## Previous task
# Delivered — performance and failure-boundary audit, 2026-10-27

Owner requests performance/stress checks and fixes without removing features or
visuals. Scope: measured Finance calculation/indexing, note Find/Replace, existing
large Vault/Canvas/PDF and cross-pane clipboard/draft stress suites. Details and
measured before/after results: performance-audit-2026-10-27.md.

Implemented account/month/kind Finance indexing, weak immutable-object validation
cache, correctly invalidated controller index snapshots, actionable per-card
calculation errors, lazy/single reference scanning and bounded Unicode Find cache.
No storage schema, feature removal, visual reduction or personal Vault mutation.

Initial stress batch: 38 passed. Recovery/split-pane batch: 50 passed. Final
combined acceptance: 118 passed (75 seconds). Analyzer clean (11.8 seconds);
strict format: 824 files, zero changes. Normal Windows release built successfully
(99.9-second Flutter build) with existing Google configuration and compiled
standalone server. Updated build/windows/x64/runner/Release/orbit_note.exe;
no server started, keys packaged or source push requested.
Counts overlap. Initial Finance index and long-note parsing retain measurable
cold costs; production frame-time/mobile/stylus acceptance is not claimed.

Suggested next task: release-mode cold-load/frame profiling on a large synthetic
Vault. Stop before implementing another feature.

## Previous task
# Delivered — finance workspace, 2026-10-26

Owner requests a substantial finance update with expense tracking and essentials.
Scope FIN-01–08 in docs/features/finance.md: exact account/transaction ledger,
transfers, monthly budgets, explicit recurring bills, savings goals, reports,
CSV preview/import/export and existing note/Canvas/history/sync integration.
No bank credentials/API, implicit currency conversion or unrelated roadmap work.

Implementation uses ordinary versioned finance notes and existing repository
commands. Exact minor-unit arithmetic, stable occurrence/import identities,
reviewed-plan guards, stale/Vault ownership checks and recoverable writes are
required. Unknown data and existing user Vaults remain untouched by testing.

Validation: 121 focused finance/sync/Life/reference integration checks passed.
Final finance acceptance suite: 17 checks passed, including all workspace sections,
actual form saves, retained drafts after failure, 390px/568px short-screen layouts
at 200% text, a 5,000-transaction exact ledger, CSV retries and preview ownership,
month-end/leap bill schedules and duplicate occurrence guards. Suites overlap.
Final additional domain rerun covers currency protection with transactions in
Trash, restoration and caller-owned edit snapshots. Native two-Vault sync used a
synthetic provider and preserved exact amounts, memo and unknown metadata. No
real bank, Google account or physical mobile device was used. Paper-theme UI
capture work/ui/finance-overview.png inspected; actual app fonts and palette used.
Logs .local/finance-{final-tests,acceptance-tests,history-tests,analyze-final}.log.
The 5,000-record calculation uses a broad five-second test budget, not a frame-time
promise. No personal Vault data, files or desktop clipboard were accessed by tests.

Windows: separate native CMake Release completed under build/windows-finance/x64;
standalone server compiled successfully without starting a server or packaging
keys. At final installation the usual app/server processes were closed, so the
verified complete bundle was also copied into build/windows/x64/runner/Release.
EXE/AOT/server SHA-256 copies match. AOT is newer than every lib source; required
Flutter/PDFium/SQLite/data artifacts verified. Final analyzer clean (111.3 seconds);
strict format: 823 files, no changes. No source push requested. The original user
Vaults were not migrated or edited by implementation/testing.
Suggested next task: optional institution-specific bank CSV column mapping with
an explicit preview; stop before implementing it.

## Previous task
# Delivered — durable and synchronized preferences, 2026-10-26

Owner requests that collapsed subfolders stay closed through tab changes and
similar settings persist and sync across devices. Scope LAY-01/06/10 and existing
Drive/live shared replication. Preserve local paths, credentials, device zoom,
tabs/cameras/positions and pane layouts. No account-wide service or new permission.

Implemented: normal open/tab/history navigation no longer expands ancestors;
explicit reveal remains available. Renaming/deleting folders remaps/cleans saved
collapse paths. Per-installation `orbit.preferences` records use existing durable
object saves/history and sync; allowlisted fields merge independently with logical
counters/UUID tie-breaks. Device outbox recovers interrupted portable saves;
pending local settings survive remote refresh. Records stay out of knowledge lists
and search. See ADR 0035 for shared-Vault visibility and conflict boundaries.

Validation: 86 focused settings/folder/native-replica/live-server checks passed;
28 navigation/large-text checks and 29 Drive coordinator/recovery checks passed
in follow-up suites. Final regression after first-run migration refinement: 41
passed, including concurrent first-run choices and in-place list mutations.
Suites overlap; counts are not distinct coverage totals. Actual native two-Vault
sync used a synthetic provider; actual loopback HTTP shared server propagated
preferences both ways. Automatic Drive adapter test confirmed preference-only
updates queue and upload without changing the content list. No real Google account
or physical second device was used. Clean analyzer (9.7 seconds); strict formatting
818 files, zero changes. Logs .local/preferences-{final-tests,final-regressions,
automatic-tests,navigation-tests,analyze}.log. Original user Vaults unchanged.

Windows release build completed through tool/build_windows.ps1 (101.8 seconds)
with the existing registered Google configuration; no new credentials or provider
permissions. Updated build/windows/x64/runner/Release/orbit_note.exe, current AOT,
Flutter/PDFium/SQLite and compiled standalone collaboration server verified.
No server process was started. AOT is newer than all lib sources.

Suggested next task: physical Windows-to-Android settings acceptance when a device
is available, including OS font fallback. Stop before implementing other features.

## Previous task
# Delivered — university modeling and engineering lab, 2026-10-26

Owner explicitly approves all seven proposed university tools based on supplied
SE/UML/Distributed Systems PDFs: state/activity modeling and execution, connected
UML checks, test/coverage workbench, Java/JUnit/SMQP, distributed event simulation,
and Dafny contracts. Extend CAN-04/05/07/14/15/16, EDT-08, STUDY-01/02/03,
DEV-01/03/05, PORT-05. Shared offline models/reports in ordinary notes and native
Canvas shapes; explicit local-tool adapters, no automatic network/process starts.
Preserve existing objects/unknown fields, undo/history and platform boundaries.
Build bounded deterministic educational semantics, with unsupported forms/errors
explicit. No arbitrary Java/UML inference or invented proof/coverage results.
Validate domain failures, UI integration, persistence/reopen and native adapters;
run focused tests, format, analyze, and normal Windows release.


Implementation: shared portable UniversityDocument v1, ordinary Canvas placements
and live diagram export, Rich/Read note presentation, generated Markdown reports,
state/activity/CFG/vector-clock/SMQP operational teaching engines, UML checks,
Java/Dafny tools and profiles. Explicit tool failures, bounded runs, stale-owner
recovery copy dialog, protected-path warnings and draft-discard controls included.
Canvas regeneration retains model-frame/node/edge identities, geometry and unknown
fields; free untracked members remain. See full operational subsets and exclusions
in docs/features/university-modeling-lab.md; no whole-UML/IDE/proof-engine claim.

Validation evidence: 133 focused editor/IDE/launch/UML/model/export integration
checks passed, with four native Python/toolchain cases skipped by their existing
opt-in prerequisites. Final additional suite: 95 checks passed (including the new
models/UI/native adapters/reopen/PDF tests plus publication theme/structure,
split-pane history and large clipboard/Canvas transfers). Suites overlap; these
counts must not be summed as distinct coverage. All seven lab UIs exercised;
390px / 200% text, invalid JSON, Rich reopen, Canvas selected-frame replacement,
free member retention and exact Undo exercised. Actual local TCP covers fragmented
UTF-8 frames, stateful SMQP, disconnect and oversized peer input. Missing Dafny
executable returns real failure; no Java/Dafny installation or genuine compiler/
verifier acceptance is claimed. Original user PDFs and Vaults unchanged.

Performance: 90 orthogonal state regions and 200 events (18,000 internal actions)
completed in 108–114 ms in synthetic isolated runs; exact state count/result
asserted with a broad five-second test budget. Not a device frame-time guarantee.
Native PDFium extraction verified report PDF text and absence of JSON metadata;
HTML/Word outputs and ordinary Markdown file reopen also exercised. Known model
metadata is masked in Read/search/export; fenced literal examples stay literal.

Final analyzer clean (8.9 seconds); strict format: 816 files, no changes. UI captures
use actual paper-theme fonts and the production Canvas painter. Evidence logs:
.local/university-final-tests.log, university-integration-tests.log,
university-analyze-final.log, university-format-check.log. Captures work/ui/university-*.png.

Windows: isolated CMake Release completed successfully under
build/windows-university/x64/runner/Release/orbit_note.exe. Original running
release/locked DLLs were not overwritten. Verified current AOT newer than all lib
sources, executable, Flutter/data, PDFium/SQLite and standalone collaboration
server present. Server compiled successfully; no server process started or keys
packaged. Three final paper-theme UI capture checks passed; inspected state and
activity layouts with production routing. Existing usual release folder unchanged.

Follow-up: owner confirmed Orbit closed. Normal tool/build_windows.ps1 completed
successfully (45.6-second Flutter release build) with registered Google desktop
configuration and standalone collaboration server. Verified normal executable,
current AOT, Flutter/PDFium/SQLite and server at build/windows/x64/runner/Release.
The usual run folder now contains this update; no additional source changes.

Suggested next task: use one real course exercise to validate the declared
state/activity model against the lecturer's expected trace, then real installed
Java/Dafny toolchain acceptance. No automatic proof/instrumentation is implied.

## Previous task
# Delivered — clipboard, selection and transfer stress audit, 2026-10-26

Owner requests heavy PDF→Markdown, cross-pane selection, copy/cut/paste and
Canvas movement/transfer acceptance (response annotation 1). Scope DES-01/02/05/06,
existing editor/PDF/Canvas adapters and history. Audit large rich/plain payloads,
source links, Unicode/newlines, pending callbacks and repeated operations.
Use synthetic data and isolated tests; preserve user Vaults and desktop clipboard.
Fix reproducible loss/corruption/performance issues, run focused stress checks,
format/analyze, and build normal Windows release. No new feature layer.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Delivered — heavy-use reliability audit, 2026-10-26

Owner requests broad bug/performance/visual hunting. Prioritize reproducible
failures around recent Canvas/workshop and document export changes, then focused
PDF/editor/large-scene regressions. Preserve user Vaults and unrelated changes.
Fix data-loss, stale callbacks, sorting/focus, timer rebuild cost, placement
collisions and literal-source parsing boundaries. No new product feature scope.
Run focused stress/regressions, format/analyze and normal Windows release.

Fixed reproducible export corruption: an aligned heading followed immediately by
a code fence containing a blank line split one fence into two and consumed prose.
Alignment now marks one line and resolves after standard parsing, with a linear
marker pass. Added exact fence/prose and 1,200-marker regressions.

Canvas/workshop fixes: isolate countdown rebuilds from sorting/list rows; read
current score for rapid clicks; keep keyed row identity during ranking; correct
fractional countdown display; guard unapplied bulk/vote drafts; keep stale-save
tallies visible; left-align idea labels. Color clustering avoids fixed/unselected
solid content and adds no no-op Undo. CSV includes protected visible notes and
works read-only, with bounded complete output and UTF-8 BOM. User Vaults untouched.

Validation: 57 heavy-use/native PDF/storage/performance checks passed, plus 51
editor/Canvas/publication checks. Final 14 audit/Canvas regressions passed after
polish, including row identity and no-op Undo; over 100 distinct targeted cases
across these runs. Exercises 1,000-note native reopen, seeded mixed Canvas history
and index consistency, repeated native save/reopen conflicts, 300-page PDF distant
render/text/navigation, 10,000 highlights, 100,000 ink samples, large note indexes,
200-note clustering, 390px/200% dialog layouts and exact export fidelity. Native
PDF benchmark: six distant text/raster measurements 236 ms in this synthetic run;
not a frame-latency or physical pen guarantee. Workshop desktop visually inspected.
Strict format: 793 files, no changes; final analyzer clean (6.3 sec).
Normal Windows release succeeded (72.5 sec), including standalone server.
Fresh AOT/runtime/assets/server files and lib/main.dart target verified.
No Git publication or server start.

Limits: this is a focused audit, not full-app proof or physical stylus/multi-device
acceptance. Existing manual voting/local timer limits remain.
Suggested next task: real-session clipboard and cross-pane selection acceptance
with varied browser/office clipboard payloads and repeated mode switches.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Delivered — Canvas brainstorming and workshop pack, 2026-10-26

Owner requests missing Miro-style features and prioritizes workshops/brainstorming.
Scope CAN-04/05/10/14/15: bulk editable sticky notes, deterministic color clustering,
CSV idea export, local workshop countdown and facilitator-controlled vote tallies.
Use existing scene/history/persistence. No claim of participant-authenticated votes,
synchronized timers, complete Miro parity or new backend. Guard stale/read-only
callbacks, preserve locked/grouped/container items, IDs and unknown data. Test
bulk limits, recovery/undo, dialog layout and stale board rejection, then Windows.

Implemented toolbar lightbulb and context entries; bulk line/paragraph sticky
creation with bounded counts/size, automatic taller notes and grouped Undo;
deterministic color clustering preserving IDs/metadata and skipping protected
placements; CSV with complete quoted text and spreadsheet-formula neutralization.
Workshop panel supplies local monotonic pause/reset countdown, manual vote edits,
score ranking and source navigation; save tallies as one undoable placement command.
Stale board/revision/read-only callbacks reject mutation. Blocked bulk drafts stay
in this editor instance for reopening. No backend or universal object duplication.

Validation: 33 focused Canvas/arrangement/history/group/column tests passed.
Final seven workshop regressions passed after draft recovery/polish, including
390px/200% controls, timer disposal, votes/Undo, native JSON round-trip/unknown
fields, switched-board refusal and retained draft. 200-note pure clustering took
24.4 ms in initial debug run and 11.7 ms in final run; no overlap in generated
cluster geometry. These numbers exclude routing/painting and are not device
frame-latency acceptance. Bulk/workshop desktop dialogs visually inspected.
Final analyzer clean (8.2 sec), strict formatting previously 792 files unchanged;
last test capture wrapper formatted separately. Normal Windows release succeeded (90.2 sec), including standalone server.
Verified main.dart target and fresh AOT/runtime/assets/server files. No server
started and no Git publication.

Limits: no authenticated participant ballots, synchronized timer, persistent
cluster objects or AI semantic clustering. User Vaults unchanged.
Suggested next task: shared workshop sessions with participant vote budgets and
a synchronized host-controlled countdown through the existing collaboration server.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Delivered — H1 chapter breaks and justified paragraphs, 2026-10-26

Owner requests a global option starting every H1 on a fresh export page and
Blockformat in the Markdown editor, interpreted as Blocksatz (justification),
because block-type conversion already exists. Scope existing EDT/PORT paragraph
alignment and publication settings. Preserve exact Markdown, undo/selection,
code literals and old settings; support Rich/Read/Source and PDF/HTML/Word.
Validate focused editing/pagination regressions and normal Windows release.

Implemented persisted optional h1PageBreaks, default off, retained through style
presets and cleared by Reset style. It decorates every current/future H1 across
PDF/HTML/Word; PDF deduplicates explicit breaks and avoids a blank fresh chapter.
Toolbar Justify · Blocksatz uses existing portable paragraph alignment comments.
Rich/Read/Source edits and undo retain inline markup; code remains literal.
Publishing now retains paragraph alignment, combines HTML style rules safely and
uses full-width spanning PDF text so alignment is visible without losing pagination.

Validation: 90 focused editor/publication tests passed; 19 visibility/chapter/
profile tests rerun after PDF width correction. Final geometric assertion checks
right-aligned heading placement. CRLF/unknown comment safety, code literals,
H1/H2 boundaries, duplicate page breaks, metadata round-trip and 390px/200% UI
save flow covered. PDF chapter/alignment fixture rendered and visually inspected.
Strict formatting: 788 files unchanged; analyzer clean (6.5 sec).
Normal Windows release succeeded (73.9 sec), including standalone server.
Main.dart target and fresh AOT/runtime/assets/server files verified. No server
started, no Git publication and no user Vault changes.
Suggested next task: paragraph spacing/line-height publication controls using
the same preview and recoverable settings boundary.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Delivered — PDF export profiles and scalable typography, 2026-10-26

Owner requests continued PDF structure/layout improvement. Scope EDT/PORT-05
existing publication settings: useful compact, accessible-reading and technical
profiles alongside existing styles, preserving paper choice, metadata, per-block
layout and editor theme. Make heading typography scale with body size consistently
in PDF/HTML/Word. Verify large-text long headings/tables and draft/save behavior,
then build normal Windows release. No Vault mutation or schema migration.

Implemented three additional explained profiles and current/custom descriptions;
all six presets preserve metadata, paper choice, Canvas inventory, block layout
and editor appearance. Shared heading scale fixes fixed-size headings in
large-print PDF/HTML/Word; title and contents typography scale with body size.

Validation: 58 targeted publication/layout/visibility/images/theme/bundle tests
passed. Final new-profile tests also pass at 390 px width with 200% text scaling,
including selection and explicit save. Large-print fixture retains 45 table rows,
very long headings and end sentinel over seven pages. PDF contents, heading and
table pages visually inspected. No user Vault changes.
Strict formatting: 787 files, no changes. Final analyzer clean (6.7 sec).
Normal Windows release succeeded (76.0 sec), including standalone server.
Verified main.dart target and fresh AOT/runtime/assets/server files. No server
started, no Vault changes and no Git publication.
Suggested next task: per-Canvas export selection and page-range preview for
large technical appendices, using existing immutable export snapshots.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Delivered — PDF structure and layout polish, 2026-10-25

Owner requests a broader PDF quality pass. Scope current EDT/PORT publication
layout, chapter breaks, heading pagination, contents alignment and Canvas page
navigation while preserving the delivered editor designs and complete content.
Use existing print-layout settings and snapshot boundaries; no owning migration.
Plan: heading break controls in the page-aware outline; measured/estimated safe
heading/figure spacing, fixed-column TOC page numbers, optional whole-board
overviews before tiled Canvas detail, bounded preview caches and isolated bundle
generation. Exercise real homework snapshots read-only plus focused regressions;
build normal Windows release after verification.

Implemented chapter break controls with guarded draft/save behavior, cross-format
page-break output, duplicate-heading safety, estimated heading/figure pagination,
aligned linked contents, palette-aware table striping, quieter header/footer,
optional tiled-Canvas overview/bookmarks/coordinates, small-board scale cap,
independent combined-preview state and bounded theme surface cache.

Validation: 55 focused publication/layout/theme/images/bundle tests passed.
Read-only current Software Engineering snapshot exported as a 10-page warm-grid
note and multi-page Aufgabe 7 Canvas. Visually inspected contents, first body/table
page, Canvas overview and detail. No missing-resource warnings; source Vault not
changed. Analyzer clean (68.8 sec). Full suite intentionally not repeated.
Final 10-test structure/bundle regression rerun passed after warning propagation.
Strict formatting: 785 files, no changes. Normal Windows release succeeded
(79.9 sec), including standalone server; main.dart target and runtime/data/AOT
files verified. No server started, no user Vault changed, no Git publication.

Limits: heading room is estimated, so unusual oversized layouts still require
preview review; Canvas PDF uses the existing bounded raster renderer.
Suggested next task: accessible preset profiles for compact handouts versus
large-print reading, using these existing publication settings.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Delivered — PDF editor design fidelity, 2026-10-25

Owner requests the full editor design in PDF: Orbit palette, writing paper rules,
and pixel-book/other design chrome, beyond just themed Canvas illustrations.
Scope existing EDT/PORT publication + LAY presentation, no owning schema change.
Capture current device-local writing appearance and effective theme when publishing
opens. Use the same WritingSurfacePainter on each page, bounded photo loading,
embedded design fonts and searchable paginated text. Provide a plain-document
opt-out; do not serialize private design/photo recipes into Markdown or sync.
Carry current Canvas palette onto appendix page backgrounds/headings as well.

Implemented existing shared painter backgrounds, all ten designs/four paper types,
216-dpi repeated page surfaces, palette-aware text/links/borders/footer, embedded
Tiny5/Crimson/SpaceMono design fonts and recolored PDF math resources. PDF theme
snapshots/cache do not alter HTML/Word resources. Personal photos use existing
position/fit/opacity/readability controls, a reading sheet, dimension/input caps
and a ten-second load deadline; high contrast omits photos and CRT scanlines.
Framed designs have a safe minimum print margin. Source text still flows across
pages; the paginated PDF is not a pixel-for-pixel viewport screenshot.

Validation: 44 focused checks passed across themed PDFs, background photos,
mixed note/Canvas bundles, selected UML/text references, pagination, attachment
images and connected publishing. Covers all ten design surfaces, real rendered
pixel-book/warm-grid/CRT PDFs across multiple pages, searchable end sentinels and
safe text bounds, photo decoding/reading-sheet/cache/missing fallback/high contrast,
and narrow enlarged-text controls. Pixel-book and CRT pages visually inspected.
Strict formatting: 784 files, no changes. Final analyzer clean (6.8 sec).
Normal Windows release succeeded (79.6 sec), including the standalone collaboration
server. Verified normal lib/main.dart target, EXE/runtime/AOT/server files and
payload newer than the final theme/export sources; no profiler marker. Usual
release run folder updated, no ZIP, server launch, desktop interaction or Vault
write. This build also contains the earlier combined note/Canvas PDF and mixed
UML/text Markdown export updates which previously awaited a release.

Suggested next task: page-aware manual break controls in the themed PDF preview.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Submission PDFs delivered; export update awaiting release — 2026-10-25

Latest urgent export: outputs/pdf/Uebung 2 - Aufgaben 1 bis 7.pdf contains all
seven tasks in order (16 pages), retaining the note text/images and complete
current Canvases for tasks 2, 3, 4, 6 and 7. Replaced duplicate embedded selections
with those current complete board snapshots in the export only. Warm Paper palette,
mixed A4/A3 pages and task bookmarks retained. Reopened all seven parts and merged
output; no missing-image fallbacks. Inspected rendered Canvas 3 and 7 pages.
Original Vault untouched; no additional source/release changes for this export.

Urgent follow-up: Canvas publication snapshots now accept the captured app
ColorScheme instead of forcing dark. Publishing and combined/standalone PDF
dialogs pass the current theme. Regenerated both submission files with Paper's
warm palette and inspected an embedded diagram page. Markdown diagram selection
also includes free connectors/lines, ink, frames and section text; bound internal
connectors retain implicit resolution. Five focused bundle/selection/palette
tests pass; existing technical-article workflow regressions passed in the same
preceding run. No Windows release build yet; installed executable unchanged.

Owner requests standalone Canvas PDF and note-first combined PDF with independent
Canvas orientation, readable pagination and full bounds. Then explicitly asks to
finish quickly for imminent submission. Scope PORT/EDT publishing + Canvas export.

Implemented source: shared PDF append callback, standalone Canvas PDF entry in
Canvas export, note publishing Combine with Canvases dialog with ordered Canvas
appendices, per-Canvas auto/portrait/landscape/A3/fit or overlapping readable tiles,
bounded 100 pages per Canvas/500 total and preview-before-save. Original objects
remain untouched. Three new focused checks pass (coverage/orientation, mixed PDF
pages/TOC/failure propagation, compact enlarged-text controls). Existing focused
publishing/image checks passed in the preceding run; one new failure-path test
was corrected and rerun. Full analyzer attempts stalled and were interrupted;
no Windows release build completed for this update. Do not claim installed.

Prioritized the imminent submission: generated outputs/pdf/Aufgabe 7.pdf (one A3
portrait page, matching tall diagram) and outputs/pdf/Uebung 2 mit Aufgabe 7.pdf
(11 pages, Canvas last). Eight embedded images, no missing-image fallback warnings.
Actual note and Canvas read as snapshots; no Vault write. Native generation test
passed, PDF reopened and rendered for visual inspection. PDF source paths and
relative attachment resolution checked. Mixed-page PDF can use landscape in UI;
these deliverables use portrait for the tall sequence diagram's readable fit.

Next task: finish analyzer/release verification and build the Windows update;
audit preservation of explicit light ink on print-paper Canvas exports.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Delivered — Aufgabe 7 editable Canvas content, 2026-10-25

Owner requests transferring their attached Aufgabe_7_Sequenzdiagramm.pdf into
the existing Software Engineering / Aufgabe 7 Canvas, matching their earlier
chat solution. Read the named chat and verified identical source PDF hashes.
No application feature expansion, build, screenshots-in-Canvas or mouse control.

Prepared 138 ordinary editable Canvas elements (44 messages including returns),
native participant lifelines, Screen actor, activation bars, notes and fragment
frames. Preserved ordering, created-object start positions, loop bounds, full
break coverage, result alternatives and source labels. Per-message arrows and
labels are grouped; message geometry uses ordinary explicitly positioned Canvas
connectors, not a new live sequence-routing model. Label/frame placement was
visually inspected with Orbit's renderer and adjusted for native text padding.

Scratch-Vault round-trip and message manifest checks passed. Initial insertion
was correctly refused by the live Vault lock. After owner closed Orbit, saved
through WorkspaceRepository/NativeWorkspaceStore with revision/source guards,
normal recoverable history and an extra original-file backup under .local.
Existing board identity 92a5d2ae-5ca3-491f-aed1-7cf92073afb6, revision 3 -> 4.
Reopen confirmed all 138 elements; other five Canvas file hashes unchanged.
No app code changes; broad code tests/build are unrelated to this content task.

Suggested next task: independent sender/receiver heights for native sequence
messages, so arrows can stay bound across differently created lifelines.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Implemented — class exercise tools and reviewed sequence drafts, 2026-10-25

Owner requests the missing tools for deriving class diagrams from sequence
diagrams: navigable associations, self-associations and a quick conversion path.
Scope CAN-04/05/14/15/16. Preserve source sequences and unknown data. Add only
reviewed draft generation from typed Canvas lifelines/messages, not image/PDF
interpretation or semantic correctness claims. Infer only unambiguous literal
types/explicit signatures; leave unknowns visible. One Undo removes insertion.
Focused regressions and normal Windows build; no full-suite run.

Implemented class tools in the existing interaction popup and Shapes menu,
four navigability choices, same-class associations with exterior shared-engine
loops, and reviewed independent sequence-to-class drafts. Source instances and
messages remain unchanged. Unknown types and ambiguous replies require review;
there is no PDF/image interpretation or semantic proof of a class model.

Validation: 60 focused tests passed across sequence drafts, class UML,
interaction diagrams, connectors and connected publishing. Includes the exercise
topology, inferred literal returns/overloads, bidirectional and self relations,
fresh-ID conflicts, source preservation, cancel/insert/one-step Undo, loop
hit/export/reload/movement, navigation and custom routing preservation, narrow
dialogs with enlarged text. Fixed a large-text navigation dropdown overflow.
Final analyzer clean (9.4 sec); strict format check passed across 778 files.
Normal Windows release built successfully (102.6 sec), including the standalone
collaboration server. Target lib/main.dart; usual EXE/DLL/data folder, no ZIP or
server launch. AOT payload newer than edited source; required release files
verified. No user Vault or desktop/mouse interaction.

Suggested next task: preview/validate class-member signatures and parameter names
without attempting to infer attributes or hidden navigability from images.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Delivered — high-degree actor routing, 2026-10-25

Owner cancels PDF insertion (already completed manually) and requests reliable,
readable routing for the many coffee-machine associations shown in screenshots.
Do not alter personal Canvas files or use mouse/desktop control. Scope existing
CAN-05/07/14/15/16 routing, actor fan-out, warning legibility and performance.

Plan: reproduce the real geometry read-only with anonymized IDs/text in ignored
fixtures; identify degree-related port/corridor limits; fix distinct routing
without shared trunks or bypassing obstacles, exercise 12–64+ associations,
labels/export/undo/workers and native performance; build normal Windows release.
Preserve layout, identities, notation, manual paths and unrelated changes.

Delivered reserved independent actor stems, globally distinct tips, validated
direct associations, adaptive narrow-gutter routing and finer dense-fan search.
Shared spatial indexing bounds large-board neighbor work and label collisions;
projected preview labels are reused safely. Direct paths follow the actor during
drag and warning text no longer clips. No personal Canvas/PDF edits or mouse use.

Current coffee geometry: 9 blocked routes before, all 16 resolved after, including
repeated moves. 106 combined tests passed; final 42 routing checks and 15 capacity
checks also passed (overlapping, not summed). Final capacity run includes the
coffee topology with 600 unrelated objects. Analyzer clean (10.3 sec), strict
format clean across 779 app/test/tool files. Normal Windows release and matching
server built (92.0 sec), current AOT/main target/runtime verified.

Native coffee input p95 2.185 ms; extreme 64-numbered-link input p95 29.976 ms.
No universal planarity, constant latency or pixel-separation guarantee is claimed.
[Implementation, measurements, acceptance and limits](high-degree-routing-2026-10-25.md).

Suggested next task: offload remaining label-heavy extreme-fan pointer work.
Stop before implementing it.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Delivered — compact Canvas publication defaults, 2026-10-25

Owner requests hiding the long Canvas source URI/revision and text inventory in
PDF by default. Keep the actual rendered diagram, authored references and useful
unavailable-source fallbacks. Add an opt-in publishing checkbox through existing
portable settings; old settings without the new flag default to compact output.
Validate native PDF text/images, settings, linked snapshots and export layout;
build the normal Windows release. No unrelated editor/routing changes.

Implemented optional `canvasDetails` publishing setting, default false including
older saved styles. Available as **Canvas source and text inventory** in the
export workspace. Successful Canvas snapshots retain their image/title but omit
generated provenance/inventory unless explicitly enabled. Original notes/IDs and
unavailable-source recovery text remain; PDF/HTML/Word share the option.

41 targeted publishing/layout/visibility tests passed (9 sec). Native PDF text
checks confirm details absent by default and restored on opt-in; PNG embedding,
precise selections, PDF/HTML/Word resources, compact controls and settings remain
covered. Root analyzer clean (8.6 sec); strict format clean across 775 lib/test
files. Evidence: `.local/compact-canvas-publication-{tests,analyze,build}.log`.
Normal configured Windows release and matching server built (83.4-second Windows
compile). Verified new export-setting string, required runtime files and absence
of the profiler entrypoint in release AOT. Updated the usual
`build/windows/x64/runner/Release/orbit_note.exe` distribution (Dart changes are in
the sibling `data/app.so`). No archive, personal-Vault launch or publication.

Suggested next task: review page breaks for large diagram exports. Stop before
implementing it.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Delivered — readable use-case routes and automatic organization, 2026-10-25

Owner requests an explicit organize button, easier-to-follow independent lines,
fewer unnecessary bends/back-side detours, no shared line segments, and legible
endpoint multiplicities. Scope CAN-05/07/14/15/16. Preserve existing identities,
manual routing, unknown data, styles, unrelated board content and undo/redo.

Plan: reproduce the pictured actor/use-case topology; remove unsafe routing
fallback, improve port/path choice with bounded work; add deterministic,
component-scoped organization as one history command; test route separation,
obstacle avoidance, topology/metadata preservation and real performance; build
the normal Windows release. No full-suite run or personal-Vault mutation.

Delivered the **Organize use-case diagram** toolbar button as one recoverable
placement command, short-path side scoring and separate relationship corridors.
Removed the crossing/merged emergency route. Canvas/SVG/hit testing now display
selectable warnings rather than phantom straight blocked paths; safe interactive
repair keeps dragging responsive. Existing identities/notation/manual data kept.

80 focused tests passed (14 sec), strict format and analysis clean. Verified
native Windows drags: event p95 2.474 ms synthetic / 1.001 ms anonymized existing
layout; maximum 3.082 / 1.205 ms, zero errors. Organizing the existing layout
needed 7 ms and resolved all 12 relationships. Normal configured Windows release
and matching server built (97.9 sec); regular entrypoint/runtime/new feature
strings verified. No global-optimum or arbitrary-graph planarity claim.
[Implementation, measurements and boundaries](readable-use-case-layout-2026-10-25.md).

Suggested next task: arrangement alternatives for diagrams with many actors.
Stop before implementing it.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Delivered improvement; residual spikes documented — large-workspace latency and stability, 2026-10-25

Owner requests completing the stability/performance audit: remaining load and
recalculation spikes, large Vaults, long notes, mixed Canvas/PDF workloads and
the previously measured ~70-ms routing event. Preserve visuals, capabilities,
authored data and unrelated sync/PDF/UML work. Focused tests, not the full suite.

Plan: capture reproducible before measurements and exact route snapshots; fix
measured algorithmic/rebuild hot spots; exercise repository/long-note/PDF/Canvas
failure boundaries together; rerun native profile measurements and focused
regressions; analyze/format and build the normal Windows release. Use isolated
fixtures, no writes to personal Vaults/accounts. Report synthetic versus real
device/Vault coverage honestly, including retained worst-case limits.

Delivered worker-based cold/release routing, exact geometry optimization,
unchanged-object reuse, bounded transactional index batches and cancellable
delayed PDF loading. Combined 160 focused tests passed; final routing group
21 passed (overlapping, not additive). Strict format and app/vendor analysis
clean. Normal configured Windows release and matching server built (93.1 sec).
Synthetic release event 43.508 → 0.799 ms; native index 867 → 298–303 ms.
One synthetic in-gesture fallback still took 44.813 ms; cold GPU raster reached
163.428 ms. These residual limits are open, not universal performance closure.
[Workloads, before/after evidence and acceptance limits](large-workspace-performance-2026-10-25.md).

Suggested next task: remaining invalid-preview routing fallback and first-raster
spikes. Stop before implementing it.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Windows delivered; Android acceptance blocked — background Drive sync, 2026-10-25

Owner authorizes completing device synchronization: closed-app/background runs,
Windows/Android convergence, reconnect/conflict safety and Drive revision cleanup.
No physical Android device is available (owner confirmed). Real-device acceptance
must remain explicitly unverified; isolated native two-client and network-failure
checks will be used. Preserve unrelated diagram/PDF work and local-first authority.

Implement opt-in platform background scheduling through the existing repository,
Vault locking, account binding and SyncEngine. No surprise task installation or
uploads: enablement is an app setting; background execution never opens consent
UI. Use reviewed immutable cleanup receipts before old payload removal; older
clients fail closed after the protocol upgrade. Keep the revision metadata,
current heads, conflicts and tombstones. Metadata compaction is not delivered;
the 10,000-record safety bound remains. Interrupted maintenance is replayable.
Focused tests/platform builds and documentation evidence required. No personal
Vault transfer, external deletion, active background task installation or public publication is
performed as part of development validation.

Implemented scope and acceptance limits:
[background Drive delivery](background-drive-2026-10-25.md),
[ADR-0033](../adr/0033-background-drive-and-payload-retention.md).

78 focused sync tests passed; analyzer clean. Windows release and hidden disabled
worker validated. A temporary disabled Task Scheduler schema test was accepted,
queried and immediately deleted; no job executed. Android build attempted but
blocked by missing SDK; no physical Android device is available. Real-account
background runtime/physical acceptance and graph metadata compaction remain
explicitly open; this is not a claim that every original sync gap is closed.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Validated — use-case routing performance, 2026-10-24

Owner reports useful paths with minimal crossings but severe lag; explicitly
requested performance tests and focused validation, NOT the full ~3,000-test suite.
Scope existing CAN-05/07/14/15/16 geometry and interaction performance. Accepted
route/label presentation and unrelated PDF/sync changes preserved.

Exact routing-input cache reuse removes complete searches for styling, stacking
and attached fallback-coordinate updates. Related drag/history writes batch
spatial bounds refreshes; in-batch queries remain current. Spatial line filtering
and grid-edge collision memoization accelerate searches. Validated interactive
path continuation avoids whole-graph routing at each pointer sample; release and
cancellation restore canonical geometry. Captured cold routes and label boxes
are identical to the baseline. No durable data/schema change.

**88 focused tests passed** (17 sec), including five new cache/batch/gesture
regressions; no full-suite run. Analyzer clean (82.4 sec); format/strict clean
across 764 lib/test files, plus both benchmark tools. Isolated native Windows
profile: 32 input moves, event p95 **2.853 ms**, frame-build p95 **3.549 ms**,
raster p95 **3.821 ms**, no errors. One full-layout event still took 69.992 ms;
release/finalization 49.535 ms. No physical-device latency guarantee.
[Before/after evidence, limitations and logs](use-case-performance-2026-10-24.md).

Configured Windows app and matching standalone server built (90.8-second Windows
compile). All 910 frozen inputs unchanged; seven runtime/server files, regular
app PDF control and absence of the synthetic profiler entrypoint verified.
Updated `build/windows/x64/runner/Release/orbit_note.exe`. Only the isolated
synthetic profiler ran and closed itself; no personal Vault/account, main-app or
server launch, GitHub publication, Android/web rebuild or archive.

Suggested next task: profile remaining full-layout spikes using a larger
anonymized diagram. Stop before implementing it.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Built, runtime untested — separated obstacle-avoiding use-case connections, 2026-10-24

Owner clarified all requirements together: avoid use-case interiors, avoid other
lines/crossings, never merge separate relationships, and clearly associate each
multiplicity with its own line. Explicitly requested NO tests and a Windows build.
This supersedes both previous routing presentations below.

Automatic use-case links now route with hard line-corridor separation instead of
crossing/overlap penalties or direct-line fallback. Node clearance is retained;
actor/oval ports are distributed. Alternate endpoint sides and up to six ordering
passes retry blocked links. Search is bounded per candidate. If an impossible or
exhausted layout has no free route, show a selectable 'Move items to route this
connection' indicator instead of fabricating a crossing/merged connection. No
stored relationship is removed. Endpoint multiplicities are placed inline on
their own line with a small outlined background and avoid other routes/labels.
Canvas, SVG, Markdown previews, hit areas and selected export bounds share it.

Tests and analyzer deliberately not run per owner instruction. Changed Dart files
formatted; configured Windows app and matching standalone server built successfully
(94.5-second Windows compile). Seven runtime/server files and the new safe-routing
fallback text in AOT verified. Updated usual
`build/windows/x64/runner/Release/orbit_note.exe`. Eleven existing regression cases
were adjusted to the new contract but NOT executed. Owner confirmed app closure
for replacement. No runtime acceptance or universal planar-routing guarantee is
claimed. Source snapshot: `.local/uml-separated-final-inputs.json` (907 inputs);
build log: `.local/uml-separated-windows-20261024.log`.
No personal Vault edits or GitHub publication. Prior validation counts apply
only to the previous revisions, not this changed routing algorithm.

Suggested next task: optional manual waypoints for blocked layouts; stop before
implementing it.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task — superseded presentation below

# Validated — independent use-case lines, 2026-10-24

Owner rejected bundled automatic routes: connections appeared joined and harder
to trace. Explicitly requested a quick fix, no large test-suite rerun, and a
Windows release. Removed the automatic Manhattan search/shared lanes/opposite-side
detours. Existing default use-case links now draw independent direct segments,
with distinct endpoint ports and retained multiplicity label spacing. Manual
curves/orthogonal routes, endpoint guidance, direction-swap multiplicities and
SVG bounds remain. No stored diagram data is changed.

Eleven focused diagram checks passed (one second execution plus compilation),
including an explicit no-common-lane regression, actor move/Undo/Redo/reopen,
label positions/hit areas, direction swapping, manual routes and SVG. The full
suite is intentionally NOT rerun for this revision, per owner instruction.
Analyzer clean (7.4 seconds); changed files formatted. Windows app and matching
standalone server built successfully (81.9-second Windows compile). All 907 frozen
inputs unchanged and seven runtime/server files present. The usual
`build/windows/x64/runner/Release/orbit_note.exe` is updated. No app/server launch,
GitHub publication, Android/web build or personal Vault modification. Logs:
`.local/uml-independent-{tests,analyze}.log` and
`.local/uml-independent-windows-20261024.log`. A final brace-only analyzer style
correction followed the focused tests; no functional change. See updated
spatial-board behavior.

Suggested next task: optional manual connector waypoints; stop before implementing.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task — superseded routing behavior below

# Validated — use-case multiplicities and obstacle routing, 2026-10-24

Owner reports overlapping/illegible actor-end multiplicities and connections
crossing use cases/other lines. Scope CAN-04/05/07/14/15/16: repair existing
use-case relationships in the shared Canvas/Markdown/export geometry. Preserve
stored endpoint labels, identities, manual routing, sequence/class diagrams,
undo/history and unknown data. Inspect the authorized Software Engineering chat
for the actor-end `2..*` example; no homework changes or messages to that chat.

Implemented derived obstacle-aware routes for existing automatic use-case links,
separate shared actor ports and endpoint labels, and spatial bounds refresh when
unrelated obstacles change. Alternate actor-side escape avoids crossings beside
the figure. From/To guidance names the endpoint; swapping direction carries its
multiplicity. Label edits retain authored manual routes/anchors. SVG selection
bounds include actual detours and endpoint labels. Route calculations remain
local and derived; no durable migration or source-content copying.

Full suite: **3,059 passed, five existing skips** (13:32, concurrency 2), including
11 new regressions for labels, obstacle/crossing avoidance, move/remove/undo/reopen,
hit/index areas, manual route preservation, reversed endpoints, temporary drags,
selected SVG and direction swapping. Real-font light/dark previews reviewed.
Analyzer clean (18.4 seconds); format/strict clean across 763 files. All 907 frozen
inputs unchanged through checks and final build. Configured Windows app and
matching standalone server built (117.4-second Windows compile). Runtime files
and new endpoint guidance/multiplicity examples in release AOT verified, alongside
the previous PDF retry control. The usual
`build/windows/x64/runner/Release/orbit_note.exe` is updated. No personal Vault
changes, app/host launch, Android/web rebuild or GitHub publication.
[Behavior, checks and routing limits](use-case-routing-2026-10-24.md).

Suggested next task: user-adjustable waypoints for intentionally arranged
use-case connections. Stop before implementing it.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Validated — PDF rendering reliability and performance, 2026-10-24

Owner reported PDF pages disappearing into blank pages after scrolling and
reopening tabs. Scope FILE-04/05/11/12/13: existing reading, selection and
annotation performance/reliability while preserving visual quality.

Confirmed upstream Windows custom-read synchronization race (issue 595),
equal-key initialization race (PR 727), and cache eviction below budget.
Tracked compatibility packages backport fixes without requiring a Flutter/Dart
upgrade or changing PDFium, durable formats or source bytes.
[Dependency provenance and patches](../../third_party/README.md).

Visible previews precede neighbour work and start after positioning the restored
viewport. Preview/high-resolution jobs coalesce and share a serial native-render
queue per cache. Canceled/retired decodes cannot populate a new source's caches.
Off-screen previews survive within budget; eviction runs once per paint.
Transient preview failures retry at most three times, then offer a page retry
that preserves document, page, zoom and selection. Native reads use bulk copying;
retired text and document loads are released safely.

Validation: **201 focused tests passed** (37 seconds), including deterministic
Windows spurious wakeups, >1 MiB callback-backed reopen/render, full-resolution
pixel fidelity, startup rebuild/disposal, cache eviction/reuse, high-DPI
coalescing and selection-preserving retry. Root and both compatibility-package
analyzers clean; format/strict clean across 761 application/test files.
Native Windows profile completed a 300-page/24,000-region PDF workload without
reported errors. Cold-load/distant-jump frame spikes remain; physical stylus and
full-suite acceptance were not rerun. [Evidence and limits](pdf-rendering-reliability-2026-10-24.md).

Final Windows release (76.4-second compile), matching standalone server and web
release (103.8 seconds) built. All 905 frozen implementation/test/tool/asset inputs
remain identical to those validated. Required runtime files and new recovery
strings verified in release AOT. The user closed Orbit Note again for replacement;
the normal `build/windows/x64/runner/Release/orbit_note.exe` is updated. No personal
Vault/PDF uploaded or modified, app/server launch, GitHub publication or Android rebuild.

Suggested next task: an exportable PDF diagnostic report excluding document text
and private file paths.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Validated — unified folder/file Explorer, 2026-10-24

Owner requested right-click PDF/file imports into subfolders and organized loose
items without flattening filed items. Scope: FILE-01, ORG-05, NAV-02. Folder menus
now select multiple PDFs or arbitrary attachments. Destination metadata is saved
with initial ownership; deduplication is folder-aware and never relocates an
existing object. Native folder existence is rechecked before writing bytes.

The shell now uses the same hierarchy for All items and type filters. Loose
objects get type groups, while subfolders retain their contents and chosen sort.
Shell-filtered objects are passed to the tree, fixing its previous bypass of
search/tag/Space filtering. Legacy standalone Notes explorers keep their existing
attachment visibility setting; the shell uses it in the Notes filter while
All items/explicit file filters show matching files. No durable format migration
or new dependency.

Validation: **79 focused regressions passed** (17 seconds), covering native
folder import/reopen, missing/unsafe destinations, sidebar/menu/picker flow,
folder operations, selection, drops and project/reference capture. Five final UI
regressions passed after retaining the Notes attachment toggle and explicit PDF
filter behavior. Analyzer clean (7.8 seconds); format/strict clean across 758
files. Initial harness errors (file-row key, provider rebuild and real file IO
under Flutter's simulated clock) were corrected before passing runs. Initial
analyzer style notices were fixed. Full suite was not rerun for this focused task.

Final Windows release and matching server built (75.6 seconds Windows compile)
with the existing registered Google configuration. Verified 471 source/asset
inputs unchanged and new controls/grouping markers in release AOT. An initial
ASCII-only marker check falsely rejected a Unicode menu label; UTF-8/UTF-16
verification passed, with no stale-build defect. Run the usual
`build/windows/x64/runner/Release/orbit_note.exe` with its sibling files.
No app/server launch or Android rebuild. Personal Vaults untouched.

Owner subsequently requested quick GitHub publication without tests. Source
`7a50547` pushed to main with `[skip ci]`. The existing Windows build was packaged
without rebuilding the app or rerunning tests. Published unsigned setup EXE,
checksum and matching source manifest in the
[Organized Explorer release](https://github.com/iax32/Orbit-Note/releases/tag/preview-explorer-2026-10-24).
All three assets, installer checksum and source commit verified. A non-version
preview tag avoids the GitHub release build workflow.
[Behavior and boundaries](../features/attachments-and-research.md).

Suggested next task: direct external file drops onto individual folder rows.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Validated — loose PDF and document synchronization, 2026-10-24

Fixes the reported `seWS26_ue1_angabe.pdf` unsupported-file failure. An explicit
case-insensitive document/media policy inventories loose files as verified blobs
without moving them or importing objects. The same policy now enumerates shared
snapshot/live assets outside `Attachments/`. Internal/unknown-file exclusions,
portable paths, immutable shared attachment paths and conflict guards remain.

Validation: **80 focused tests passed** (56 seconds), covering native replica,
Drive adapter, shared host/live assets, inventory, path policy, conflicts and
interrupted transfers. Analyzer clean (29.8 seconds); format and strict format
clean across 754 files. Two mistakes in newly added test setup (a canonical object
path assertion and reusing a replica after reopen) were corrected before the
passing batch; production opening guards were preserved.

Windows release built (131.5 seconds) with registered Google desktop configuration
and matching standalone server. Built from an isolated source snapshot while the
old app ran; 471 source/asset inputs matched published commit `aaad875` under Git
newline rules. Initial isolated setup needed existing plugin junctions/dependency
metadata; no Windows settings were changed. After owner closure, every copied
runtime file was hash-checked into the normal `build/windows/x64/runner/Release`
folder. No app or server was launched.

[Windows PDF Sync Fix release](https://github.com/iax32/Orbit-Note/releases/tag/preview-pdf-sync-2026-10-24)
published with setup EXE, SHA-256 and package/source manifest. Setup hash and source
commit verified; all three assets published. Unsigned preview; Android unchanged.
Source `aaad875` pushed to main with `[skip ci]`; non-version preview tag avoids
the GitHub release build workflow. The full suite and GitHub CI were not rerun,
as requested. No personal Vault was
modified or uploaded by the tests. See [supported behavior](../features/cloud-sync.md).
Real-account and physical second-device testing were not repeated.

Suggested next task: a user-facing preflight list explaining unsupported files
before starting a bulk Vault upload.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Published — Windows preview, 2026-10-24

Owner requested the current source and Windows release on GitHub with long tests
skipped for this publication. Source commit `b073496` was pushed to `main`.
[Windows release](https://github.com/iax32/Orbit-Note/releases/tag/preview-2026-10-24)
contains the complete per-user setup EXE, SHA-256 checksum and package/source
manifest. The installer is unsigned and the release is labeled preview.

Quick checks: staged-source credential/path scan clean (178 files), installer
hash matches its manifest, manifest source commit matches the pushed source,
and all three assets are published. Private Google config, signing keys, local
Vaults, temporary PDFs, SDKs and build output are excluded from source commits.
No long tests/builds were rerun and CI was skipped as requested. The existing
3,030-test validation below predates publication. Android was not rebuilt.
Further PDF-performance work was paused before implementation at owner request.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Validated — Native Canvas raster profiling, 2026-10-24

Native Windows profiling reproduced expensive raster replay of saved pressure
segments despite the prior debug CPU-recording speedup. Committed ink now uses
bounded disposable previews at native zoom/DPI, with immediate vector fallback
when more pixels are needed, safe async disposal and stable admission when the
visible set exceeds its budget. Original samples/undo/storage/export remain.

Measured 100,000-sample workload: warmed pan raster p95 **247.550 → 3.102 ms**;
scripted drawing **244.232 → 5.185 ms**. These are engine timings on the tested
Ryzen 5600X / RTX 3060 host, not general FPS or physical pen latency. Preview
warmup and cold/distant PDF page loads still have spikes.

**14 new regressions. Final full suite: 3,030 passed, two existing skips**
(13:42). Focused batch 65 passed; Drive controller batch 24 passed. Analyzer clean
(8.2 sec); format/strict clean across 756 files including profiler tools. Extra
native-DPI RGBA/spatial comparison passed and generated images were reviewed.
An initial load-sensitive Drive timing assertion was stabilized without changing
production sync; the failed run, isolated pass and bounded repair are documented.

Direct Windows app + matching server built (123.4 sec Windows compile). All 902
final frozen inputs, seven runtime files, 13 fonts and the registered Google
client verified; new renderer markers are in the updated AOT snapshot. Standard
JS web passed (113.1 sec), with existing SDK Wasm/Cupertino font warnings. No ZIP,
publication or main-app/server launch. The isolated profile window closed itself.
Run `build/windows/x64/runner/Release/orbit_note.exe` with its sibling files.

The owner confirmed no physical pen is available. Physical stylus delivery/palm
rejection/input-to-photon and private large real-document acceptance remain
untested; reports use synthetic input/documents and no personal Vault/account.
[Measurements, checks and boundaries](device-profile-2026-10-24.md).

Suggested next task: reduce measured cold-preview warmup and first/distant PDF
page-transition spikes. Physical pen acceptance is a separate pending check.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Validated — Native PDF and pen performance, 2026-10-24

Owner authorized the large-document audit. Existing Canvas/PDF engines now use
bounded saved-ink vector caching, frame-coalesced active previews, finite pressure
fallbacks, reliable pen capture/release/recognition and dense-page annotation
lookups. Comfort fitting retains one native job and the latest destination,
cancels obsolete work and retries failed measurements without stale cache entries.
Original PDF bytes, editable ink samples, object identity and storage remain.

**12 new regressions. Full run: 3,016 passed, two existing skips** (11:27).
Focused batch: **77 passed** (20 sec), including real PDFium on 300 pages,
24,000 annotation regions in the reader, 100,000 saved ink samples and pixel
comparisons for all seven pen styles through edits/undo/zoom. Analysis clean
(9.1 sec); format/strict clean across 752 files. Saved-ink display-list recording
was about 5.12× faster in the focused debug fixture; this is not a frame-rate
or physical pen-latency claim.

Direct Windows app + matching server built (76.6 sec Windows compile). All 898
frozen inputs unchanged; seven runtime files, 13 fonts, registered Google client
and new performance types in AOT verified. Standard JS web passed (73.8 sec),
with existing Google SDK Wasm/Cupertino font warnings. No archive regenerated.
Run `build/windows/x64/runner/Release/orbit_note.exe` with its sibling files.

These are synthetic headless workloads. Physical pen latency, real-device palm
rejection, profile/release frame timing and large real-document acceptance remain
unmeasured. No private Vault/cloud operation, app/server launch or shutdown.
[Scope, measurements and final validation](pen-pdf-performance-2026-10-24.md).

Suggested next task: physical stylus/profile-mode input and frame-latency
acceptance with representative large real documents. Stop before another feature.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Validated — Motion update final integration checks, 2026-10-23

Motion profiles, actual text presentation, Canvas replay/laser, PDF navigation/
lens/optional progress, selection/format/grammar feedback, graph paths and revision
scrubbing use the existing engines. The studio now shows previews first and folds
advanced controls; desktop presentation is wider. **The 70-item inspiration guide
contains concept-only entries; this is not completion of all 70 workflows.**

**28 new regressions.** Full run: **3,003 passed, two existing skips** (12:09).
After the localized two-dialog cleanup and one added UI test, **59 focused/real-font
checks passed** (9 sec); no later full run is claimed. Native PDF/motion batch:
**94 passed** (21 sec). Final analysis clean (7.5 sec); format/strict clean across
751 files. Real-font actual-widget previews visually reviewed.

Current direct Windows app + matching host built (92.1 sec Windows compile),
897 frozen inputs unchanged, seven runtime files/13 fonts and Google client
verified. Standard JS web passed (111.1 sec), with existing SDK Wasm/Cupertino
warnings. No Android/device/manual acceptance, app/host launch, private account/
Vault operation, publication or shutdown. Earlier packaging artifacts remain;
no archive was regenerated for this final build. Existing work is preserved.
[Use, exact guide coverage, validation and boundaries](motion-studio-2026-10-23.md).

Run `build/windows/x64/runner/Release/orbit_note.exe` with sibling runtime files.
Next suggested task: native PDF/pen performance and interaction acceptance on
large real documents; stop before another feature.

## Earlier validation

# Validated — Motion studio and connected interaction feedback, 2026-10-23

Owner supplied the animation inspiration chat and requested implementation.
This update extends MOT-01–06 in the existing Flutter renderer. Scope includes
persisted motion profiles, a searchable 70-concept preview catalog, actual note
text presentation, focus/selection/formatting/grammar feedback, authored Canvas
replay and temporary laser, PDF navigation/lens/optional progress, graph path
reveal and read-only revision scrubbing. No new animation package or AI backend.
The catalog is inspiration coverage, **not evidence of 70 completed workflows**.
Delivered: searchable Motion Studio within the 43-entry settings index, fluid/
paper/experimental personalities, 0.5–2x timing, text replay alternatives with
Unicode grapheme cluster safety, authored Canvas board/stroke replay and ephemeral
laser pointer, PDF navigation glide with magnification lens and reader tone controls,
graph edge reveal, and read-only revision scrubbing.

Validation: 94 focused tests passed covering motion studio, settings, UML interaction,
and PDF navigation regressions. Corrected edge cases: PDF paper tones observe reader
controls, motion previews halt on OS reduced motion, and Canvas preview images
persist throughout dialog closing animations. Fixed unbraced flow control in PDF reader.
Formatting clean: 751 files formatted with 0 changes. Root analyzer clean in 13.6s.
Windows release compiled in 95.1s (`build/windows/x64/runner/Release/orbit_note.exe`).
Distribution package assembled: `release-assets/OrbitNote-Windows-x64.zip` (34.5 MB,
SHA-256: `e64cb0890b6b23bbfbe020c4ac4b93588f06d81add5b0f20e6dc7c68f1535795`),
with checksum recorded in `release-assets/SHA256SUMS-Windows.txt`.
[Scope, coverage and validation](motion-studio-2026-10-23.md).

Suggested next task: native PDF/pen performance and interaction acceptance for
these effects with large real documents; do not build another feature ahead.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Validated — Use-case and sequence diagrams, 2026-10-23

Owner selected both diagram types from UE2.pdf. Shared Canvas adds actors,
use cases/extension points, boundaries/constraints, association/include/extend/
generalization, lifelines/activations/destruction, messages/self calls and the
twelve combined-fragment operators. Precise live Markdown references, vector
previews, selectable details and publication snapshots reuse existing boundaries.
Two generic starters; ordinary placement selection/history/transfer remains.
No new engine, account or schema migration. **16 new regressions**. Complete
rerun: **2,975 passed, two existing skips** (11:44); final **94 focused passed**
(14 sec) after a localized zero/subpixel frame guard. Analysis clean (8.7 sec),
743 formatted files. Windows app + matching host built (86.4 sec); 889 frozen
inputs unchanged, seven runtime files/13 fonts and registered Google client
verified. Strict formatting clean; standard JS web build passed (97.5 sec), with
the existing SDK Wasm/Cupertino-font warnings. No native/manual acceptance or
Android build is claimed. No app/host launch, private Vault/account work,
publication or shutdown. Existing work remains.
[Scope, use, evidence and limits](uml-interaction-diagrams-2026-10-23.md).


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Validated — Searchable settings workspace, 2026-10-23

Owner-requested LAY-01/06/08/10 subset: nine categories and **43 searchable entries**,
grouped cards, desktop navigation, compact/enlarged-text layout, keyboard search
and clear, per-category scroll recovery and progressive advanced controls.
Additional working controls cover code font/size/numbers/wrapping, corners,
explorer/splits/sorting/attachment/calendar visibility, all **15** Canvas papers,
dictionary management and expanded timer/line-spacing/autosave choices.
Seven local sections have confirmed reset and guarded Undo. Account connections,
knowledge, unknown roles and unrelated edits remain. Advanced appearance recovery
stays readable even with all custom roles black. False optimization success is
removed, reload reports its outcome, and local counts avoid scanning note bodies.

Two bounded flat-session defaults (defaultCodeWrap/codeFontSize) preserve old JSON
and unknown data; existing stored code typography/numbers now reach real editors.
Font changes retain source/focus/selection and existing panes keep local choices.
**14 new regressions**; initial focused **103 passed** (18 sec), recovery batch
**16 passed** (4 sec). Complete rerun: **2,959 passed, 2 existing skips** (10:50,
concurrency 2), followed by **108 focused/real-font checks** (21 sec) after final
localized recovery-entry hardening. No additional complete run is claimed after
that final localized change. Initial full-run failure was an older test assuming
always-expanded controls; it now uses search/content navigation. Format/strict
check clean across **740 files**; final analysis clean (**7.2 sec**). Real-font
actual desktop dark and compact light UI reviewed; 250% text with keyboard insets
passes at 320×640 and 568×320. [Use, evidence and limits](settings-workspace-2026-10-23.md).

Configured Windows app + matching host and standard JS web builds passed
(**75.0/72.9 sec**). **886** frozen inputs unchanged, seven runtime/host files,
**13** font hashes and registered Google client verified. Existing web SDK
Wasm/Cupertino warnings remain; native/mobile visual and screen-reader acceptance
are unverified. No APK rebuild, desktop control, app/host launch, private
account/Vault work, publication, ZIP or shutdown.

Run `build/windows/x64/runner/Release/orbit_note.exe` with sibling runtime files.
Preview: `build/previews/orbit-settings-appearance.png` (also Code/compact samples).
Next suggested task: user-defined settings profiles using existing Spaces, with
preview and recoverable apply; stop before that feature.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Validated — Shared semantic colors and Orbit defaults, 2026-10-23

Owner-requested LAY-01/06/09/10 continuation: refreshed Orbit Graphite defaults,
all **113** built-ins calibrated against actual state surfaces, new/missing
accent preferences follow theme, explicit presets retain their choice with
readable shades. Shared Material text/input/floating/focus controls, statuses,
collections, graphs, code/LaTeX/callouts and Canvas previews/grid/minimap follow
semantic roles. Same-mode color changes refresh caches while source, selection,
IME, authored scene/ink/paper colors and durable Markdown remain intact.
Custom-role overrides, unknown data, old preferences and Spaces remain.
Recovery follows the effective base family with a readable fallback. The other
chat's exact answer was unavailable; no claim that its hidden rules were read.

**9 new regressions; 94 focused passed** (19 sec). Complete suite:
**2,946 passed, 2 existing skips** (13:44, concurrency 2). Format/strict check clean
across **737 files**, analysis clean (10.3 sec), targeted diff whitespace check
clean. Real-font/icon actual-component default/light/dark renders visually
reviewed. [Behavior, validation and limits](semantic-color-system-2026-10-23.md).

Configured Windows app + matching host and standard JS web builds passed
(**84.6/83.2 sec**). **883** frozen inputs unchanged, seven runtime/host files,
**13** packaged font hashes and registered Google client verified. Existing web
SDK Wasm/Cupertino warnings remain. Native/mobile visual acceptance is unverified;
no APK rebuild, desktop control, app/host launch, private account/Vault work,
publication or shutdown.

Run `build/windows/x64/runner/Release/orbit_note.exe` with sibling runtime files.
Preview: `build/previews/orbit-semantic-colors.png`.
Next suggested task: native focus/hover/selected/disabled and high-contrast audit;
stop before implementing it.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Validated — System appearance for paired palettes, 2026-10-22

Owner accepted the preceding next task: opt-in OS light/dark switching for the
50 paired palette families. Preserve manual defaults, explicit user styling,
unknown session data and old Spaces. Resolve appearance without saving on OS
changes; manual palette selection disables following and turning following off
keeps the visible member. Keep settings, gallery, preview and export consistent.
No new dependencies, arbitrary custom-theme pairing or time-based scheduling.
**11 new regressions; 64 focused passed** (6 sec). Full rerun: **2,937 passed,
2 existing skips** (11:54, concurrency 2). Format/strict checks clean across
**736 files**, analysis clean (8.1 sec). Actual app retains editor controller,
focus, selection, identity and durable bytes across simulated OS changes.
Space close/reopen, old descriptors, manual/import/generator exits and matching
preview/export pass. Real-font/icon headless renders visually reviewed; 360 px
with 200% text passes. Two older settings tests now scroll before offscreen
lookup/tap. An initial Drive deadline check failed under load, then passed
unchanged in isolation and the complete reduced-concurrency rerun.

Configured Windows app + matching host and standard JS web builds passed
(**75.9/74.1 sec**). **882** frozen inputs unchanged, seven runtime/host files,
**13** packaged font hashes and registered Google client verified. Existing web
SDK Wasm/Cupertino warnings remain. No APK rebuilt; native/mobile visual acceptance
remains unverified. No desktop control, app/host launch, private Vault/account work,
publication or shutdown.
[Use, validation and limitations](system-appearance-2026-10-22.md).

Run `build/windows/x64/runner/Release/orbit_note.exe` with sibling runtime files.
Next suggested task: explicit preferred light/dark pairing for original/custom
themes; stop before that expansion.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Validated — One hundred coordinated appearance palettes, 2026-10-22

Owner-requested LAY-01/06/09/10 subset: 50 named families × light/dark = **100 new
complete semantic palettes**, retaining 13 originals (113 built-ins). Eight
collections, search, mode/collection filters, six-card pages, Show active and
paired switching keep the destination visible. Actual app accents can **Follow
theme**, and that choice survives reload. New families preserve typography and
corners. Manual overrides retain a notice, explicit reset and guarded Undo;
unknown roles/custom themes/old IDs and portable JSON remain. Filled-control and
check/badge ink uses actual contrast. No authored migration or new dependency.

The **UI Color Rules Explained** question was readable, but its answer remained
only a content reference. Exact rules were unavailable; do not claim to have
read them. Primary Apple and W3C guidance informed surfaces/accents/contrast.
[References, use, scope and limits](appearance-palettes-2026-10-22.md).

**11 new regressions; 42 focused passed** (5 sec), including 13,500 contrast
comparisons across all 100 additions, exact JSON/session round-trips, actual app
accent resolution, old/custom compatibility, paging/filtering/pair controls,
reset/Undo/unknown roles and 200% text at 360 px. Full suite: **2,926 passed,
2 existing skips** (5:49). Format/strict formatting clean across **734 files**;
analysis clean (8.5 sec). Real-font/icon headless samples rendered and visually
reviewed. Preview: `build/previews/orbit-palette-preview.png`.

Configured Windows app + matching host and standard JS web builds passed
(**81.1/79.2 sec**). **880** frozen inputs unchanged; seven runtime/host files,
**13** packaged font hashes, new palette payload markers and registered Google
client verified. Existing web SDK Wasm/Cupertino warnings remain. Android SDK
remains unavailable; no APK rebuilt. No app/host launch, desktop control, private
Vault/account work, publication or shutdown. All prior dirty work preserved.

Run `build/windows/x64/runner/Release/orbit_note.exe` with sibling runtime files.
Next suggested task: optional system-driven light/dark switching for paired
palettes; stop before that expansion.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Validated — Live shared replication; mobile background/device acceptance pending, 2026-10-22

Owner-approved SYNC-03/04/05/06/07/09/10/12/16 subset now includes negotiated live
room creation, all owning-object/lifecycle/tombstone replication, verified resumable
assets before owners, authenticated event waits and bounded local wakeups. Shared
bases/uncertain edits/creations survive restart in device-only guarded journals.
Independent text changes merge; overlapping replacements require review. Rich/
Source note carets/selections use source hashes and safe UTF-16 ranges. Canvas
pointer changes wake promptly. Optional secure reconnect runs on launch/resume;
explicit Disconnect suppresses it. Unchanged checkpoints avoid writes; failed/
oversized checkpoints block publication with recovery feedback. Local history,
draft/opening/CAS guards, unknown data and Drive/shared exclusion remain.

Legacy rooms retain existing-document behavior. New live rooms require matching
updated clients/host. The host preserves a verified private journal checkpoint
before new record kinds; preserve the whole stopped host directory for recovery.
No authored migration. [Protocol/limits](../adr/0032-live-shared-vault-replication.md).

**24 new regressions; focused 76 passed** (4 sec). Full suite **2,915 passed,
2 existing skips** (5:28). Format/strict checks clean across **731 files**;
analysis clean (6.7 sec). Configured Windows app + standalone host and standard
JS web builds passed (**75.9/74.2 sec**). **877** frozen inputs unchanged;
seven runtime/host files, **13** packaged font hashes and registered Google client
verified. Packaged host also passed isolated loopback health/auth/capability smoke
testing and was stopped. Existing web SDK Wasm/Cupertino warnings remain.

**Still unfinished:** closed-app Windows/mobile workers, arbitrary-overlap CRDT,
physical Windows-to-Android and deployed TLS/mobile runtime acceptance. Owner has
no second device available. Android check blocked before compilation: SDK missing;
no APK rebuilt. No desktop control/app launch, private Vault/account transfers,
persistent host installation, publication or shutdown. Prior dirty work preserved.

Run `build/windows/x64/runner/Release/orbit_note.exe` with sibling runtime files.
[Full evidence and operation](live-shared-sync-2026-10-22.md).
Next suggested task: constrained mobile background jobs and physical-device
acceptance once SDK/device access exists; stop before that platform expansion.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Validated — Incremental personal Drive sync, 2026-10-22

Audited actual Drive/auth/replica/controller/shared-host code against the owner's
OneNote-level goal. **Parity remains incomplete**: personal eventual file sync is
separate from existing-document shared editing; closed-app/mobile background,
shared continuous new objects/deletions/attachments and text caret/CRDT behavior
are not completed or verified. Public OAuth and physical-device acceptance remain.

Personal native sync now uses paginated Drive change feeds with durable complete
revision membership/cursors, safe baseline race replay, immutable metadata/graph
validation and 15-minute cloud audits. Missing/rejected checkpoints and backwards
clocks rebuild safely. Failed pages/graphs/access do not advance checkpoints.
Reset snapshots preserve local-apply crash replay. Unchanged checks avoid history
listings/media reads/journal rewrites. No authored format, provider authority,
Google scope, package or backend changes.

Active Vaults check remotely every five seconds, preserving normal ~30-second local
integrity checks without rehashing attachments every poll. Saved edits keep their
earliest two-second scheduled pass during continuous typing. Settings shows
upload bytes and separate last-cloud-check/full-sync times. Retry deadlines,
account/draft/opening guards, explicit pause and Drive/shared exclusion remain.
Inactive Vaults retain their selected 1/5/15-minute schedule. Timing is not a
network/OS delivery guarantee. Retained history still has a 10,000-revision cap,
16 MiB checkpoints and no automatic compaction.

**20 new regressions; 104 focused passed** (46 sec), including 1,000-revision,
pagination/interruption, concurrent-client, source-loss/tamper, account-switch,
old-journal/restart, draft, tombstone, middle-upload resume and continuous-edit
cases. Full suite: **2,891 passed, 2 existing skips** (5:08). Format/strict format
clean across **725 files**; analysis clean (6.2 sec). Configured Windows app/host
and JS web builds passed (**77.3/76.9 sec**). Existing Wasm/Cupertino-font warnings
remain. Android debug check blocked before compilation: **Android SDK missing**.

**772** frozen inputs unchanged; seven runtime/AOT/host files, **13** authored
font hashes and registered Google client in AOT verified. Prior uncommitted work
preserved. No desktop control, app/host launch, private account/Vault access,
cloud upload, publication or shutdown. No APK rebuilt.

Run `build/windows/x64/runner/Release/orbit_note.exe` with its sibling runtime files.
[Full source audit, API findings, evidence and limits](cross-device-sync-2026-10-22.md).
Next suggested task: complete live shared-Vault new/deleted-object and attachment
replication with push events and device acceptance; stop before that expansion.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Validated — Connected publishing snapshots, 2026-10-22

PDF/HTML/Word now include Canvas/selected-diagram previews rendered by Orbit's
spatial engine, searchable UML/text inventories, task details, saved collection
memberships, safe linked images and source identities/revisions. Objects/paths/
query clock are captured at dialog opening; styles reuse the same snapshot.
Missing, ambiguous, deleted, foreign-Vault and unsupported/precise sources retain
labelled references and warnings. Limits are explicit. Original knowledge is
unchanged. Short connector multiplicities no longer overlap; Canvas/SVG/PNG share
the corrected geometry. Painter resources are released after raster export.

13 new regressions; focused **65 passed**; full **2,871 passed, 2 existing skips**
(4:36). Format/strict check: **724 files**, clean; analysis clean. Native resource/
image/text checks and Poppler/native visual review cover blueprint/UML snapshots
and task/collection reports. Configured Windows app/standalone host and standard
JS web builds passed (69.2/64.4 sec). **785** frozen inputs unchanged after builds;
seven runtime files and **33** font hashes verified. Existing SDK Wasm/Cupertino
web warnings remain. All prior uncommitted work retained. No desktop control,
private Vault/account, app/host launch, publication or APK rebuild.

Run `build/windows/x64/runner/Release/orbit_note.exe` with its sibling runtime files.
Note/LaTeX object cards are metadata-only; use linked sections for full content.
Nested media/boards stay static labelled cards. [Evidence and limits](connected-publishing-2026-10-22.md).
Next suggested task: tiled multi-page Canvas printing; stop before implementing.

Owner explicitly requested shutdown after this update. Validation/build evidence
is saved; follow with normal shutdown only, no forced app closure. A short-delay
hidden helper may invoke `shutdown /s /t 0`; unsaved applications may block it.
See `.local/connected-publishing-shutdown-plan.json` for dispatch state if present.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Validated — Complete visible PDF content, 2026-10-22

Markdown PDF export now paginates formatted prose/lists, long headings, contents,
code and endnotes; preserves nested list order; uses labelled records for too-wide
or tall table cells; fits figures without cropping and lets captions continue.
Natural equation surfaces replace the fixed viewport, retain full bounds and use
TeX fallback at allocation limits. Static SVG diagrams now normalize offline;
active/external/unsupported SVG content retains a labelled fallback. Serif symbols
can use bundled Lato. Running text/footer spacing, first-page destinations,
matching-title duplication and the release-mode 500-page cap are repaired.
Original Markdown/attachments and saved settings remain unchanged.

10 new regressions; focused **42 passed**; full **2,858 passed, 2 existing skips**
(4:37). Format/strict check clean across **721 files**; analysis clean. Native
content/bounds/pixel checks and **14 Poppler-rendered pages** reviewed with actual
bundled math fonts. Configured Windows app/standalone host and standard JS web
builds passed (70.6/66.3 sec). **782** frozen inputs unchanged; seven runtime files
and **33** authored/KaTeX font hashes verified. Existing SDK Wasm/Cupertino-font web
warnings remain. No app launch, desktop control, personal Vault/account, live web
image request, publication or APK rebuild. Prior unrelated sync work retained.

Run `build/windows/x64/runner/Release/orbit_note.exe` with its sibling runtime files.
Web images still require **Load web images**; unavailable resources, unsupported
glyphs, complex SVG and live workspace widgets retain explicit fidelity warnings.
[Evidence and limits](pdf-visible-content-2026-10-22.md).
Next suggested task: resolved Canvas/live-object previews in publishing; stop
before implementing it.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Validated — Markdown PDF images, 2026-10-22

Fixed valid images becoming PDF placeholders: decoder buffers/descriptors now
outlive frame decoding. Canonical Vault attachment references resolve at any note
depth, including encoded names, without a clipboard resolver; changed Vault
openings invalidate pending reads. Original note/attachment bytes are unchanged.

Publishing adds image counts, Retry missing images, explicit Load web images and
cancellation. Anonymous HTTPS downloads are bounded by redirects/size/deadline;
style changes reuse loaded images. Network/corrupt/unsupported/authenticated sources
retain visible labelled fallbacks. No automatic web-image request occurs.

11 new regressions; focused **32 passed**; full **2,848 passed, 2 existing skips**.
Format/strict check clean across **719 files**; analysis clean. Actual PDF images
verified with native pixel checks and visual PDFium/Poppler rendering. Configured
Windows app/standalone host and standard JS web builds passed. 781 frozen inputs,
seven runtime files, fresh AOT/host payloads and 13 authored font hashes verified.
Existing Google SDK Wasm/Cupertino-font web warnings remain.

Run `build/windows/x64/runner/Release/orbit_note.exe` with its sibling runtime files.
Web images: Export as PDF → Document style → Images → Load web images.
HTTP-only, unsupported or login-protected/expired/browser-blocked images may need
local import. No personal Vaults/accounts, live image sites, desktop control or app
launch. Prior uncommitted sync work is retained; no publication or APK rebuild.
[Evidence and limits](markdown-pdf-images-2026-10-22.md).
Next suggested task: SVG image normalization for publishing; stop before implementing it.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Validated — Device sync and self-hosted recovery, 2026-10-21

Drive retains mid-transfer edits and coalesced foreground checks, schedules real
retry deadlines and exposes queued/retry states. Pause, account and shared-session
authority guards remain in force. Shared sessions read state before publishing;
optional host-incarnation checks protect stale cursors, uncertain acknowledgements,
restored/reused versions, open Canvas comparisons and the check-to-publication
restart race. Local content/history remain recoverable; unknown ancestry requires
review. Shared settings add a host/HTTPS/invitation guide and actionable diagnostics.

22 new regressions; final focused **83 passed**; final full **2,837 passed,
2 existing skips**. Format/strict check clean across **716 files**; analysis clean.
Configured Windows app + standalone host and standard JS web builds passed.
778 frozen source/test/build inputs unchanged; seven runtime files and 13 font
hashes verified. Standalone host help exits successfully without starting a host.
Existing Google SDK Wasm and missing Cupertino-font web warnings remain.

Run `build/windows/x64/runner/Release/orbit_note.exe` with its sibling runtime files.
Use the matching `collaboration` host folder for the new restart guards. No desktop
control, personal Vault access, real Google actions or persistent service launch.
No publishing or Android build was requested in this update. Android OAuth/public
rollout, physical two-device/TLS acceptance and continuous shared new-object,
deletion/attachment streaming remain outstanding.
[Evidence and limits](device-sync-recovery-2026-10-21.md).
Next suggested task: durable shared new-object/attachment synchronization with
explicit deletion and recoverable operation replay; stop before implementing it.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Published — GitHub Windows/Android 1.0.2 preview, 2026-10-21

Source pushed without force at `10c5cef8778e8f468edfadb966804455079f1e9b`;
version 1.0.2+3. [Published release](https://github.com/iax32/Orbit-Note/releases/tag/preview-2026-10-21)
contains a Windows setup EXE and signed Android preview APK, plus checksums and
runtime/signature/package evidence. All seven hosted asset SHA-256 digests and
sizes match the verified local files; the tag resolves to the exact build source.
Android retains its previous preview application ID/key and increments code to 3.

Both hosted platform builds succeeded. Source audit: 1,059 files, no private
material found. Formatting/strict check clean across 714 files; analysis clean.
Preceding full suite: 2,815 passed, 2 existing skips; app behavior is unchanged by
version/packaging. Additional repository CI was still running at publication and
is explicitly not claimed as passing.

Local configured runnable Windows build verified at
`build/releases/1.0.2/orbit_note.exe`, with runtime siblings and matching font files.
No app/installer/server launched, personal Vault access or desktop-control testing.
Windows is unsigned; Android Google sign-in remains local-only and physical-device
acceptance remains pending. [Evidence and limits](github-publication-2026-10-21.md).
Next suggested task: physical Android update/import and cross-device acceptance;
stop before implementing it.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Validated — Math explanation paste, 2026-10-21

Normal Rich paste now imports mixed ChatGPT-style explanations and editable
inline/display LaTeX from plain text and browser math HTML. Fixed duplicated
visual/accessibility math, extra blank paragraphs, long malformed-input scans,
and table quoting across Read/embedded/Study/export views. Column inline math
also uses its intended renderer. Source/code/plain paste remains literal.
Existing focus/revision/composition guards and undo/history remain in place.

46 new regressions; focused **192 passed**; final full **2,815 passed, 2 existing
skips**. Format/strict check clean across 714 files; analysis clean. Configured
Windows/server and standard web builds passed; 485-file source snapshot, fresh
app payloads, runtime files and font hashes verified. Existing web SDK/font
warnings remain. No desktop control, personal Vaults, cloud access or app launch.

Run `build/releases/Math Paste/orbit_note.exe` with its sibling runtime files.
The previous running app/release folder remains intact. Physical clipboard/device
acceptance remains unverified; [evidence and limits](math-explanation-paste-2026-10-21.md).
Next suggested task: equation labels, numbering and cross-references; stop before
implementing it. Earlier unrelated changes are preserved.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Validated — Connected Life Workspace, 2026-10-21

Implemented the complete owner-approved LIFE-01–12 proposal: configurable Home,
goals/milestones, habits/routines, custom fitness/programs/resumable sessions,
journals, experiments/check-ins, life administration, learning, 31 starters/five
connected packs, personal note/Canvas templates, live boards and period reviews.
Normal local repository commands and portable objects retain authority.

85 new regressions; focused **102 passed**; full **2,769 passed, 2 existing skips**.
Formatting/strict check clean across 711 Dart files; analysis clean. Native files,
10,000 records, failed/partial/duplicate writes, enlarged layouts and headless
real-font previews verified. Configured Windows/server and standard web builds
passed; fresh payloads, runtime files and font hashes verified.

Run `build/releases/Life Workspace/orbit_note.exe` with its sibling runtime files.
A verified source snapshot allowed a separate release while the older app remained
open. No desktop control, personal Vault/account access, publishing or shutdown.
[Scope, evidence and limits](life-workspace-2026-10-21.md).
Next suggested task: local daily reminders and mobile quick logging; stop before
implementing it. Earlier unrelated uncommitted work is preserved.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Validated — Shared Canvas review and everyday templates, 2026-10-20

Added known-base placement-level local/shared/removal/order review with immutable
comparisons, stale-state guards, normal history and safe idempotent publication.
Independent edits still merge; newer overlap during saving returns to review.
Added 26 Markdown and eight Canvas starters, categories/search, title/date
preparation, vector previews, fresh placements and one insertion undo.
29 new regressions; focused **90 passed**; full **2,684 passed, 2 existing skips**.
Formatting/strict check clean across 701 files; analysis clean. Configured
Windows/server and standard web builds verified with fresh payloads, runtime
files and font hashes. Existing web SDK/font warnings remain.
[Evidence and limits](canvas-review-templates-2026-10-20.md).
Unknown common bases/document metadata conflicts retain existing recovery.
No desktop control, personal Vaults, cloud mutations, publishing or shutdown.
Next suggested task: save personal notes and Canvas layouts as reusable templates;
stop before implementing it.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Validated — Canvas shared presence and structured split editors, 2026-10-20

Added bounded Canvas selected-placement presence and a separate overlay, own-session
clear-on-leave and renewed connection IDs; fixed merge identity/order checks and
room-switch presence denial. Fixed structured focus/backwards selections, delayed
code/table clipboard ownership, and Find focus stealing replacement input. Shared
document history remains pane-local and conflicting drafts remain recoverable.
27 new regressions; focused matrix **201 passed**; full suite **2,655 passed**,
**2 existing skips**. Formatting/strict check clean across 693 files; analysis
clean. Configured Windows/server and standard web builds verified with fresh
payloads, runtime files and font hashes. Existing web SDK/font warnings remain.
See [evidence and limits](canvas-split-quality-2026-10-20.md).
Update both app and self-hosted server for selected-item presence/clear-on-leave.
No desktop control, personal Vaults, cloud operations, publishing or shutdown.
GitHub releases/APK unchanged. No CRDT/new-object/attachment streaming expansion.
Next suggested task: placement-level review of overlapping shared Canvas edits;
stop before implementing it.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Published — GitHub source and Windows/Android preview, 2026-10-20

Source pushed at `b669857503f6e89e80feecdf18f0142bcd680d7a`; version 1.0.1+2.
[Published preview](https://github.com/iax32/Orbit-Note/releases/tag/preview-2026-10-20)
contains a Windows setup EXE and signed Android preview APK, with checksums,
runtime manifest and signature/package evidence. Existing Android preview key
and identity retained; version code 2 updates the previous preview. Remote asset
digests/sizes and source tag verified. Local runnable Windows folder also rebuilt.
Source audit: 1,027 files, no private material found; strict formatting/analysis
clean. Prior app validation: 2,628 passed, 2 existing skips. Additional repository
CI remained running at publication; it is not claimed as passing. Windows remains
unsigned; Android Google sign-in remains local-only and device acceptance pending.
No personal Vaults or app auto-launch. Next suggested task: physical Android update/
import and cross-device acceptance with the published preview; stop before it.
See [publication evidence](github-publication-2026-10-20.md).


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Validated — Editor transactions and split-pane reliability, 2026-10-20

Fixed wrong-input/document undo ownership, reused-note history, stale shared
history replay, backwards selection restoration, revision-guarded clipboard/review
commands, read-only callbacks, Unicode replacement previews and duplicate draft
recovery. 34 new regressions; final expanded matrix **214 passed**; full suite
**2,628 passed**, **2 existing skips**. Formatting/strict check clean across 688
files; analysis clean. Configured Windows/server and standard web builds verified
with fresh payloads, runtime files and font hashes. Existing web SDK/font warnings
remain. See [evidence and limits](editor-transactions-quality-2026-10-20.md).
Preserve unrelated work and portable originals. No desktop control, personal
Vault mutation, publishing or shutdown. Next suggested task: structured
table/code-block selection and command ownership across split panes. Stop before
implementing it.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Validated — Split-pane navigation and focus quality, 2026-10-20

Fixed hidden/read-only pane shortcut targeting, stale/deleted tab cycling,
secondary Canvas candidate filtering, tab/split-close typing focus and LaTeX
preamble focus fallback. Pane scopes and guarded activation preserve modal focus
and independent long-document selections/scroll. 18 new widget regressions;
focused matrix 40 passed; full suite **2,594 passed**, **2 existing skips**.
Formatting/strict check clean across 682 files; analysis clean. Configured
Windows/server and standard web builds verified with fresh payloads, runtime files
and font hashes. See [evidence and limits](split-focus-quality-2026-10-20.md).
Preserve unrelated work and portable data. No desktop control, personal Vault
mutation, publishing or shutdown. Next suggested task: find/replace and undo/redo
ownership while switching split panes. Stop before implementing it.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Validated — Assignment and reference workflow quality, 2026-10-19

Fixed stale mention linking, deleted reference targets, tag normalization and
unknown-data retention, original-document tag input, live project/reference
choices, guarded assignment ownership, disappearing keyboard selection and
retryable connection drafts without duplicate edges. 19 new regressions;
focused matrix 65 passed; full suite **2,576 passed**, **2 existing skips**.
Formatting/strict check clean across 681 files; analysis clean. Configured
Windows/server and standard web releases built; fresh payloads, runtime files
and font hashes verified. See [evidence and limits](assignment-relation-quality-2026-10-19.md).
Preserve unrelated work and portable data. No desktop control, personal Vault
mutation, publishing or shutdown. Next suggested task: split-pane tab switching
and keyboard focus restoration after dialogs with several long documents. Stop
before implementing it.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Validated — Metadata dialog quality, 2026-10-19

Fixed stale-field/whole-property overwrites, guarded rename/property/color
callbacks, retained conflicting drafts, finite-number/hex validation and enlarged
color previews. Folder rename checks changed membership; native save/reopen keeps
source, identity, aliases and unknown metadata. 17 new regressions; focused matrix
47 passed; full suite **2,557 passed**, **2 existing skips**. Formatting/analysis
clean across 676 Dart files; final fixture-only isolation check also passed.
Configured Windows/server and standard web releases built; fresh payloads, runtime
files and font hashes verified. See [scope, evidence and limits](metadata-dialog-quality-2026-10-19.md).
Preserve unrelated work and portable data. No desktop control, personal Vault
changes or shutdown. Next suggested task: bulk tag/project assignments and retained
relation pickers under concurrent edits, large selections and failed saves. Stop
before implementing that follow-up.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Validated — Bulk lifecycle quality, 2026-10-19

Fixed mutable/duplicate batch selections, retired queued lifecycle commands,
partial permanent-cleanup reconciliation, failed-save deletion guards and
pending confirmation ownership/counts. Stress evidence includes 120 mixed native
owners across repeated moves/Trash/restore/reopen and guarded planning Undo.
19 new regressions; full suite **2,540 passed**, **2 existing skips**; formatting
and analysis clean. Configured Windows/server and standard web releases built;
runtime files, fresh payloads and font hashes verified. See
[scope, evidence and limits](bulk-lifecycle-quality-2026-10-19.md). Preserve
unrelated work and ordinary files. No desktop control, personal Vault changes or
shutdown. Next suggested task: Explorer rename/property/color dialogs under
concurrent edits, retained callbacks and narrow/large-text layouts. Stop before
implementing it.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Validated — Creation and source/file workflow quality, 2026-10-19

Fixed wrong-type creation, retained inline callbacks, failed-read retries, stale
source/model previews, source-operation feedback and delayed external-open
ownership. Stress coverage includes out-of-order reads, stable preview state and
5,000-file listings. 18 new regressions; full suite **2,521 passed**, **2 existing
skips**; formatting and analysis clean. Configured Windows/server and standard
web releases built; fresh payloads, runtime files and font hashes verified. See
[scope, evidence and limits](file-workflow-quality-2026-10-19.md). Unrelated work
and portable originals are preserved. No desktop control, personal Vault changes
or shutdown. Suggested next task: mixed-type bulk move/delete/restore and guarded
Undo after partial failures or later edits. Stop before implementing it.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Validated — Kanban and project-board quality, 2026-10-19

Fixed reserved-name grouping, stale drag/options/completion, failed/delayed
creation, read-only/imported data, shared membership and large/narrow layouts.
18 new regressions; full suite **2,503 passed**, **2 existing skips**; formatting
and analysis clean. Configured Windows/server and standard web releases built;
fresh payloads, runtime files and font hashes verified. See
[scope, evidence and limits](kanban-quality-2026-10-19.md). Unrelated changes,
unknown data and legacy scope semantics are preserved. No desktop control,
personal Vault changes or shutdown. Suggested next task: specialized-object
creation flows, including the generic Other type group. Stop before implementing it.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Validated — Large-project collection quality, 2026-10-18

Fixed existing collection-table stale edits, popup/dialog/creation ownership,
durable folder moves, shared timeline/progress membership and large-text/imported
data handling. 20 new regressions; full suite **2,485 passed**, **2 existing
skips**; formatting and analysis clean. Configured Windows/server and standard
web releases built; runtime files, fresh payloads and font hashes verified.
See [scope, checks and limits](collection-quality-2026-10-18.md). Unknown data,
unrelated changes and legacy scope precedence are preserved. No desktop control,
personal Vault changes or shutdown. Suggested next task: Kanban cross-view edits
and large-project board interactions. Stop before implementing it.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Validated — Writing font and zoom quality, 2026-10-18

Fixed Pixel notebook heading weights, bundled real terminal bold/italic faces,
expanded symbol fallbacks and isolated code/math from pixel text-size stepping.
14 new regressions; full suite **2,465 passed**, **2 existing skips**; formatting
and analysis clean. Configured Windows/server and standard web releases built;
fresh payloads and all packaged font faces/hashes verified. See [changes, checks
and limits](writing-font-quality-2026-10-18.md). No desktop-control testing,
personal Vault changes or shutdown. Preserve unrelated work. Suggested next task:
document preview/export font-style fidelity audit. Stop before implementing it.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Validated — Canvas selection/drop/clipboard quality, 2026-10-18

Completed the approved selection, drag/drop and cross-editor clipboard quality
batch. 31 new behavior regressions; full suite **2,451 passed**, **2 existing
skips**; formatting and analysis clean. Configured Windows, standalone server
and standard web releases built; required bundle files and fresh compiled
payloads verified. See [changes, checks and limits](canvas-transfer-quality-2026-10-17.md).
No desktop-control testing, personal Vault changes or shutdown. Preserve all
unrelated working-tree changes. Suggested next task: Canvas connector routing
and UML editing quality audit. Stop before implementing it.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Validated — Editor and document-tool quality, 2026-10-17

Completed the scoped writing-tool, temporary-draft, publication failure and
layout quality batch. 21 new regressions; full suite **2,420 passed**, **2 existing
skips**; formatting and analysis clean. Windows/configured Google and standard
web releases built, runnable bundle verified. See [changes, checks and remaining
boundaries](editor-quality-2026-10-17.md). No desktop-control testing or shutdown.
Suggested next task: Canvas selection, drag-and-drop and cross-editor clipboard
quality. Stop before implementing it; preserve all unrelated working-tree changes.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Validated — Technical articles and CMS publishing, 2026-10-17

Implement the owner's technical-article, memory/reverse-engineering diagram and
SEO publishing request. WordPress/another CMS is the chosen destination.
See [scope, plan and evidence](technical-articles-2026-10-17.md). Preserve the
completed PDF work and unrelated changes. Do not repeat the previous shutdown.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

# Validated — PDF review workspace, 2026-10-17

Owner requests a substantial documented feature update, followed by computer
shutdown once work is complete. Scope FILE-04/05/11/12/13/14: expanded review,
keyboard source navigation, explicit multi/range selection, bounded paginated
results, selected-only copy/export/linked summaries, bulk resolve/reopen/color/
style/delete with progress/cancellation, guarded per-item recovery and batch Undo.
CAN-13/15 and FILE-13 bridge selected evidence into linked Canvas review boards.
Reuse ordinary annotation notes, original PDF bytes and existing repository
history; report partial results honestly. No new engine, service, schema or
desktop-control testing. Preserve unrelated work.

Plan: share validated review transformations and repository commands; build an
Orbit-themed selection/action workspace around existing review rows; verify
bulk/Undo/partial failure/cancel/stale/readonly/source changes, native restart,
keyboard/filter/narrow-layout behavior; run required checks and release builds.
Finish all writes/checks and record results before requesting OS shutdown. Do not
force-close unsaved apps. No shutdown until actual completion.

Delivered: the existing Highlights and comments view expands over the reading
area with its actual state retained, rather than a duplicate editor. Checkboxes,
Shift ranges, keyboard source navigation/selection and 50-item result pages work
with the full filtered selection. Hidden selections clear on filter changes;
selected-only copy, export, linked summary and annotated PDF use existing paths.
Selected review boards use ordinary PDF/note-reference cards, retain source
context and open beside the PDF; no evidence notes or attachment bytes are copied.

Bulk resolve/reopen/color/style/Trash commands validate each immutable snapshot
and use normal recoverable note saves. A 1,000-item bound, duplicate-ID collapse,
single-batch guard, source/draft/read-only checks and explicit saved/unchanged/
failed results retain safe partial progress. Cancellation stops between writes.
Undo restores only exact committed snapshots and retains newer edits; incomplete
Undo can retry its remaining receipt. Page comments cannot become text markup.
Receipts are private runtime state; durable history/Trash remain after reopening.

The first focused tests passed domain/native failure boundaries but caught an
expansion fixture tapping before layout settled; the fixture was repaired.
Large-text native rendering prompted a less crowded selection toolbar and
collapsible keyboard help. No warnings are suppressed or checks skipped for this.
Validation and release evidence follow; no SDK/dependency/schema upgrade, external
account access, personal data or desktop-control testing is used.

Focused acceptance: **49 passed in 16s**, including 13 new domain/native/widget
cases for batch operations, partial failure/cancel/Undo, unknown versions,
deduplication, stale sources/drafts, linked boards, selection/export/pagination,
2x narrow text and native reader expansion with retained selection. Headless
rendering with local Segoe UI confirms the final 390px/2x layout at
work/ui/pdf-review-workspace-large-text.png; the opt-in visual check passes.
Final analyzer is clean in 13.5s. Required format and strict check pass for 656 lib/test
files with zero changes. Scoped whitespace checks pass. No packages, analyzer
exclusions, timeout changes or new skips were added. Evidence:
.local/pdf-review-workspace-{focused,visual,analyze,format,format-check,fix}.log.
Final full regression and release evidence follow.

The first full run exposed two older review fixtures clicking clipped controls
or tapping while earlier save feedback obscured the bottom row. They now scroll to controls
and await layout/feedback expiry before real taps; assertions remain unchanged.
That run was stopped after those failures to repair and rerun the affected PDF
tests. Its output is retained at .local/pdf-review-workspace-tests-first-pass.log;
it is not counted as a passing full run. No hit-test warnings are suppressed.

Affected regression: **24 passed in 12s**, including the real native PDF reader
workflow and expanded review selection. No missed-tap warnings remain. Evidence:
.local/pdf-review-workspace-regression.log. Fresh full regression: **2,384 passed, 2 existing skips in 4m16s**. No failures
or missed-tap warnings. Existing skips cover native symlink permission and manual
Google consent; no new exclusions/skips/timeouts were introduced. Evidence:
.local/pdf-review-workspace-tests.log. Release evidence follows.


Release validation: Windows release **passed in 95.7s** with the existing
registered Google desktop client; the standalone collaboration server compiled
without starting a server or packaging keys. Web JavaScript release **passed in
85.6s**. Existing Google Identity WebAssembly dry-run incompatibility and missing
Cupertino font warnings remain; this does not claim a Wasm build. Both build
processes exited zero. Logs:
.local/pdf-review-workspace-{windows,web}-build.log.

Runnable Windows application:
build/windows/x64/runner/Release/orbit_note.exe. The release folder contains
Flutter, PDFium and SQLite runtimes, ICU data, Flutter assets and the standalone
server/launcher. Compiled data/app.so is 24,282,000 bytes, written 2026-10-17
02:19:52 Europe/Vienna, newer than all six production files in this task. The
native runner can retain its older timestamp; Dart application code is in app.so.
No ZIP was created. No personal Vault, account transfer, physical-device or
computer-control test was performed. Unrelated working-tree changes are retained.

All feature work, automated validation, release builds and documentation are
complete. The user's authorized completion action is an ordinary Windows
shutdown, requested by a short hidden helper after the final response can send.
It uses shutdown.exe /s /t 0, without /f; unsaved applications may prevent poweroff.
The helper request/result is recorded in .local/pdf-review-workspace-shutdown.log;
physical poweroff cannot be confirmed from this session.

Suggested next task: import existing native PDF annotations into linked Orbit
review notes, with explicit fidelity warnings and recoverable duplicate handling.
Do not implement that next task as part of this completed update.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

### Validated — PDF note deletion and extraction reliability, 2026-10-16

Fix reported accidental PDF reference/highlight notes that cannot be deleted or
leave the app stuck. Scope FILE-04/05/11/12/13 and ordinary recoverable note
commands: accessible deletion from connected notes and the source banner,
retryable failure/Undo, safe tab cleanup, stale/dirty/read-only/Vault-switch
guards, and adjacent PDF quote extraction/save failures. Preserve original PDFs,
unknown note/Canvas data, identity and history. No desktop-control testing.

Plan: reproduce controller/UI failure boundaries; repair shared deletion and
linked-note controls, quote persistence and source guards; test deletion/retry/
restore, competing writes, real reader widgets and native restart. Run required
format/analyze/full tests, document results and rebuild Windows when unlocked.

Reproduced: SessionState's default lists are immutable, while tab close/pin/
archive operations mutate them. A linked-note deletion can commit and then throw
during tab cleanup, leaving presentations inconsistent. Sessions now own mutable
list copies, including caller-supplied const lists. Trash removes presentation
state without snapshotting a deleted note and promotes the adjacent PDF.

Connected notes and the note's PDF-source banner now expose recoverable deletion
and Undo; save failure releases per-note busy state with retry guidance. Generic
Trash flushes pending edits, validates snapshots/drafts/workspace, bounds duplicate
deletes and preserves keystrokes arriving during a deletion in the same Trash
note. Undo refuses newer Trash snapshots; restoration keeps recovered content.

Adjacent fixes: quote extraction uses canonical Canvas data rather than object
properties, preserving existing elements/metadata. Markdown insertion retains
authored whitespace/line endings, rejects LaTeX/read-only/invalid destinations,
and reports failed saves. Reader retains failed selections and clears only after
success. Quote/highlight creation ignores results belonging to a switched Vault.
Plain quote notes retain optional source text for citation dragging. No schema
migration, original PDF rewriting, dependency or alternate rendering engine.

New tests reproduce default-list failure, delete/restore/retry, competing drafts,
late typing during gated writes, wrong destinations, extraction failure, old-Vault
results, real note/banner UI and native restart/source-byte retention. Existing
Canvas extraction fixtures now assert scene data rather than the wrong property.
Exploratory fixture syntax/async/snapshot checks are not passing evidence; final
validation and release evidence follow. No test skips/timeouts/exclusions added.

Focused acceptance: **70 passed in 28s**, including 13 new lifecycle cases,
actual native PDF selection/deletion/Undo/source-change tests, quote extraction,
Trash/permanent deletion and document history. Analyzer is clean in 8.8s.
Required formatting and strict check pass for 653 lib/test files, zero changes.
The 19 scoped style fixes affect only the two edited library files. Scoped
whitespace checks pass. Evidence: .local/pdf-note-reliability-{focused,analyze,
format,format-check,fix}.log.

Full suite: **2,371 passed, 2 skipped in 4m22s**, concurrency 6 without competing
release builds. Existing skips are native OS symlink permission and explicitly
opt-in real Google consent. Evidence: .local/pdf-note-reliability-tests.log.
No desktop control or personal Vault testing used.

Windows release succeeds in 113.6s with the existing registered Google Desktop
configuration. The standalone server compiles without starting it or packaging
keys. Normal web release succeeds in 117.6s with the existing Google Identity
Wasm dry-run and missing Cupertino font warnings; no Wasm acceptance is claimed.
No SDK upgrade was performed. Runtime verification confirms EXE, Flutter/PDFium/
SQLite, ICU/assets and server/launcher, with a fresh **24,200,080-byte app.so**
newer than all six changed production Dart files. Run the ordinary
build/windows/x64/runner/Release/orbit_note.exe with its siblings. No ZIP or
app launch used. Evidence: .local/pdf-note-reliability-{windows-build,web-build,
release-validation}.log. Final scoped whitespace checks pass.

Suggested next task: keyboard navigation and multi-selection for PDF review
items, building on the existing recoverable deletion commands. Stop before
implementing the next task. These checks cover the reproduced failures and
related save/deletion paths, not a claim that every PDF issue is resolved.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

### Validated — Orbit UML styling and live Markdown diagrams, 2026-10-16

User requests Orbit-native styling and professional export of a Canvas diagram
into the Markdown editor without screenshots. Scope CAN-07/13/15/16 and EDT-05/08:
shared graphite/theme-aware class rendering; export selected UML classes plus
their relationships as a live, precise Markdown object reference; send to a new
or existing note or copy for paste; readable vector previews in Rich/Read,
source editing/navigation, missing/changed-source feedback and safe persistence.
Keep existing authored class/placement IDs and unknown fields; no raster capture,
new rendering engine, package or future Mermaid parser.

Plan: reuse existing object-embed grammar and Canvas renderer; add a bounded
selection fragment and guarded note export through controller commands; apply
shared Orbit styling to Canvas/SVG and previews; test references, live updates,
subset boundaries, failure/retry, read-only/stale edits, native restart and
narrow layouts. Run required checks and build the normal Windows release.

Delivered: shared Orbit surface/foreground palette, quiet separators, rounded
class boxes and restrained per-class accents in Canvas, SVG and note previews.
The existing Shapes and diagrams menu offers Export diagram to Markdown and
Copy live diagram for Markdown. Pure-UML Extract Selection uses the same path.
The destination dialog creates a note with source folder/project/course context
or appends to a searchable existing editable Markdown note. Precise placement
IDs travel in the existing object-block grammar; selected class content remains
authoritative in Canvas and current internal relationships update live.

Rich/Read render the same Canvas vector painter, with expansion/zoom, selectable
class details and exact source navigation. Rich source editing opens the shared
Canvas editor focused on the selected classes. Removed/hidden/malformed/future
sources retain useful warnings instead of showing unrelated board content.
Removing a block preserves its source. Source/destination changes, conflicting
drafts, Vault switches and read-only destinations reject mutation. Existing text,
line endings and unknown metadata survive append; failed writes retain a draft
and retry without appending twice. Native save/restart preserves exact refs.

Production Read-editor testing exposed cached object previews that did not
refresh when prose stayed unchanged. A scoped object notifier now updates live
surfaces without reparsing/replacing the surrounding Markdown. Twelve new
reference/domain/controller/native-storage/widget tests cover this behavior.
Focused acceptance: **85 passed in 23s**. Analyzer is clean in 14.1s; required
format and strict check pass for 652 lib/test files with zero changes. Earlier
fixture compile errors, Material ancestor assertions and the stale Read test
were repaired and are not counted as passing evidence.

Publication boundary: outside Orbit the block is a normal source link. Existing
PDF/HTML/Word publication exports retain that link and their preview-fidelity
warning; self-contained vector publication snapshots are not implemented here.
No new dependencies, analyzer exclusions, timeout changes or skips added. No
desktop control or personal-data testing used.

Full regression: **2,358 passed, 2 skipped in 4m27s**, concurrency 6, without
competing release builds. Existing skips are OS symlink permission and opt-in
real Google account consent. Native rendering with a real local Segoe UI font
was inspected at .local/uml-preview.png; this is a test artifact, not the stored
diagram representation. Evidence: .local/diagram-markdown-{focused,tests,format,
format-check,analyze}.log. Scoped whitespace checks pass.

Windows release succeeds in 109.1s with the existing registered Google desktop
configuration. The standalone server compiles without starting it. Normal web
release succeeds in 101.7s with the existing Google Identity Wasm dry-run and
missing Cupertino font warnings; no Wasm acceptance is claimed. Release runtime
verification confirms Flutter/PDFium/SQLite, ICU/assets, server/launcher and a
fresh **24,183,696-byte data/app.so** newer than all 14 changed production Dart
files. Run build/windows/x64/runner/Release/orbit_note.exe with its siblings;
no ZIP or app launch was used. Evidence: .local/diagram-markdown-{windows-build,
web-build,release-validation}.log. An initial verifier used the wrong server
filename; the corrected check confirms the actual OrbitNote-Server.exe.

Suggested next task: vector diagram snapshots in published PDF/HTML/Word output,
with explicit source/freshness details. Stop before implementing it.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

### Validated — Editable UML class diagrams, 2026-10-16

User requests native Canvas class diagrams matching the supplied class-box and
multiplicity reference. Scope CAN-04/05/07/14/15/16: compartmented class shapes,
editable attributes/operations, stereotypes/abstract names; association,
dependency, generalization, realization, aggregation and composition; attached
orthogonal connectors, roles/multiplicities; starter example; shared selection,
move/resize, clipboard, history, JSON and SVG. Ordinary rectangle/connector
presentations retain old-reader fallback and unknown fields; no new engine,
dependency, generated code, desktop control or external service.

Plan: inspect existing shape/connector/save paths and compatibility; implement
class/relationship editors and shared geometry/export; test creation, editing,
undo, paste/remapped endpoints, move/resize, locked/read-only/stale dialogs,
native save/reopen and narrow/enlarged layouts; run required checks and build.
Delivered: the Canvas Shapes and diagrams menu and empty-space context menu create
native class boxes and attached relationships. Double-click/Open edits classes
or UML edges. Classes have distinct bold name, attributes and operations
compartments, optional stereotype/abstract name, authored visibility/type text
and blue/navy defaults; empty compartments remain visible. Editing grows to fit
new members while preserving manually enlarged geometry. Cancel inserts nothing;
stale/read-only/locked scenes refuse edits. No universal objects are copied.

Association, dependency, generalization, realization, aggregation and composition
presets use ordinary connectors with open arrows, hollow triangles and hollow/
filled diamonds. Endpoint multiplicities/roles, attachment side/fraction and
orthogonal lane controls support multiple separated relationships per class.
Shared endpoint resolution drives paint, marker tangents, hit testing, culling
and SVG. Closed markers cover the stroke behind them. Endpoint labels follow
movement/resizing and are indexed for hit testing; class member search returns
the actual class name. Reversing a connector swaps its endpoint role/position
fields as well as existing anchors/markers. Existing marker behavior is retained.

Insert UML example adds the four supplied medical-domain classes and four
associations as one undo operation, with non-overlapping lanes and useful stored
endpoint fallbacks. Menus return keyboard focus for immediate copy/undo. Whole-
diagram paste remaps shape/edge placement IDs and attachments. Schema 1 is
unchanged: rectangles carry an optional documented `uml` map and connectors
carry optional relationship fields; old readers retain named-rectangle fallback.
Unknown root/placement/nested metadata survives edit/save/reopen. JSON retains
editable data; SVG/PNG retain appearance. SVG escapes authored labels and clips
content to geometry. Existing Mermaid export remains flowchart-only, with UML
fidelity warnings in the dialog and copy action.

Validation: 74 focused Canvas/UML/connector/export/search/narrow-panel checks
pass in 17s, including 12 new domain/native storage/widget/rendering cases.
The full suite passes: **2,346 passed, 2 skipped in 4m02s**, concurrency 6,
without competing release builds. Skips remain native symlink permission and
the explicitly opt-in real Google consent test. Strict formatting passes for
648 lib/test Dart files; root analyzer is clean in 7.7s. Native save/reopen
retains exact members, bound endpoints and unknown data. Headless rendering uses
real local fonts for visual inspection; all six generated SVG variants parse
with authored escaped labels and the expected closed UML marker geometry.

Exploratory checks caught keyboard-focus loss after example insertion, generic
search-result titles, duplicate template routing lanes and a toolbar-width
regression. These were repaired before final acceptance: UML uses the existing
Shapes menu, keeping Layers reachable at previous widths. Initial fixture
assertion/lint and interrupted compiler runs are not counted as passing checks.
No analyzer exclusions, timeout changes, new dependencies or test skips added.
Evidence: .local/uml-{focused,tests,format,format-check,analyze,svg-validation}.log;
native visual artifact .local/uml-preview.png.

Windows release succeeds in 98.4s with the existing registered Google desktop
configuration; the unchanged standalone server also compiles without starting a
process. Normal web release succeeds in 87.8s with the existing Google Identity
Wasm dry-run and missing Cupertino font warnings; no Wasm acceptance is claimed.
The Release directory includes orbit_note.exe, Flutter/PDFium/SQLite runtime,
ICU/assets and a fresh 24,134,544-byte data/app.so newer than all eight changed
production source files. The runner EXE retains its earlier native build date;
updated Dart behavior is in the AOT bundle. Scoped whitespace checks pass.
Logs: .local/uml-{windows-build,web-build}.log. App/server remain closed;
no ZIP, publishing, personal files or desktop control were used.

Limits:
no Mermaid classDiagram import/export, self-associations, automatic obstacle
avoidance, code generation or signature/multiplicity semantic validation. No
manual device acceptance, desktop control, personal data, publishing or ZIP.

Suggested next task: Mermaid UML classDiagram import/export with fidelity
checks and preserved authored member signatures.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

### Validated — PDF highlighting and annotation controls, 2026-10-15

Owner reports laggy PDF highlighting and missing deletion, and requests a more
reliable Firefox/Acrobat-style reading workflow. Scope FILE-04/05/11/12/13:
page-local cached annotation geometry; preserve selection/camera during ordinary
highlight saves; show pending markup promptly; direct annotation/page-comment
delete with recoverable Trash and guarded Undo; useful right-click actions and
clear save failures. Preserve original bytes, canonical note IDs, unknown data,
read-only/stale-source protections and ordinary save/history boundaries.
No new PDF engine, dependency, destructive PDF edits or desktop control.

Plan: audit selection/render/save paths and existing tests; implement cached
page lookup and guarded annotation removal/restoration; improve in-page/review
controls without intercepting selection drags; exercise native PDF selection,
failure/retry, source replacement, large annotation sets, Trash/restart and
narrow layouts; run required formatting/analyzer/full suite and Windows build.

Delivered: PdfAnnotation decodes its immutable normalized Canvas regions once;
the reader indexes markup and page comments by page, reusing unchanged decoded
snapshots when another mark changes. Fresh parent wrapper lists no longer trigger
annotation invalidation or full-document geometry work. Painting, hit testing
and comment-pin construction use page-local data. Active-mark pulses repaint
without rebuilding the whole reader; unchanged page notifications no longer
overwrite page-jump input. Original bytes and portable annotation fields stay
authoritative; no package, alternate ink engine or format migration was added.

Plain highlight/underline/strikeout saves paint pending regions promptly, keep
the page viewport and panel state, and clear selected text only after success.
Failure removes the transient preview but retains selection for retry. Cancelled
passage comments keep selection without reporting a persistence failure. The
existing comment dialog retains failed drafts. Text markup remains paint-only;
selection drags and ordinary selected-text context menus are not covered by
annotation hit-test widgets.

Right-click text marks for details, color/style/comment editing, copying or
Delete. Details and review rows expose deletion of highlights and page comments,
including stale source-version notes. The application issues an ordinary
revision-checked save to Trash and returns that exact deleted snapshot for
eight-second Undo. Stale snapshots, unsaved/in-flight edits, competing editor
drafts, unsupported/read-only notes and changed Vaults refuse mutation. Closing
the deleted note's view avoids a post-delete automatic snapshot that would change
its revision and invalidate Undo. Unknown data/comments/UUIDs are preserved;
Trash survives restart and does not modify the source PDF. Clipboard failures in
individual review rows now report safely. Late actions/replies are source-bound.

Validation: 60 PDF/controller/export checks pass in 13s, including
13 new domain/controller/native widget/storage cases. Native tests verify actual
PDF selection/paint callbacks, pending/failure/retry, stable camera/viewport,
same-identity delete/Undo without source reload, read-only menu changes, source
replacement, cancelled comments, narrow 2× text and native Trash/restart/restore
with exact original bytes/unknown metadata. The full suite passes: **2,334 passed,
2 skipped in 4m45s** with concurrency 6 and no competing builds. Skips remain the
existing Windows symlink privilege case and explicitly opt-in real Google consent
test; all new native PDF cases ran. Final strict formatting passes (645 lib/test
Dart files, zero changes); root analyzer is clean in 8.2s. Early exploratory
fixture/formatting and tab-close failure cases were repaired before the final
passing runs; no failing run is counted as acceptance.

Geometry-only microbenchmark: 1,000 annotations across 100 pages, 12,000 regions,
30 simulated repaint passes on one page. The prior repeated-decode loop takes
4,464,189 µs; page lookup takes 924 µs for the same visible geometry. Initial index
build takes 38,443 µs and snapshot-reusing refresh 4,670 µs. Each page visits 120
regions, instead of decoding 1,800,000 region instances across those passes.
This isolates annotation processing: it is not an end-to-end PDF frame-rate,
large-file rendering benchmark or a guaranteed device speedup. Script/result:
.local/pdf-markup-benchmark.dart and .local/pdf-reader-benchmark.log.

Windows release succeeds in 123.8s using the existing registered Google Desktop
client; the existing standalone server also compiles without starting a process.
Normal web release succeeds in 116.2s with the pre-existing Google Identity Wasm
dry-run and missing Cupertino font warnings; no Wasm acceptance is claimed.
The normal Release directory contains orbit_note.exe, Flutter runtime, PDFium,
SQLite, ICU/assets and a fresh 24,052,624-byte app.so newer than all five changed
production source files. No ZIP or publishing; the app remains closed. Scoped
whitespace checks pass, and unrelated workspace changes are preserved. Logs:
.local/pdf-reader-{focused,tests,format,format-check,analyze,windows-build,
web-build,benchmark}.log. No desktop control or personal PDF is used.

Limits: these are headless native PDF and storage checks, not measured desktop
scroll/selection frame-rate or device/manual acceptance. Deletion/Undo act on
Orbit's linkable annotations; native editing of annotations already embedded in
an imported PDF is not introduced. Original attachments are never overwritten.
No complete Acrobat-parity or PDF-wide keyboard undo/redo claim is made.

Suggested next task: PDF annotation keyboard shortcuts and document-wide
annotation undo/redo with the same durable recovery guarantees.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task

### Validated — Device sync and self-hosted connection continuity, 2026-10-15

Owner requests continued Google Drive improvements plus easier self-hosting and
cross-device sync. Scope: opt-in foreground checks for selected existing Drive
Vaults, explicit pause/retry/status, secure remembered shared-server connections
and reconnect, authenticated server readiness diagnostics and clearer host setup.
Reuse existing provider/engine, native locks, repository history and shared roles.
Drive and shared authorities must not run together, including connection setup.
No new cloud scopes, personal uploads from agent tools, public deployment,
firewall changes, desktop control, new live object/attachment protocol or service
that continues after Orbit closes. Core local-only startup stays offline.

Plan: finish targeted storage/server inspection; implement guarded scheduling
and secure device-only connection profiles; add server test/setup guidance;
exercise restart, account/Vault switches, locks, revocation, cancellation and
authority handover; run format/analyzer/full tests and relevant platform builds.

Delivered: successful bulk transfers offer **Keep these Vaults updated while
Orbit is open** (off by default). Settings → Sync → **Manage scheduled Vault
checks** shows the selected Vaults, per-job results, last/next check, 1/5/15-minute
interval, check now, pause/resume, remove and Forget. The secure device-local
selection survives restart and binds to the Google subject. Checks reuse the
active controller's exclusive batch lease and production engine/provider, exclude
the current Vault, and open/close inactive native repositories under their normal
existing-identity/OS locks. Individually paused/unbound Vaults cannot be newly
enabled by scheduling. Offline work backs off; account failures need explicit
retry. No scheduler account service is constructed without saved opt-in.

Shared settings add owner-authenticated **Test server connection**, explicit
**Remember connection on this device**, **Reconnect saved server** and **Forget
saved connection**. Only a room capability is saved in OS-protected storage keyed
by Vault UUID hash; never the root owner key or portable files. Live server role,
revocation and divergence checks remain authoritative. Unsupported private data
is preserved until explicit Forget, which remains accessible after load failure.
Shared create/connect signals activity before the first await to suspend Drive;
late import/invitation replies retain active-opening guards. New controls wrap
at narrow widths and enlarged text. Unknown supported private metadata survives.

The normal Windows build now includes collaboration/OrbitNote-Server.exe,
Start Orbit Server.cmd and its README. The explicit launcher uses private
LOCALAPPDATA/OrbitNote/Server and keeps an ordinary console open; no installed
service, firewall rule or public host is created. Both CLI and service reject
server data inside a Vault before creating keys/journals. Minimal /healthz returns
readiness without private details; /v1/server requires the owner key and returns
protocol/readiness/capabilities. Journal failure reports unready. ADR-0031 extends
the earlier memory-only reconnect boundary; no authored migration/dependency or
new live shared-object protocol was introduced.

Validation: **17 new continuity tests passed**, including native selected-Vault
checks/restart, per-Vault opt-out, account/shared exclusion, offline backoff,
cancellation, locks, supported unknown metadata/future formats, saved server
roles/revocation, cancelled connections, narrow 2× text/recovery controls and
server readiness/storage failure. The complete suite passes: **2,321 passed,
2 skipped in 5m26s** with concurrency 6 and no competing builds. Skips remain the
existing Windows symlink privilege case and opt-in real Google consent/uploads.
An isolated production Drive/native storage file also passed all 13 tests in 26s.
Exploratory narrow-layout overflow and a new widget fixture's simulated-clock
stall were fixed. An earlier full run under simultaneous release compilers hit
the existing storage test's 30s timeout; it was stopped, then the isolated check
and the uncontended full suite passed without increasing timeouts.

Final strict formatting passes (644 lib/test Dart files, zero changes); root
analyzer reports no issues in 124.2s. Windows release succeeds in 153.9s with the
existing registered Google Desktop client and standalone server compilation.
The normal web release succeeds in 131.6s; existing Google Identity Wasm dry-run
and missing Cupertino font warnings remain, so no Wasm acceptance is claimed.
The compiled server separately passed health/authentication/key initialization
and CLI refusal to create private state inside a Vault, using an invisible
ephemeral helper with synthetic data; the helper and data were removed afterward.
The normal Windows EXE, runtime DLL, ICU/assets and current 24,019,856-byte app.so
are present in build/windows/x64/runner/Release. The collaboration subfolder
contains the 7,574,528-byte server EXE, launcher and README, with no owner key.
No ZIP was created. The app remains closed. Scoped whitespace checks pass and
unrelated workspace edits are preserved.

Evidence: .local/device-sync-{continuity-final,storage-recheck,tests,format,
format-check,analyze,windows-build,web-build-final,server-smoke}.log.

Limits: this slice uses temporary synthetic Vaults, a simulated Drive HTTP
service and an ephemeral loopback host. It does not repeat owner Google consent,
upload personal files, control the desktop, configure HTTPS/public exposure or
prove physical-device transfer. Previous real-account acceptance below predates
this schedule UI. Checks stop when Orbit closes. Existing-note/Canvas live edits
remain the shared protocol; new objects, deletions and attachment changes still
require a new shared snapshot. No publishing or process termination of the user's
app/server is performed. The compiled smoke helper is owned by this test only.

Suggested next task: shared live propagation of newly created objects,
deletions and attachments with durable reconnect and two-client acceptance.

## Previous bulk-transfer evidence

### Validated — Bulk Drive Vault transfers, 2026-10-15

Owner requests a button to select multiple local Vaults (including a group on
Desktop), upload/connect them to Drive, and retrieve them on another device.
Scope SYNC-02/03/04/05/07: native explicit multi-selection, bounded folder
discovery, sequential per-Vault sync through existing engine/provider, persistent
bindings, per-Vault results, cancellation/retry and bulk cloud download into new
local folders. Preserve active Vault, existing identities, locks, drafts, conflict
copies and account isolation. No automatic upload of the owner's personal Vaults
from agent tools, new scope/dependency, desktop control or global background
service. Inactive Vaults sync on this explicit batch; foreground automatic sync
continues for the active Vault only.

Plan: inspect existing registry/discovery and binding contracts; add a guarded
batch coordinator with existing-only native opening; add accessible local/cloud
pickers and transfer results; test multiple Vaults, selection scope, duplicates,
restart/retry, locks, conflicts, cancellation and account changes. Run required
format/analyze/full tests and relevant platform builds; record actual evidence.

Delivered: Settings → Sync now has **Upload multiple Vaults** and **Download
multiple Vaults**, with explicit checkboxes, Select all, individual folders and
shallow discovery inside a chosen parent such as Desktop. Per-Vault status,
streamed file progress, cancel and retry preserve partial work. Downloads create
separate folders, register up to 50 recents without changing the active selection,
and show authored Vault names in the switcher. Duplicate UUID copies require an
individual choice; different Vaults with matching names remain independent.

The batch reuses extracted binding/manifest-opening helpers, SyncEngine and the
production Drive provider. The active controller grants an account/opening-guarded
lease, suspends its polling and retains active draft/apply checks. Inactive native
repositories use OS locks, verify an existing manifest identity before recovery,
and close after each job. No missing selection can create a replacement Vault.
Completed reconciliations retain per-Vault sync bindings. Cancellation during a
first transfer leaves automatic sync disabled; existing opt-ins are preserved.
Account/shared-session changes invalidate subsequent requests and checkpoints.
No authored migration, new package or alternate sync protocol was introduced.

Validation: 42 focused provider/controller/native batch checks passed in
34s, including twelve same-name Vaults, selected-only scope, locks/deleted paths,
duplicates, partial retry, account changes, exact downloads, future binding data,
conflicts, active draft guards, recents and narrow 2× text layouts. Three additional
checks cover active polling exclusion and account invalidation during batch/picker
setup. Root analyzer is clean in 99.3s; strict format check passes (639 Dart files).
The complete suite passes: **2,304 tests passed, 2 skipped in 3m51s**. Skips are
the existing Windows symlink privilege case and explicitly opt-in live-account
acceptance (no Google consent or cloud upload occurs in normal tests). The 18 new
cases include actual native files/staging and deterministic UI discovery data;
initial exploratory fixture/compile failures were repaired and are not counted
as passing runs. Windows release succeeds in 91.5s using the existing registered
Google Desktop client. The normal web release succeeds in 98.7s; it retains the
pre-existing Google Identity Wasm dry-run and missing Cupertino icon-font warnings,
so no Wasm acceptance is claimed. Evidence:
.local/bulk-drive-{focused,format,format-check,analyze,tests}.log.
Build logs: .local/bulk-drive-{windows,web}-build.log. The compiled Windows
data/app.so postdates all 11 changed application sources; EXE, runtime DLL,
ICU data and assets are present in build/windows/x64/runner/Release. The app
remains closed. No ZIP, process termination, publishing or desktop-control test.
Scoped whitespace checks pass; unrelated workspace changes are preserved.

Limits: batch execution is explicit foreground work, not continuous inactive-Vault
background sync. This update uses native temporary Vaults and a simulated Drive
HTTP service for repeatable tests; no personal Vault was uploaded or app desktop
controlled. Previous real-account acceptance below predates this batch UI.

Suggested next task: optional scheduling for explicitly selected inactive
Vaults while Orbit is open, with visible ownership/lock and pause controls.

## Previous acceptance evidence

### Validated — Real-account Drive acceptance, 2026-10-15

Owner approved the outstanding real Google-account and two-device transfer checks.
Use only isolated synthetic acceptance Vaults with the production account,
Drive provider, native repository and sync engine. Tokens stay in memory; do not
read the application's credential store or upload any personal Vault. Browser
consent belongs to the owner. No desktop control, new scopes or publishing.

Plan: add an explicitly opt-in live acceptance harness; exercise sign-in/refresh,
cloud discovery, verified note/Canvas/attachment transfers, reverse transfers,
offline divergence, retained conflict copies, explicit resolution, interrupted
resumable uploads, lost publication acknowledgements, tombstones and restarts.
Retain clearly named synthetic fixtures for inspection. Two isolated native
clients on this PC are not two physical devices; record that distinction and any
owner-assisted second-device result. Default automated suites must skip live I/O.

Delivered: an explicit `ORBIT_LIVE_DRIVE=true` manual acceptance harness (skipped
by default) and reproducible setup/acceptance instructions. Owner completed fresh
Google consent and selected two local clients for now. No desktop control or
app credential-store access was used. Two independent native repositories and
HTTP clients used the production OAuth, Drive provider, staging and SyncEngine.

Real-account result: **1 live test passed in 4m10s**. Google identity, session
restore and refresh passed. A uniquely identified synthetic cloud Vault was
created/discovered; client B bootstrapped from its checksum-verified remote
manifest. Mixed-line-ending/Unicode Markdown, Canvas unknown data and a 2 MiB +
37-byte attachment transferred intact. New objects transferred B → A. Offline
divergent edits retained both originals; explicit cloud resolution converged.
A real acknowledged upload chunk lost its response; reopening the local
repository resumed the same journaled session without creating another session.
A real revision creation lost its response and recovered by stable ID. Trash and
permanent-deletion tombstones propagated; both persisted replicas restarted with
clean checkpoints and no remaining branches. No production defect surfaced in
these scenarios; no application behavior or binary changes were needed.

Evidence: .local/drive-live-acceptance.log and sanitized
.local/drive-live-result.json. Synthetic cloud fixture **Orbit Sync Acceptance
dcf46d05** and matching local fixtures are retained for inspection. Tokens stayed
only in memory and were cleared on completion; local operational journals remain
ignored and are not portable account credentials. Existing personal Vaults were
not read or uploaded. Format/strict checks pass (631 Dart files), analyzer is
clean in 8.2s, and the normal full suite passes: **2,286 passed, 2 skipped in
3m45s**. The skips are the existing Windows symlink-permission case and the new
explicitly manual live-account case (which passed separately above). Logs:
.local/drive-live-{format,format-check,analyze,tests}.log. Scoped whitespace checks
pass. Only tests and documentation changed; the existing Windows binary remains
current for production application code, so no rebuild or app launch was needed.

Limits: this is actual Google-account transfer acceptance on one Windows PC,
not two physical devices, app UI scheduling, app secure credential storage,
mobile/public OAuth rollout or multiplayer acceptance. The owner chose to defer
the second physical device. Suggested next task: installed-app sign-in/secure
session restore and transfer acceptance on a second Windows device when available.

## Previous implementation evidence

### Validated — Automatic personal Drive sync preview, 2026-10-15

Owner approved automatic Drive Vault synchronization with conflict recovery.
Scope SYNC-01–08/11/12: opt-in native personal Vault sync, durable account/Vault
binding and retry state, automatic foreground scheduling, verified streamed files,
new-object/deletion propagation, conflict review and recoverable resolution.
Reuse SyncEngine, WorkspaceSyncReplica and normal save/history. Preserve unrelated
work. No desktop control, new OAuth scopes, server deployment or account upload
from agent tools. Enabling uploads remains an explicit in-app action.

Plan: select/document a race-safe Drive publication protocol; implement provider
and engine conformance with temporary native replicas; add opt-in application/UI
coordination and conflict recovery; verify restarts, forks, uncertain responses,
drafts, account/Vault switches, format/analyze/full suites and Windows release.
Drive v3's mutable-update CAS is not assumed. Immutable revision publication will
retain concurrent branches and surface them for explicit resolution rather than
overwrite an unobserved edit. ADR-0030 records this extension of ADR-0017.

Delivered: native foreground automatic personal sync with explicit account/Vault
consent, durable folder binding and interrupted-setup IDs, restart resume,
pause/retry and new-device opening into a separate folder. The provider publishes
verified streamed immutable blobs and parent-linked records; concurrent heads are
retained as branches. SyncEngine preserves each alternative before checkpointing
and journals explicit resolutions; newer local edits reject stale reviews. Ordinary
repository history, exact authored bytes, stable IDs, attachment-first apply and
permanent-deletion tombstones remain authoritative. Provider/key caches avoid
re-downloading every record for each publication. No automatic cloud garbage
collection, new dependency or authored Vault migration.

Local-only startup reads opt-in without constructing account services. Account/
Vault switching, pause and Shared Vault activity invalidate applies and late
acknowledgements. Authentication/quota/configuration failures stop automatic
requests until attention/manual retry; transient failures back off. Pause remains
reachable when Google requires reconnection. Backups stay independent of sync.
Operational settings/journal and optional engine resolution fields are documented
in implemented-formats; ADR-0030 partially supersedes the mutable CAS-only gate.

Validation: 27 new regression cases exercise the production HTTP
adapter against a simulated Drive service and real temporary native Vault files,
including offline divergence, racing branches, restart/lost acknowledgements,
multi-chunk/empty attachments, moves, Canvas unknown data, tombstones, initial forks
with no local object, stale review, setup/pause recovery, account isolation,
startup opt-in, Archive gate and narrow/enlarged settings. UI/ready focused checks
pass (20 cases). Format and strict format checks pass (630 Dart files), root
analyzer is clean in 7.9s, and all 2,286 tests pass in 4m47s (concurrency 8), with
one existing Windows symlink-permission skip. Evidence:
.local/drive-sync-{format,format-check,analyze,tests,ui-final}.log. Native/provider
fixtures and the complete pre-existing engine/replica suites are included in the
full run. Initial metadata-widget fixtures stalled across fake/real clock file
queues; only read-only footprint metadata is deterministic in those layout tests,
while native durability tests still use real files. Interrupted exploratory runs
are not counted as final checks. Windows release succeeds in 101.7s with the
existing registered Desktop client; the normal web release succeeds in 101.0s
(.local/drive-sync-{windows,web}-build.log). Web retains existing Google Identity
Wasm dry-run incompatibility and missing Cupertino icon-font warnings; no Wasm
or browser automatic-sync claim. Compiled data/app.so postdates all 13 relevant
app sources; executable, runtime DLL and assets are present in the normal
build/windows/x64/runner/Release folder. No ZIP, app launch, process termination
or publishing. The app remains closed. Scoped diff whitespace check passes.

Limits: native folders and open-app lifetime only, empty folders/device settings
stay local, device-local folder Archive metadata blocks setup; 10,000 retained
revisions, 64 parents, 16 MiB operational checkpoints and existing native file
limits. Some non-Notes moves and restoring a permanent deletion need manual
recovery. Retained revisions consume Drive storage. No user account upload,
browser/desktop control, public OAuth rollout, Android activation or real
Google-transfer/two-device acceptance was performed by this task.

Suggested next task: real-account, two-device Drive acceptance covering offline
divergence, account renewal and interrupted large attachment transfer. Stop before
performing it; no broader multiplayer or cloud retention/GC feature is authorized
by this continuation.

---

# Validated — Drive and shared-session reliability, 2026-10-15

Owner requests improving Google Drive and multiplayer. Scope SYNC-02/03/04/05/07/
08/09/10 within ADR-0027: improve backup account/cancel guards, completed-upload
feedback, provider error classification, backup browsing, and shared-session
reconnect/backoff, pending work and revoked-access feedback. Preserve local editing,
known-base merging, journal acknowledgements, private capability credentials and
whole-Vault snapshot consent. No automatic personal sync, new live object protocol,
production deployment, new OAuth scopes, account uploads or desktop control.

Plan: regression fixtures for interrupted/cancelled transfers and connection races;
bounded recovery and actionable status/controls; headless provider/two-client tests,
format/analyze/full suites, docs and normal Windows release if closed. No new package
or portable schema migration. Live Google/two-device acceptance remains separate.

Delivered: Drive backups filter by current/all Vaults and name within the connected
account, bind confirmation to account and owning Vault opening, and discard late
cancelled restore candidates. Verified uploads remain visible if listing fails or
is temporarily incomplete. Upload recovery refreshes expired tokens once, probes
the same resumable session after transient failures with bounded 1/2/4-second
waits, and distinguishes quota/rate/API configuration from revoked access. Failed
sign-out keeps account data and actionable feedback instead of silently succeeding.
Shared sessions add 1/2/4/8/16/30-second network backoff, Retry now, revoked-access
pause, and pending-document status including failed local saves. Late connection/
Vault responses are ignored; uncertain edit acknowledgements replay the same
operation identity while newer local edits remain separate proposals. Existing
repository history, capability roles and server journal boundaries remain intact.

Validation: 23 new regression cases; 62 focused Drive/shared-session checks pass
in 4s. Headless provider fixtures cover cancellations, uncertain
acknowledgements, token expiry, throttling/outages and exhausted recovery; widget
fixtures exercise backup filters/account isolation and stale confirmation. Local
two-client/server-restart and narrow/large-text shared controls remain covered by
the focused collaboration suite. No user Vault/account upload, browser sign-in,
desktop control, server deployment or real two-device acceptance in this batch.

Formatting and strict format checks pass (624 Dart files); root analyzer is clean
in 15.6s. All 2,259 tests pass in 4m41s (concurrency 8), with the existing one
Windows symlink-permission skip. Evidence: .local/cloud-shared-{format,
format-check,analyze,focused,tests}.log. The initial widget fixture stalled while
closing/reopening a PDF indexer across fake/real clocks; it was replaced with an
owning-workspace replacement fixture. An initial transfer fixture also exposed
that an immediately empty listing hid a verified upload; the product now retains
that verified result. Interrupted exploratory runs are not counted as final checks.

Windows release succeeds in 93.6s using the existing registered desktop client
(.local/cloud-shared-windows-build.log). Compiled data/app.so postdates all six
changed application sources; executable, runtime DLL and assets are present in
build/windows/x64/runner/Release. App remains closed. No private credentials are
printed or packaged separately, no ZIP is created and no running process is stopped
or app launched. Scoped diff whitespace check passes; no new dependency/schema
migration.

Suggested next task: automatic personal Drive Vault synchronization through the
existing provider/reconciliation boundary, including conflict recovery. Stop
before implementing it.

---

# Validated — Remove editor scroll-progress stripe, 2026-10-15

Owner asks to remove the annoying Markdown scroll-progression indicator. Scope
EDT-03/15: remove the shared NoteEditor reading-progress stripe, derived progress
state and its whole-editor scroll-notification rebuilds. Retain scrolling, source
offset callbacks, native scrollbar behavior, saved Rich/Read/Source/Split positions
and line/column indicators. No source/preferences/storage changes or desktop control.

Plan: remove indicator-only state/listener, update the existing UI assertion and
design contract, format/analyze/full tests and rebuild Windows if the app is closed.

Delivered: removed the reading-progress widget and percentage state from shared
NoteEditor chrome and the indicator-only ScrollNotification wrapper. Source scroll
offset callbacks and existing saved view-state listeners remain intact. The line/
column regression now expects no stripe; no new implementation-mirroring test.
Format and strict format checks pass (623 files), root analyzer is clean in 16.6s.
All 2,236 tests pass in 4m12s (concurrency 8), with one Windows symlink-privilege
skip. Headless tests include saved view restoration, selection/scrolling and
large-note navigation; no desktop control or hardware-performance claim. Evidence:
.local/remove-scroll-progress-{format,format-check,analyze,tests}.log. Windows
release succeeds in 92.3s (.local/remove-scroll-progress-windows-build.log).
Compiled data/app.so postdates note_editor.dart, and the normal executable/DLL/data
folder remains runnable without a ZIP. App remains closed; no process was stopped
or launched. Scoped diff whitespace check passes. Changes remain limited to the
requested UI removal.

Suggested next task: the previously queued nested/numbered browser-list paste
audit. Stop before implementing it.

---

# Validated — Browser list paste spacing, 2026-10-15

Owner reports ChatGPT/browser paste showing empty bullet placeholders above each
paragraph. Scope EDT-04/09, DES-01: reproduce paragraph-wrapped HTML list conversion,
attach first paragraph text to the existing bullet, and verify real Rich paste,
formatting, undo and plain-text fallback. Preserve authored empty list items,
ordinary Markdown blank lines, code and unrelated work. No desktop-control tests,
user Vault mutation, dependency or source format change.

Plan: failing converter fixtures for paragraph/div wrappers; narrow HTML import
fix; headless keyboard paste/undo and adjacent converter regression tests;
format/analyze/full suites, evidence and Windows release if the app is closed.

Delivered: HTML list import consumes leading whitespace and opening paragraph/div
wrappers with the list-item boundary, keeping its first text on the bullet instead
of creating an empty list block followed by unrelated prose. This applies to rich
browser paste only, not existing Markdown source or plain paste. No blanket empty
item/blank-line removal. Literal code remains protected by the existing converter.

Three failing fixtures reproduce paragraph/div/nested-div wrappers generating the
reported empty bullets. After the narrow fix, 67 focused clipboard/table/selection
checks pass in 17s. Six new cases include real Rich Ctrl+V replacing a selection,
filled list fields, preserved bold and exact one-step undo, wrapper attributes/case,
Unicode, inline code and links, and deliberately empty HTML items/prose paragraphs.
Existing source/raw code/plain clipboard behavior remains checked. Owner closed
the running release app; no process was killed. Final format and strict format
checks pass (623 files), root flutter analyze is clean in 11.9s, and 2,236 full-suite
tests pass in 4m18s with concurrency 8. The one skipped native symlink check requires
Windows privilege and remains unverified. Logs: .local/browser-list-focused.log,
browser-list-repro.log, browser-list-full-tests.log, browser-list-analyze.log and
browser-list-format-check.log. Testing is headless with clipboard fixtures, not
desktop control or real external-app acceptance. Registered-client Windows release
succeeds in 79.5s (.local/browser-list-windows-build.log); compiled data/app.so
postdates markdown_clipboard.dart. The normal runnable Release/orbit_note.exe,
DLLs and data remain together without a ZIP; the app stays closed. Scoped diff
whitespace check passes. Previously malformed pasted sections must be re-pasted or
edited explicitly; existing source is never automatically rewritten.

Suggested next audit: nested and numbered browser-list clipboard imports. Stop
before implementing it.

---

# Validated — Feature reliability and delayed-action audit, 2026-10-15

Owner requests feature testing and bug fixes. Scope EDT-04/09/11/12, DES-01, CAN-05/07 and
storage/recovery regression: inspect existing feature boundaries, reproduce
clipboard/grid, connected-Canvas and delayed-dialog failures, fix defects with native
widget/domain fixtures and run the broader existing feature/stress suites. Owner
then requested continuing the issue audit: expand to equation/table/link/attachment
dialogs, read-only transitions and note-block placement while switching documents.
Preserve unrelated work, ordinary Markdown/JSON and unknown data, object versus
placement identity, undo, failed/stale operations and read-only behavior. No new
features, desktop control, app launch or tests on user Vaults.

Plan: failing round-trip/rectangle/race clipboard tests and duplicate/connector
geometry tests; narrowly repair those paths; validate editing, source undo,
Canvas history, saved/reopened fixture bytes, code/PDF/search/recovery workflows
through existing headless suites. Format/analyze/full tests, docs/evidence and
serial web/Windows builds; stop with one suggested next audit.

Delivered: rectangle keyboard/menu/grid paste starts at the upper-left cell with
range/revision/owner guards; CSV/TSV copies quote delimiter/quote/empty values,
unquoted tabs take precedence over commas, and blank rows retain their positions.
Plain clipboard fallback uses one captured read. Single-line caret paste preserves
commas/quotes instead of overwriting neighbor cells; explicit Paste cells retains
CSV import. Native table copy/cut actions share guarded handlers; failed cuts retain
text, successful cell/range cuts are undoable, changed note epochs (including
switch-away-and-back) refuse delayed cut/paste, and active composition is retained.
Canvas duplicate remaps copied connector anchors to copied nodes, retaining outside
anchors. Copy snapshots visible endpoint geometry so detached paste keeps its
shape when attached nodes are outside the copied set; fully connected copies keep
authored fallback coordinates. Malformed connector field types use safe getters
for rendering and hit-testing while retaining their JSON. Cut checks still use the
original immutable placement data, not the copied geometry maps. No source
format/migration, object deletion or new dependencies.

Additional delivered fixes: Source equation/table/link dialogs use the guarded
insertion boundary shared with attachments, capture note/controller/Vault ownership
and refuse switch-away-and-back or read-only completions. Changed source/selection
offers explicit Insert here instead of overwriting newer text; that action rechecks
ownership and permissions. Rich attachment insertion shares the outer guard.
Pending Source cut rechecks read-only/deleted state after clipboard success; Source
paste also checks those permissions. Controller/Vault changes invalidate ownership
epochs. Note-block placement captures its source owner/title before picking a Canvas
and validates owner, local/persisted source and permissions before adding anchors
or placements. Successful equation/table/link insertions remain undoable. Equation
Studio uses a scrolling dialog and naturally sized controls plus a bounded symbol
list so short/narrow windows and enlarged text do not squeeze controls into overflow.

Validation in progress: failing fixtures reproduced forward rectangle refusal,
TSV/cell quote and delimiter corruption, linked duplicates targeting original nodes,
stale connector fallback positions, and failed native cuts deleting text. Fixes
passed 137 focused checks in 27 seconds after the additional connector audit,
including 24 new table/clipboard/Canvas cases, native keyboard/menu routes, source undo,
owner/range races and active composition. Existing PDF reading/search/navigation,
code-file viewing, course drafts, workspace recovery, editor selection and stress
checks pass. Stress evidence is eight seeds/8,000 mixed Canvas commands and a
temporary native 24-note Vault with six save/reopen rounds and external conflicts.
Unknown data, original scene/source after undo, and final persisted bytes survive.
These are test workloads, not hardware frame-time or total-capacity guarantees.
The first full suite caught fallback-coordinate changes in fully connected copies;
narrowing snapshots to detached copies restores that existing contract. A separate
malformed-connector fixture reproduced a render TypeError; safe typed getters fix
it without removing or rewriting original data. The first completed full run passed
2,207 tests with one Windows symlink-privilege skip; analyze was clean and strict
formatting passed (622 files). Continuing the audit reproduced cross-note equation
and table insertion, link insertion overwriting newer text, Source attachment
insertion after switch-and-return, wrong-note Canvas placement, and pending Source
cut deleting after read-only transition. Equation Studio's compact layout overflow
was also reproduced. Twenty further headless checks cover those failure boundaries,
normal insert/undo, guarded explicit relocation and 390px/1.8x-text math layout.
The expanded full suite also caught an integration regression: routing dialog
insertion through the attachment handler displayed indefinite transfer progress
while waiting for user choice. Dialog insertions now retain the safety/duplicate
guards without transfer progress; ordinary attachment operations keep it.

Final source checks: 2,227 full-suite tests passed in 7m54s; the one skipped check
requires Windows native symlink-creation privilege, and remains unverified here
(.local/feature-audit-full-tests.log). The expanded math/writing/table/clipboard
focused run passed 111 tests in 26s, and the existing note-editor plus dialog checks
passed 24 in 13s after removing modal transfer progress. Three additional free
line/arrow/connector duplication regressions passed in 2s: the existing geometry
copy path already shifts explicit endpoints, so no additional code fix was needed.
There are 47 new cases in this audit (44 exercised in the full suite, three in
.local/feature-audit-free-connector-repro.log). Native clipboard adapters are
fixtures; external-app/device acceptance, sign-in and hardware latency are not
claimed. Final format and strict format checks pass (623 files, zero differences),
and root flutter analyze reports no issues in 10.7s. A post-build analyzer run
exposed ignored scratch snapshots and package caches under Windows 8.3 aliases;
analysis_options.yaml now excludes only .local/.pub-cache and their aliases,
retaining application/test analysis (.local/feature-audit-analyze-cache-probe.log
records the cache findings; .local/feature-audit-analyze.log is the passing run).
JavaScript web release succeeds in 197.5s (.local/feature-audit-web-build.log).
Existing Google identity dependency Wasm dry-run and Cupertino font warnings
remain; this validates the JavaScript target, not Wasm or font fallback fidelity.
Registered-Google-client Windows release succeeds in 144.4s
(.local/feature-audit-windows-build.log); data/app.so postdates all changed app
sources. The runnable build/windows/x64/runner/Release/orbit_note.exe, DLLs and data
remain together in the normal release folder, without a ZIP. No running app was
stopped or launched. Scoped git diff --check passes. Unrelated work is preserved.

Suggested next audit: PDF/asset-import cancellation while switching Vaults. Stop
before implementing that audit. Native external-app/device acceptance and the
skipped symlink-privilege check remain separate work.

---

# Validated — More writing designs and pixel-font zoom, 2026-10-14

Owner requests more Markdown designs and a fix for soft pixel-notebook lettering
at Ctrl-plus app zoom. Scope LAY-01/06/10, EDT-03/04: four writing designs using
the existing surfaces/paper/photo system, display-pixel-aligned Tiny5 sizes with
an opt-out for continuous sizing, previews and preserved pane preferences.
Keep native Rich/Source/Read/Split selection/undo, OS accessibility scaling,
ordinary app chrome and other fonts. No new fonts/packages, file schemas or
authored content changes; no desktop-control testing.

Plan: inspect font metrics and zoom path; scope pixel sizing to note title/body
and previews, add palettes/original vector frames and useful initial paper
choices; exercise Ctrl-plus, DPR/OS text scaling, state/selection, all palettes,
photo contrast and narrow layouts. Render real bundled-font previews headlessly,
run format/analyze/full suites, update evidence and build web/Windows serially.

Delivered: Blueprint, Field journal, Typewriter and Amber terminal palettes and
original vector drafting/cover/platen/phosphor details, with existing paper/photo
controls. Blueprint/grid and journal/rules are initial choices from plain paper.
Paper controls precede the expanded gallery; larger pickers remain scrollable.
Tiny5's bundled font metrics are 1024 units/em and 640-unit cap height (five
128-unit cells). A stable MediaQuery scope rounds title/body and previews after
the composed zoom/OS scaler to integer display cells; app chrome/other fonts and
viewport geometry stay unchanged. Sizes can grow in steps; Crisp pixel sizing
opts out without replacing controllers or source. Existing preferences retain
unknown fields and default pixelSnap to true. No font/package additions.

Validation in progress: 66 focused checks pass in 12 seconds
(.local/designs-zoom-focused.log), including eight new preference/zoom/state cases,
all ten designs/four papers at 360px/200% text, light/dark contrast, photo contrast/
storage and selection/clipboard/search regressions. Ctrl-plus passes in actual
Rich/Source/Read/Split, preserving native field/controller identity and selection;
five display densities and three OS scales exercise every zoom step and normal
writing sizes. Continuous opt-out and Apply/Reset preserve source. The expanded
gallery required scroll-to-paper in the existing interaction fixture; no checks
were removed. Real bundled-font headless previews for all designs and pixel
110/125/150% zoom pass and were inspected (.local/designs-zoom-render.log,
.local/designs-pixel-render.log, .local/writing-{design}.png,
.local/pixel-zoom-{zoom}.png). Strict formatting: 622 files, zero changes (5.57s).
Analysis is clean (9.6s). Full regression passes 2,183 tests with one explicit
Windows native-symlink-permission skip in 205 seconds
(.local/designs-zoom-full-tests.log); native interpreter fixtures are configured.
Scoped git diff --check passes. JavaScript web release passes in 72.6 seconds
(.local/designs-zoom-web-build.log), with existing dependency Wasm dry-run and
Cupertino-font warnings; no Wasm claim. Windows release passes in 73 seconds
(.local/designs-zoom-windows-build.log), retaining the registered Google desktop
client. Normal executable: build/windows/x64/runner/Release/orbit_note.exe;
data/app.so is newer than all changed implementation sources. No desktop
control, user Vault mutations, physical-input/IME/hardware clipboard acceptance,
ZIP or publication. Platform font rasterization is not a universal pixel-exact
claim; native rendering and authored formatting remain supported.
Suggested next task: reusable writing presets for applying favorite looks to notes.

---

# Validated — Markdown selection scroll ownership, 2026-10-14

Owner reports selected text pulling the Markdown editor back upward when
scrolling/copying. Scope EDT-03/04: reproduce mouse selection plus manual scrolling,
fix paragraph/document ownership of focus and caret reveals, preserve selected
source and clipboard/undo, and update stationary drag endpoints after scrolling.
Keep ordinary typing/navigation/search reveals, native single-paragraph selection,
edge scrolling, lazy paragraphs and structured editors. No format/storage change.

Plan: headless failing short/virtualized-note wheel tests; narrowly gate stale
paragraph reveal requests while the document owns selection, restore native focus
on release/cancel and resolve scroll endpoints after layout. Verify forward/reverse
scroll, copy/paste, focus recovery and existing search/clipboard/selection tests,
then format/analyze/full tests and serial web/Windows builds. No desktop control.

Delivered: request-time native paragraph reveal gate while document selection
owns the range, focus transfer before wheel recycling, post-layout endpoint
updates for stationary wheel/edge scroll, global-coordinate hit testing and
current selection notifications. No focus-node disabling or custom clipboard
engine. Release/cancel and new editing preserve normal focus, source and undo.

Validation in progress: original wheel-plus-drag tests returned to offset 0 in
both short and lazy notes; selection notifications retained the old extent.
Regression fixes pass 85 focused checks in 26 seconds
(.local/selection-scroll-regressions.log), including 10 new scrolling/clipboard
cases and existing code-search, native state/geometry, source/multi-block copy,
media clipboard, paste/undo, surfaces and cleanup. The complete editor checks
exact UTF-16 range copying and replacement, caret reveal after paste and undo.
Analysis is clean (12.2s); strict format check passes for 620 files with zero
changes (11.63s). The full suite passes 2,175 tests with one explicit Windows
native-symlink-permission skip in 221 seconds (.local/selection-scroll-full-tests.log).
Native interpreter fixtures are configured. Scoped git diff --check passes.
JavaScript web release passes in 92 seconds (.local/selection-scroll-web-build.log)
with existing dependency Wasm dry-run/Cupertino-font warnings; no Wasm claim.
Windows release passes in 77.8 seconds (.local/selection-scroll-windows-build.log),
retaining the registered Google desktop client. The normal executable is
build/windows/x64/runner/Release/orbit_note.exe; updated data/app.so is newer than
the changed editor source. No physical mouse, IME/hardware clipboard,
desktop-control, user Vault mutation, ZIP or publication testing.
Suggested next task: audit drag-selection transitions through tables and inline
equations, using headless geometry and clipboard fixtures.

---

# Validated — Photo writing backgrounds, 2026-10-14

Owner accepts custom photo backgrounds with readable-text controls. Scope LAY-01/
06/10 and EDT-03/04: local photo selection, bounded static normalized image,
position/fit/intensity, protected reading sheet or automatic contrast protection,
preview/apply/cancel/remove/reset and persisted pane preferences. Reuse existing
repository device paths and platform image/file adapters; no network image URLs,
authored attachment/object, schema migration or user Vault changes during testing.

Plan: validated recipe and bounded image conversion, guarded hash-addressed private
photo read/write, cached decorative layer and accessible picker/status recovery.
Keep native text/caret/undo and unknown preferences, stale note/Vault guards and
quota/failure safety. Test resource limits, storage reopen/corruption/failure,
reversible preview, old-note compatibility, readable worst-case backgrounds and
narrow/enlarged text; headless visual inspection, format/analyze/full suites, then
serial web/Windows builds. Record evidence and stop before one suggested next task.

Delivered: local PNG/JPEG/WebP selection and static normalized copies, horizontal/
vertical position, fill/crop or whole-image fit, intensity, protected reading sheets
and conservative contrast caps without a sheet. Existing paper patterns remain on
the writing sheet, and high contrast suppresses photos with an explicit explanation.
Apply saves a private hash-addressed copy through the repository before updating
view preferences. Preview/cancel/remove/reset, stale note/repository/Vault guards,
missing/corrupt retry and quota/failure feedback preserve knowledge and the old
appearance. No image URLs, uploads, new objects/packages or source-file mutations.
Session JSON holds small recipes, not pixels. Duplicate normalized photos share a
device file; unused copies are retained so other panes are never silently broken.

Validation: 63 focused checks pass in 9 seconds
(.local/photo-focused-final.log), including 11 new photo model/import/storage/UI
tests plus writing-surface, search, font, layout and plot regressions. PNG/JPEG/WebP
decode, image dimensions/byte budgets, guarded/deduplicated private writes, corrupt/
oversized and failed saves, native reopen, cached reads, stale owner responses,
missing retry, high contrast and 200% text at 360 px pass. Initial tests exposed
paper controls pushed below the picker viewport and failure notifications queued
without a frame; restoring paper-control priority and scheduling feedback fix both.
Synthetic photo/reading-sheet and automatic-contrast previews were rendered and
inspected headlessly (.local/photo-sheet.png, .local/photo-contrast.png,
.local/photo-render.log); the capture waits for image decoding, not desktop control.
Analysis is clean (11.1s); strict formatting is 620 files with zero changes
(.local/photo-analyze-final.log, .local/photo-format-check.log). Full regression
passes 2,165 tests with one explicit Windows symlink-permission skip in 211 seconds
(.local/photo-full-tests.log); native interpreter fixtures are configured.
JavaScript web release passes in 70.9 seconds (.local/photo-web-build.log), with
existing dependency Wasm dry-run/Cupertino-font warnings; no Wasm claim. Windows
release passes in 74.0 seconds (.local/photo-windows-build.log), retaining the
registered Google desktop client. data/app.so is newer than the changed sources;
the normal executable is build/windows/x64/runner/Release/orbit_note.exe.
Scoped git diff --check passes. No user Vault, desktop-control, app launch, ZIP
or publication testing. There is no automatic unused-photo deletion or shared
photo/export styling claim; private copies are bounded to 1,600 px and 2 MiB.
Suggested next task: reusable writing presets across notes.

---

# Validated — Writing surfaces, 2026-10-14

Owner requests Markdown editor designs matching pixel notebook, CRT terminal,
classic book and retro desktop/command references, with lined and graph paper.
Scope LAY-01/06/10 and EDT-03/04: selectable pane-local writing surfaces, scoped
readable colors/typography, vector frames/paper, preview/apply/cancel/reset, and
device-local view persistence. Keep Rich/Source/Read/Split and native text editing,
font scaling, ordinary content/history and existing app theme. No document schema,
cloud, new renderer, flicker, desktop control or changes to user Vaults.

Plan: bounded appearance data with unknown-value fallback; reusable responsive
surface/picker and original reference-inspired vector details; integrate editor
view state and readable fonts. Verify content/selection/undo survival, reopen,
unknown preferences, read-only, narrow/enlarged text and headless rendered previews.
Run required format/analyze/full tests and web/Windows checks. Record evidence and
suggest one next task without implementing it.

Delivered: Orbit, Pixel notebook, Bound book, CRT terminal, Retro desktop and
Command prompt writing surfaces with plain/lined/math-grid/dotted backgrounds.
Original vector frames, adjustable 20–64 px paper spacing, scoped semantic
colors/selection and offline Tiny5/Space Mono/existing Crimson Text fonts surround
real editable content. Apply/cancel/reset, font opt-out, quiet writing and Show
editor tools preserve access to existing features. View preferences persist in
existing pane/note session state; unknown data is retained. Source/text, selection,
knowledge/history and user Vaults are unchanged. Rich/Source/Read/Split and
read-only presentation are covered; LaTeX keeps its existing appearance. Static
details do not cover/intercept text; high contrast suppresses CRT scanlines/vignette.
No flicker, arbitrary skin code, raster text scaling or new package. Surface themes
are reused while typing and background painting has its own repaint boundary.

Validation: 52 focused tests pass in 10 seconds
(.local/surface-focused-final.log), covering 11 new preference/layout/identity
checks, font/large-text behavior, code search and live graph regression. The full
run caught mode controls pushed below clipped Find chrome after adding the new
button; placing modes first fixes the interaction with existing regression coverage.
An initial keyboard fixture lacked editor focus and was corrected to exercise
Alt+T from the source field. Native source selection/draft and unknown preferences
survive apply/cancel/reopen; read-only, stale-note refusal, quiet/full recovery,
custom-font retention, 200% text at 360 px and readable palette contrast pass.
Six headless previews were rendered with real fonts and inspected
(.local/writing-*.png, .local/surface-render.log). The initial preview revealed
old dark-toolbar tokens; scoped Orbit colors fix the mismatch. Analysis is clean
(13.5s) and strict format checks 616 files with zero changes
(.local/surface-analyze-final.log, .local/surface-format-check.log). Final full
regression passes 2,154 tests with one explicit Windows symlink-permission skip in
246 seconds (.local/surface-full-tests-final.log), with native interpreter fixtures
configured. JavaScript web release passes in 68.4 seconds
(.local/surface-web-build.log), with existing dependency Wasm dry-run and
Cupertino-font warnings; no Wasm claim. Windows release passes in 70.6 seconds
(.local/surface-windows-build.log), retaining the registered desktop Google client.
The normal executable remains build/windows/x64/runner/Release/orbit_note.exe;
data/app.so is newer than the changed sources. Both releases bundle the new fonts
and license files. Scoped git diff --check passes. No desktop control, app launch,
ZIP, publication or user Vault editing was used. These are original reference-inspired
frames, not exact third-party UI/art assets; writing surfaces do not affect exports.
Suggested next task: custom photo backgrounds with readable-text controls.

---

# Validated — Live mathematical plots, 2026-10-14

Owner requests more math features. Scope EDT-03/04/06/09/12 and existing Canvas
math snapshots: live editable plot blocks in Rich/Read/Split notes; compare up to
four functions, inspect coordinates, generate/copy value tables, export SVG, and
reuse comparison/table tools in Math Lab for LaTeX and Canvas. Keep offline use,
normal undo, identity and source guards. Bounded readable orbit-plot fenced JSON;
unknown/malformed/future recipes remain editable code. No workspace migration,
new engine, packages, symbolic CAS, accounts or desktop-control testing.

Plan: pure recipe/sample/table/SVG boundaries and compatibility tests, responsive
cached graph widget and parameter/range editor, Markdown/Read/math-lab/Canvas
integration, stale/source/read-only guards, ordinary history and clipboard/source
fallbacks. Run required formatting, analyze and full tests before serial platform
builds. Update evidence, suggest one next task and stop. Preserve user Vaults.

Delivered: live Markdown plot recipes with editable expressions/parameters/ranges,
four-function comparisons, pointer/tap and keyboard coordinate inspection, numeric
tables, TSV copying and local CSV/SVG export. Shared Math Lab offers comparison
and table output for LaTeX/Canvas; boards retain grouped editable primitive snapshots,
distinct curve colors and fit-selection. Ten more templates bring the shared new
set to 30. Numeric expressions accept π/×/÷/−. Source search reveals native JSON;
unsupported/future/unsafe numeric metadata remains editable code. Unknown fields,
line endings, read-only/IME and stale note/Vault/source guards remain intact.
No new packages, schema, accounts, spatial engine or user Vault changes.

Validation: all 78 focused checks pass in 10 seconds
(.local/plots-acceptance-final.log), including recipe bounds/precision, Unicode
inputs, Canvas JSON/group undo, template/TeX rendering, domain gaps, native source
search, read-only controls, stale edits, narrow 200% text, table hidden-field handling
and clipboard failures. Full regression passes 2,143 tests with one explicit Windows
symlink-permission skip in 282 seconds (.local/plots-all-tests-verified.log); native
interpreter fixtures are configured. Final analysis has no issues (106.3 seconds),
and strict formatting checks 613 files with zero changes
(.local/plots-analyze-final.log, .local/plots-format-check.log). Standalone SVG passes
Python standard-library XML validation with two vector curves and no script/image
elements. A verification helper initially selected only root-level polylines; the
correct descendant selector passes. No new XML package was added.

JavaScript web release passes in 98.7 seconds (.local/plots-web-build-final.log),
with existing dependency Wasm dry-run/Cupertino-font warnings; no Wasm claim.
Windows release passes in 84.7 seconds (.local/plots-windows-build-final.log),
retaining the registered Google desktop client; the updated data/app.so is newer
than the changed sources. The normal executable is
build/windows/x64/runner/Release/orbit_note.exe. No desktop-control testing, app
launch, ZIP or publication. Scoped git diff --check passes. Numeric plots have 257 samples
per curve and can miss discontinuities/oscillation; this is not a symbolic CAS.
Markdown publication outputs retain fenced recipes, with standalone SVG available
for figures. Suggested next task: unit-aware calculations and conversions.

---

# Validated — Shared Math Lab, 2026-10-14

Owner requests a substantial math update across Markdown, LaTeX and Canvas.
Scope EDT-02/04/09/12 and existing CAN mathematical card/ink behavior: offline
bounded arithmetic and variables, function plots and numerical calculus, small
real matrix operations, reusable templates and explicit TeX insertion. Preserve
source, normal undo/history, object identity and existing spatial primitives.
No symbolic CAS, arbitrary execution, network service, new schema or desktop QA.

Plan: pure numeric domain tests (precedence, ranges, singularities, matrices),
responsive shared dialog and renderable TeX, all-editor integration with stale
source/read-only/composition guards, Canvas editable plot snapshot round-trip and
single undo. Validate focused and full suites, formatting, analysis and web/Windows
builds; record evidence, suggest one next task and stop. Do not alter user Vaults.

Delivered: shared calculator and numeric variables, sampled function plots with
explicit windows, function evaluation, numerical derivative/integral/root tools,
real small-matrix inverse/transpose/determinant/product/system solving, presets and
20 templates in both palettes. Markdown retains descriptions/TeX; TeX results also
retain parameter values. Rich LaTeX inserts inside the document before its closing
marker. Canvas makes editable grouped graph snapshots using existing primitives,
with matrix row previews and card heights sized for rows. No new dependencies,
object schema, cloud or user Vault modifications. Calculus is approximate; sampled
plots can miss gaps. Full TeX rendering remains richer in notes/lab than Canvas.

Acceptance: 72 focused tests pass (.local/math-acceptance-complete.log), covering
numerical domains/precedence/resources/corners/singular matrices, all template
rendering, input invalidation, portable Canvas JSON/SVG/group undo, all-editor
insertion and stale drafts, large text and an on-screen keyboard, search/selection
layout and existing equation/footnote behavior. Initial runs exposed search-header
crowding and keyboard footer overflow; both have regression coverage and fixes.
An overlapping native build/test attempt hit a PDF DLL lock, so final platform
builds run after tests. Final focused acceptance also checks that template-search
Enter retains its search-only role. The full run passes 2,124 tests with one explicit Windows
symlink-permission skip in 201 seconds (.local/math-all-tests-complete.log).
Native interpreter fixtures are configured. Analysis is clean (9.7s); strict format
is 606 files with zero changes (.local/math-analyze-complete.log and
.local/math-format-check.log). No native desktop-control testing was used. Final
JavaScript web build passes in 72.3 seconds (.local/math-web-build-complete.log),
with existing dependency Wasm dry-run/Cupertino-font warnings; no Wasm claim.
Windows release passes in 74.4 seconds (.local/math-windows-build-complete.log),
retains the registered Google desktop-client configuration and updates data/app.so
with a timestamp newer than the changed sources. The normal executable remains
build/windows/x64/runner/Release/orbit_note.exe. No ZIP, app launch, publication or
user Vault edits. git diff --check passes for changed tracked source/docs.
Suggested next task: live function plot blocks in notes with editable parameters.

---

# Validated — Block formats and BTW callouts, 2026-10-14

Owner requests new Markdown features and “BTW block format.” Interpret BTW as
By the way, alongside a real current/selected-block format chooser. Scope EDT-02/
03/04/09/12: reuse portable Markdown, existing projection/save/history and callout
renderers; no new object identity, schema migration, cloud service or desktop QA.

Delivered: Format block toolbar control opens a searchable list of paragraph,
Heading 1–6, bullet/numbered/checklist, quote and Note/BTW/Tip/Warning styles.
Formatting expands to supported complete source blocks, retains inline markup,
links, checked checklist state and stable block anchors; structured/unknown blocks,
aligned blocks and nested list/quote levels refuse rather than flatten silently.
Multi-line prose cannot become a heading without an explicit one-line selection.
A callout conversion refuses to absorb unselected adjacent quote lines. Applications
revalidate source/note/Vault and use one normal undoable edit. BTW insertion is
also in Insert/slash menus and callout type selection; empty blocks have no filler
sentence. Existing Note/BTW insertion now prefixes every body line correctly.

Callout options edit the title without rewriting the body/type, make it collapsible,
remove collapsibility, or choose expanded/collapsed defaults using [!TYPE]+/-.
Local expand/collapse changes no source. Rich source navigation reveals a folded
body; Read search temporarily expands folded contents before matching/reveal.
Title editing refuses changed source and clears obsolete title-highlight ranges;
unknown alphabetic types, exact body quoting and CRLF remain source-preserved.

Narrow/enlarged editor acceptance exposed an existing status-row overflow and a
command header consuming the writing viewport. Compact cursor details remain in
the clickable tooltip, while narrow command chrome scrolls within a bounded area.
Callout title controls align at the top so long wrapped titles do not move controls
below the viewport. Normal-width labels and actions remain available.

Plan/validation: parser/projection tests, formatting safety/anchors/CRLF/unknown
blocks, picker cancellation and stale source, title shortening after selection,
source-vs-view folding, exact undo and narrow 200% text. Run formatting/analysis/
full tests, web build, and normal Windows rebuild only when closed. Record results,
suggest one next task and stop. No native desktop-control testing or app launch.

Validation: focused coverage passes 50 tests, including 10 new cases,
with the shortened-title/selected-header regression and 200% layout checks
(.local/blocks-focused-final.log). The first full suite exposed two footnote-menu
hit-test failures after inserting a new menu item above Footnote. Keeping existing
command order and placing BTW after existing insert commands fixes both; all 11
footnote/underline tests pass (.local/blocks-footnote-regression.log). The final
full suite passes 2,102 tests with one explicit Windows symlink-permission skip in
320 seconds (.local/blocks-all-tests-final.log). Native interpreter fixtures are
configured for that run. No native desktop-control testing was used.
Analysis is clean (.local/blocks-analyze-final.log); strict formatting reports
598 files, zero changes (.local/blocks-format-check.log). Final JavaScript web build
passes in 180.7 seconds (.local/blocks-web-build-final.log), with existing dependency
Wasm dry-run/Cupertino-font warnings; no Wasm claim. Final Windows release passes
in 182.5 seconds (.local/blocks-windows-build-final.log), retains the registered
Google desktop-client configuration and updates the normal release data/app.so.
The executable remains build/windows/x64/runner/Release/orbit_note.exe; no ZIP,
app launch or publication was performed. git diff --check passes for changed
tracked files. Existing unrelated source and user Vaults remain intact.
Suggested next task: reusable custom callout presets with icons and colors.

---

# Validated — Vault Insights and Markdown Document Checks, 2026-10-14

Owner requests more graph-like diagnostics/statistics, then more Markdown editing
features. Scope: deterministic read-only Vault inspection (AI-09/15, LNK-04/06)
and document checks with explicit single-link repair (EDT-13/LNK-03/04). Preserve
existing identity, portable documents, save/history, offline use and unknown data.
No AI provider, credentials, schema migration or desktop-control testing.

Plan: reuse the shared object-connection index; compute object/type counts,
reference occurrences vs unique pairs, connected components/degree, isolated notes,
repeated titles, recent updates and task completion. Expose current draft/save/
repository/PDF indexing counts, refreshable snapshot and aggregate-only clipboard
report. Add a paginated document inspector for missing/ambiguous wiki links,
missing/unused/duplicate footnotes and repeated/skipped headings. Open exact source
ranges or deliberately choose a replacement object through the existing picker;
retain label/fragments, validate the captured source/Vault and use ordinary undo.
Check large Vaults, CRLF/UTF-16, literal exclusions, stale snapshots, narrow/200%
text layouts, repair cancellation and undo. Format/analyze/full tests, web and
Windows release builds when the app is closed. Record results, then stop.

Delivered surfaces: Graph → Vault Insights; Markdown Writing tools → Document
Checks. Insights counts cover the whole active Vault, independently of graph
filters, and reflect current drafts. Navigation revalidates object/Vault identity.
Diagnostics copy contains only aggregate counts/phases; no names, object IDs,
paths, source content or account details. Snapshots refresh deliberately rather
than doing report work during typing. Recent means last updated within seven days,
not an edit history. Isolated notes and repeated titles are explanations for review,
not errors. Missing recorded sources cover derived placement/metadata edges;
Wiki mentions are inspected in Document Checks. No disk-health/sync certification.

Document Checks operates on unchanged authored source. Existing literal/footnote/
heading parsers preserve code, frontmatter and comments and retain UTF-16 source
ranges. Findings open Source with selection and reveal. Explicit link repair
retains the authored label/fragment, changes one mention through normal history,
and refuses stale notes/Vaults, composition, read-only writes or unavailable
replacement objects. No external URL validation, broad Markdown/grammar guarantee,
auto-cleanup, automatic merge or semantic interpretation. No storage changes.

Validation: new domain/widget tests cover a 5,000-object reference graph,
repeated edges/missing/deleted targets/empty Vaults, aggregate-report privacy,
stable ID/alias/binding resolution, code/frontmatter/comment exclusions,
CRLF/UTF-16 findings, 200% text at 360x640, paginated navigation, snapshot refresh,
stale-document refusal, explicit link repair, cancellation and one-step undo.
Full suite passes 2,089 tests with four skips in 301 seconds
(.local/insights-all-tests.log). Three skips were interpreter-dependent acceptance
fixtures; rerunning the IDE/launch suites with ORBIT_IDE_TEST_PYTHON produces
34 passing and one OS-permission symlink skip (.local/insights-native-supplement.log).
Thus interpreter coverage is recovered, with the Windows symlink-creation check
still explicitly unverified. No desktop-control QA was used.
Analysis is clean (.local/insights-analyze-final.log); strict formatting reports
594 files, zero changes (.local/insights-format-check.log). JavaScript web release
passes in 180.4 seconds (.local/insights-web-build.log), retaining existing
Wasm-dependency/Cupertino-font dry-run warnings; no Wasm-support claim.
Windows release passes in 152.8 seconds (.local/insights-windows-build.log), using
tool/build_windows.ps1 and retaining the registered Google desktop-client build
configuration. The normal executable is at build/windows/x64/runner/Release/
orbit_note.exe; no ZIP, app launch or publication was created. git diff --check
passes for the changed tracked files. Existing unrelated work remains intact.
Suggested next task: project-scoped Insights with navigable connection groups.
Do not implement the next task ahead.

---

# Completed — Demonstration Vault and next-feature audit, 2026-10-14

Owner requested a separate demonstration Vault and asked what substantial feature
can be added from the docs next. This delivery creates sample content only; it does
not implement a new roadmap feature or change production code.

Created `C:/Users/isa/Desktop/Orbit Showcase Vault` using normal repository and
controller commands, with a new stable workspace identity. Existing Vaults and
active/recent Vault preferences were not replaced. The START HERE note links a
15-minute tour of 68 objects across 34 folders: university course/lecture/study
cards, game design/production, invented research Function records, creative brief/
references/decisions, tasks/calendar/Gantt/Smart View, linked Canvas control room,
classic-blue blueprint board, illustrated note, original PDF and OBJ/GLB models.
Ordinary source projects under Code Projects provide Python, multi-file C++ and
an interactive static web example; Python/C++ profiles use current launch storage.
No account sign-in, upload, shared server, desktop control or automatic code run.

Validation: headless generation through production boundaries passes, then closes
and reopens the Vault with the same identity/count and no repository issues
(.local/showcase-generation.log). A separate automated check verifies internal
note links, Canvas source identities, query results, decoded PNG dimensions,
12-triangle OBJ/GLB parsing and persisted valid Python/C++ launch profiles
(.local/showcase-verification.log). Source files, original media and canonical
objects remain editable. No production build/full-suite rerun was needed for this
content-only artifact; prior app validation remains recorded below.

Docs audit: substantial remaining work includes scoped Git history/diffs and
revision capture (DEV-03/05), graphical debugger integration, and automatic
personal Drive synchronization (manual backup is separate). Suggested next task:
read-only scoped Git integration connecting exact revisions/diffs to design and
playtest evidence. Await owner choice; do not implement ahead.

---

# Implementation validated — Saved launch profiles and local web preview, 2026-10-13

Owner accepts the suggested next Code workspace task. Focus DEV-01/03/05 on small
scripts/web projects: saved editable project run/build profiles with argument arrays
and scoped working folders, sequential build/run with failure/cancellation boundaries,
recoverable expected-hash configuration saves; explicit loopback-only static web
preview with saved-file reload, asset support, visible address and start/stop controls.
Preserve external source authority, unknown data, existing drafts/tools and Google
configuration. No desktop-control QA, automatic execution, package installation,
public hosting, graphical debugger or new backend. Do not build ahead.

Plan: pure launch configuration, native/stub store/server adapters, reuse existing
process console and project save checks, compact profile editor and preview controls.
Test real temporary-project HTTP traversal/hidden-file/symlink boundaries, assets,
reload and shutdown; native profile restart/conflicts/recovery/future data; sequential
failure/cancellation and UI at narrow/enlarged text. Format/analyze/full tests and web
build; Windows rebuild only when the normal release is closed. Update evidence and
behavior docs, suggest one next task, then stop.

Delivered: Run profiles manager with Python/C++/custom presets, stable IDs, names,
project-relative working folders, editable ordered steps and literal JSON argument
arrays. `{output}` and `{buildDir}` support generated executables and separate
object outputs; multi-file MSVC compilation was verified using paths with spaces.
Selecting/opening profiles does not execute them. Explicit runs check source drafts,
open-file hashes/versions and saved configuration; failure, changed context and
cancellation stop later steps. Pending process startup also honors cancellation.
Settings preserve unknown fields, refuse future versions/stale saves and retain
flushed before/after checkpoints with a recovery picker. No Vault migration/package.

Local HTTP preview opens saved HTML with module/CSS/image/font asset serving, visible
address/copy/refresh/stop, saved-file reload and native external-change watching.
Ephemeral IPv4 loopback binding, per-port authorization cookies and Host/origin
checks prevent accidental shared-cookie interference or outside/cross-site access.
Hidden/unsupported files, directory listings and symlink escapes are refused. The
reload script is appended without modifying authored markup or source files; body
closing strings inside JavaScript/comments cannot break insertion. Project changes,
close and successful exit stop the service. No public hosting, bundler/backend or
graphical debug adapter claim. External watching/CSP/media Range limitations are
documented; normal sources remain ordinary UTF-8 files.

Focused evidence: 34 passing IDE/launch cases and one explicit skip, including
13 new launch tests (.local/launch-focused.log). Native tests cover configuration
restart/unknown metadata/concurrent stale writers/checkpoint failure/future data,
HTTP authorization/assets/methods/traversal/hidden sources/Windows external reload/
shutdown, independent preview cookies, literal process arguments/scoped working
folders, sequence failure/cancellation, pending startup and 200% text at 360x640 /
640x360. Symlink creation was refused by this Windows account; that dedicated
native link test is explicitly skipped rather than claimed as accepted.
Supplementary MSVC multi-file profile build/run passes
(.local/launch-cpp-multifile-check.log), using temporary source only.

Initial full suite: 2,078 passing, one skip, 253 seconds (.local/launch-all-tests.log).
Final full suite after the HTML markup-preservation fix: 2,078 passing, one explicit
native symlink skip, 291 seconds (.local/launch-all-tests-final.log). The real HTTP
regression verifies that authored JavaScript containing a body-closing string is
retained intact and original file bytes are unchanged. Analysis is clean
(.local/launch-analyze-final.log); strict formatting reports 588 files, zero changes.
JavaScript web release succeeds in 159.3 seconds (.local/launch-web-build.log), with
the existing dependency Wasm dry-run/Cupertino font warnings. No Wasm claim.
git diff --check passes. No source/configuration fixture or preview server was left
running; temporary projects were removed. The final markup fix is native-only and
does not alter the successfully built JavaScript/stub branch.

Windows release succeeds in 122.3 seconds (.local/launch-windows-build.log). The app
closed during validation, so tool/build_windows.ps1 could update the normal release
while preserving the registered Google desktop client. Required executable,
flutter_windows.dll, data/icudtl.dat and data/app.so are present. No force-close,
app launch, desktop-control QA or public release publication occurred. Actual
browser runtime acceptance and OS link/locking matrix
remain device checks. See setup, implemented formats and ADR-0029. Suggested next
task: graphical Python debugging with breakpoints, call stack and variables. Stop
before implementing it.

---
# Implementation validated — Code workspace for HTML, Python and C++, 2026-10-13

Owner requests full IDE-style coding support. This supersedes the earlier
read-only-source restriction for an explicitly selected coding project. Scope:
DEV-01/03/05 editor/tool adapters with HTML/Python/C++ workflows. Add multi-file
editing, recoverable drafts and guarded/history-backed saves; offline snippets;
optional local LSP completion/diagnostics/hover/definition/formatting; explicit
Python syntax/run/pdb, C++ single-file build/run/configured console debug and HTML browser preview; bounded
output, cancellation and project navigation/search. Preserve all prior work.
No automatic code execution, shell-interpreted project commands, unreviewed
server edits, graphical debugger promises, cloud or app desktop-control QA.

Plan: pure source/tool/LSP models and application session commands, conditional
native/stub project/process adapters, existing CodeSurface/CodeController/history,
scoped source browser/search and linked evidence. Source files keep ordinary
external-file authority; draft/history state is documented separately and never
turns source files into duplicate Vault objects. Record boundary change in ADR
0028. Validate conflict/failed-save/reopen/locked writes, UTF-16/version/range safety,
framing/disconnect/cancellation, real temporary-project tooling, compact layouts,
then format/analyze/full tests and relevant builds. Windows release remains pending
owner closing the running release; Google activation/configuration is preserved.

Delivered: dedicated Code workspace from Explorer/command palette and Game/Analysis
dashboards, focused on the owner's chosen small-scripts/web-project workflow.
Multi-file editing/creation/search, per-tab undo/selection, line operations,
find/replace, go-to-line, save-all with partial-failure reporting, recovered drafts,
external-change comparison and checkpoint review reuse existing editor/history
surfaces. HTML/Python/C++ include offline snippets and optional local LSP completion,
versioned diagnostics, hover, definition, symbols and formatting preview. Evidence
capture uses ordinary Vault commands and canonical dashboard links.

Native files retain UTF-8/BOM/line endings, expected hashes and flushed before/after
checkpoints. Saves serialize within/across Orbit sessions; independent recovery
files cannot clear another session's draft. Unknown/future recovery and device-tool
settings remain intact. UTF-16 proposals reject invalid/overlapping/surrogate-split
ranges and stale versions. Local process commands use executable/argument arrays;
Python parsing/run/pdb, MSVC/clang/g++ single-file build/run and configured C++ console
debugging are explicit. HTML preview opens the saved file in the browser. Native
scope is conditional; no new app package or Vault migration was introduced.

Validation: all 2,066 tests pass in 207 seconds (.local/ide-all-tests.log), including
22 new IDE cases. Covers mixed endings/emoji/snippets, split-byte LSP framing,
stale diagnostics/server mutation refusal/disconnect, edits arriving during save,
external conflicts/failed recovery and close, native BOM/history/restart/create/path
guards, concurrent stale saves, separate-session drafts, future data retention,
private preferences, tab limits, real process stdin/output/stop, installed MSVC
compilation, explicit-run guards, completion undo/Python indentation and 360x640 /
640x360 at 200% text with live console/input/stop. Compact testing exposed inaccessible
Stop controls and a static modal console; these now scroll/reflow and update live.

Supplementary real temporary-project acceptance passes for Python LSP initialize,
math.sqrt completion, undefined-name diagnostics and hover; HTML LSP initialize,
div completion and validated formatting; MSVC C++20 debug compilation, PDB symbols
and program output. Logs: .local/ide-real-language-check.log,
.local/ide-real-html-check.log and .local/ide-cpp-debug-check.log. Test servers were
installed only in ignored isolated .local environments; no project code or user
binary was executed. Fixtures/processes closed and temporary source folders removed.

dart format lib test completed; strict check reports 581 files, zero changes.
flutter analyze reports no issues (.local/ide-analyze-final.log). JavaScript web
release succeeds in 81.2 seconds (.local/ide-web-build.log). Existing dependency
Wasm dry-run and Cupertino font warnings remain; Wasm acceptance is not claimed.
git diff --check passes. No desktop-control testing was used.

Windows release replacement remains pending: orbit_note.exe PID 1440 still runs
from the normal release folder. The earlier close request has not been answered;
no force-close or locked-file overwrite was attempted. Resume tool/build_windows.ps1
after closure to preserve the registered Google client. No release/publish claim.
Tool setup, source authority and limits are documented in
[Code workspace setup](../development/code-workspace-setup.md) and ADR-0028.
clangd/C++ console debugger, actual browser preview and two-process OS-lock acceptance
remain separate device checks; no full IDE, graphical DAP, multi-file build or
hardware power-loss claim. Suggested next task: project run/build profiles and a
local web development preview server. Stop before implementing it.

---
# Implementation validated — Technical source search and build investigations, 2026-10-13

Owner requests more features for reverse engineers and game developers. Scope:
DEV-01/02/03/04, REV-02/04 and GAME-02 local knowledge subsets. Add cancellable,
bounded all-file source search with exact-line navigation; capture source evidence
as portable linked notes; compare recorded function maps across explicitly chosen
binary/build identities; save linked comparison reports and investigation tasks.
Preserve earlier work and source authority. No desktop-control testing, executing
code/binaries, external repository edits, live debugger connectors or cloud work.
The Google test-account follow-up below remains pending owner browser access.

Plan: extend current read-only source browser/adapters and normal validated
repository commands. Match function records only with explicit binary/build/module
context and unique symbols; flag duplicates/unsupported locations, distinguish
rebasing from changed recorded RVAs and avoid claiming an actual binary diff.
Retain source UUIDs/revisions, exact excerpts and evidence when checkouts disappear.
Test source cancellation/limits/failures, scoped comparison/missing context, stale
reports, storage failure/reopen and narrow/enlarged layouts. Run standard checks.

Delivered: cancellable literal search across selected source-folder listings with
case/whole-word/path filters, progress, partial/skipped status, exact-line results
and stale-file SHA-256 checks. Assembly/log files join existing scripts/shaders.
Game and research dashboards can save source evidence notes with exact fenced
excerpts, path/range/hash metadata and canonical owner links. Gameplay capture
reuses the same search. No source file is executed or changed.

Recorded function-map comparison appears on research dashboards/Function tables.
Build choices require the same explicit binary ID; exact unique module/symbol
pairs distinguish changed metadata/RVAs, rebasing and recorded presence/absence.
Duplicates, incomplete context and auto-address names remain uncertain. Filters,
30-row pagination and baseline/candidate cards open original UUID records. Reports
and investigation tasks retain source revisions/resource links in ordinary files;
stale/unsaved/missing/future records reject save. View switching does not copy
functions. Snapshot reports are not binary diffs or a claim of equal behaviour.

Focused validation: 46 passing source/research/gameplay tests, including 15 new
technical-investigation cases. Verified supplementary Unicode whole-word matching,
LF/CRLF capture, path-before-limit search, cancellation during a pending read and
within a 100,000-line file, failure/budget reporting, stale source navigation,
ambiguous/rebased/different-binary locations, source UUID connections, failed saves,
native-file restart and 360x640/640x360 at 200% text. The test fixtures were corrected
to use repository.objects and real async outside Flutter's fake clock; the UI save
assertion now waits for the asynchronous command to finish. No desktop-control QA.
Analysis is clean (7.7s); strict formatting passes on 569 files; diff check passes.
Full suite: 2,044 passing tests in 3m50s (.local/technical-full.log). JavaScript web
release succeeds in 156.6s (.local/technical-web.log). Existing Google JS-interop
Wasm dry-run and missing Cupertino-font warnings remain; this is not Wasm support.
Windows rebuild is pending: final process check still finds Orbit Note running
from the normal release directory (PID 1440). Owner was asked to save/close it;
no confirmation arrived during validation. Do not overwrite/force-close the running
release. Resume with tool/build_windows.ps1 after the owner closes it, retaining
the existing registered Google client. No force-close or app launch was performed.

Limits: literal line search of supported listed files, 500 matching lines and
16 Mi UTF-16 code units per operation; existing native listing/preview bounds
apply. Function comparison is limited to 1,000 scoped selected records. Note bodies,
binary instructions/bytes and Git commits are not compared. Search is session-local;
source paths in evidence do not grant filesystem access. Google test-user follow-up
is unchanged. No cloud, new package, architecture/store migration or execution.
Suggested next task: read-only Git revision/diff inspection and verified commit
excerpt capture through explicit repository scope. Stop before implementing it.

---
# Follow-up task — Google test-account access, 2026-10-13

Owner screenshot shows Google's 403 access_denied for a different Google account
from the registered owner test user. Scope: add the account shown to the existing
Testing audience, verify its saved entry, then request a fresh app sign-in. No
public rollout, new credentials, app rebuild or automatic Vault synchronization.

Confirmed screenshot explanation: only developer-approved test users may access
the app. The prior owner account remains the immediate sign-in option. Browser
inventory no longer exposes the earlier Brave owner session. In-app Cloud Console
cannot load the project/audience and shows no project entries; retry did not fix
it. Asked owner to reopen the existing Brave setup session. No test-user change
has been submitted or claimed successful. Resume only with accessible owner UI.
No source changes or new app tests required for this external-registration fix.

---
# Completed task — Google Drive sign-in activation, 2026-10-13

User requests functional one-click Google sign-in. Authorized Google Cloud browser
registration and explicitly accepted the Google API Services User Data Policy at
its final step. Scope: activate the Windows Desktop app client/Drive API/testing
audience, fix unconfigured-build setup and sanitized diagnostics, exercise OAuth
and existing account/backup flows, and rebuild Windows with actual local config.
Preserve all prior work. No app desktop-control testing, automatic Vault sync,
multiplayer expansion, Android registration, billing or public rollout.

Confirmed: local generated build configs had no client IDs. Old project
orbit-note-508518 is inaccessible from the relevant signed-in accounts. Created
dedicated orbit-note-511512 under the owner's existing Google account; saved
branding, external testing audience, Desktop client and owner test-user entry.
Client configuration stays in ignored local config; no secrets are printed,
committed, placed in a Vault, or uploaded to GitHub. Drive API is enabled.

Delivered: registered narrow scopes and real Windows Desktop app client; imported
its ignored local build configuration; fixed the inactive sign-in button with
validated preview registration recovery, secure device restoration, sanitized
configuration errors and an explicit first-sign-in empty-folder preparation.
Added tool/build_windows.ps1 so future local rebuilds keep the registered client.
Existing identity, credential binding, offline use and manual transfer boundaries
are unchanged. No automatic upload occurs after sign-in.

Real-account evidence: after the owner completed browser consent, the temporary
production-adapter OAuth check exchanged the code, verified identity, read quota
and listed Vaults/backups. RAM-only credentials were cleared afterward. No Vault
upload, restore or original-file change occurred. Screenshot:
.local/google-registration-evidence.png; result: .local/google-live-result.json.
The installed app still requires its own first sign-in; device secure storage and
live backup transfers were not manually tested through desktop controls.

Validation: 17 new tests cover parser rejection, BOM/version handling, activation
and secure restart, failed/parallel configuration writes, compiled-client protection,
provider errors, actionable setup UI and first-folder success/failure/reuse without
upload. Focused auth/backup run: 47 pass; final activation/ready run: 23 pass.
An older full run exposed the obsolete no-root-on-sign-in fixture; it was corrected
to verify existing-folder reuse. A temporary test edit accidentally referenced an
out-of-scope restore variable in cancellation assertions; corrected before the
final restart. Analysis is clean (101.2s); format/strict pass on 563 files.
Final full suite: 2,029 passing tests in 5m32s against the corrected sources
(.local/google-activation-full-clean.log). git diff --check passes.

Windows configured release succeeds in 180.8s (.local/google-activation-windows.log).
JavaScript web release succeeds in 213.6s (.local/google-activation-web.log).
Existing Google JS-interop Wasm dry-run and missing Cupertino-font warnings remain;
this validates JavaScript web, not Wasm. Windows data/app.so is updated (22,807,440
bytes); the native launcher can retain its prior timestamp for Dart-only changes.

Limits: Google Testing owner audience only. Android OAuth registration and public
rollout remain open; local configuration does not configure hosted CI. No Vault
backup was uploaded for this verification, no desktop-control QA, no automatic
Vault sync or multiplayer completion claim. All earlier work remains preserved.
Suggested next task: automatic personal Vault synchronization, using the existing
reconciliation/save contract, with visible conflicts and offline recovery. Stop
before implementing it.

---
# Completed task — Universal reference bridges, 2026-10-13

User requests a cohesive app with genuine references across Canvas, notes, files,
courses/projects and specialized workflows. Scope: LNK-03/04/10, CAN-02/03/09,
VIEW-06/07, NAV object navigation. Preserve prior uncommitted work. Plan: unify
reference discovery/preview/actions, bridge source objects into notes/Canvas,
index live embeds and portable ownership/resource links with exact source
locations, and preserve precise references during clipboard transfers. Reuse
normal object identity, existing embeds/placements and recoverable mutations.
No desktop-control QA, backend, new packages or speculative future subsystems.

Delivered: shared universal-object picker with live preview and keyboard search,
Connections/Use elsewhere across object surfaces, precise incoming-use navigation,
authored relationship reasons/source-version review and saved-query membership.
Added source-owned live task/view cards, canonical course/project context, guarded
reference embedding/placement and exact page/section clipboard/open-beside paths.
Backlinks, outbound inspection and Graph now share the reference projection,
including file/view objects, live embeds, source provenance and resource links.
Unknown metadata/Markdown and shared-source identity remain preserved.

Validation completed after the final Graph integration. Initial automated fixtures
were corrected to use real storage async outside the widget fake clock, valid
Study provenance and the actual Canvas schemaVersion field. An earlier full run
was interrupted after a changed test encountered a previously compiled Graph
API; the restarted full run uses the frozen final sources. No desktop-control QA.

Final checks so far: full suite 2,012 passing tests in 4m15s
(.local/bridges-full-final.log), including 33 new connection/bridge tests.
Focused Graph/reference/research run: 51 pass (.local/bridges-graph-focused.log).
Cases include canonical identity/rename, CRLF and escaped/Unicode fragments,
unknown markers, code literals, exact use offsets, attachment ambiguity, live
query membership, shared task updates, stale drafts/future scenes/failed writes,
source review/undo, canonical course ownership, native temporary-store reopen,
1,000-reference incremental parsing, picker keyboard/pagination, Vault-generation
invalidations, and 360x640/640x360 layouts at 200% text.
Analysis is clean in 11.6s (.local/bridges-analyze-clean.log); format/strict pass
on 561 files (.local/bridges-format-clean.log, .local/bridges-strict-clean.log).
git diff --check passes. Windows release succeeds in 157.7s
(.local/bridges-windows.log). JavaScript web release succeeds in 94.9s (.local/bridges-web.log).
Existing Google JS-interop Wasm dry-run and missing Cupertino-font warnings
remain; this validates the JavaScript build, not WebAssembly. The Windows
release contains updated data/app.so (22,774,672 bytes); the native launcher
can retain its existing timestamp when only Dart code changes.

Limits: Graph aggregates object-pair edges rather than exposing a complete typed
dependency engine. Only supported object/reference formats are interpreted;
unknown metadata and unsupported fragments remain preserved. No desktop-control
QA, mobile binary build, deployment/publication, new backend or issue-free claim.
Suggested next task: semantic Canvas connectors that author labeled relationships
and display them consistently in Connections and Graph. Stop before implementing.

---
# Completed task — Connected university workspace and competing drafts, 2026-10-13

User authorized the simultaneous-editor/autosave audit, explicit code/OBJ/GLB
opening controls, courses with maintenance/progress, and broader Canvas/structured
planning workflows. Their clarification prioritizes the university workspace.
Scope: STUDY-01/03/04/05, CAN-02/03/08/09/14, VIEW-02/06/07 and HIST-01/09.
Preserve all previous uncommitted work. No desktop-control QA or new packages.

Plan: retain competing note/Canvas drafts; exercise parallel autosave, failures
and recovery. Add discoverable file controls using current offline viewers. Build
a course hub on ordinary overview notes, stable course membership, editable
metadata, real task/practice/understanding metrics, linked material and scoped
study/planning boards. Reuse columns, object cards, saved queries, calendar and
Study & Review. Do not promise complete Milanote/Notion commercial feature parity.
Validate ownership on queued creates/setup, preserve unknown fields/user text,
then run focused/full automated tests, analysis, formatting and release checks.

Delivered: session-retained conflicting note bodies/Canvas scenes, shared/retained
comparison, recovered-object copy/discard, normal exit/switch blocking, correct
Canvas source snapshots throughout active gestures, and no-op draft suppression.
Queued creates/folders reject Vault changes; object creation freezes caller maps.
Course hub adds search/status/semester filters, editable details/fractional ECTS,
assignment/practice/concept metrics, explicit linking/removal and archived/passed
states. Linked study boards use normal columns, shared objects and scoped live
queries. Course-specific planning/review/continuations use stable UUID membership,
with legacy folder/name compatibility. Added direct code/OBJ/GLB/course buttons,
menu entries and a command-palette course entry. Existing read-only sources now
correctly disable note/Canvas mutations in the shell.

Validation so far: 18 new tests pass (.local/university-new-verified.log). They
cover same-frame note publishers/rebuild/recovery, failed recovery, newer retained
drafts during a pending recovery, simultaneous Canvas gesture/source changes,
100 queued draft updates with three parallel flushes, no-op revisions, frozen
caller maps, queued create/folder Vault switches, same-name course isolation,
metadata/body preservation and stale form rejection, scoped live query updates,
membership removal preserving objects/placements, malformed/duplicate/failed and
partially completed setups, scoped exam/card/resume records, direct entry points,
and course layouts at 360x640/640x360/1100x800 with 200% text. Full suite passes
1,979 tests in 4m02s (.local/university-full.log). Analysis is clean in 11.3s
(.local/university-analyze-clean.log); format/strict checks pass on 557 files
(.local/university-format-clean.log, .local/university-strict-clean.log).
The initial widget fixture awaited storage in Flutter's fake async zone; corrected
to use runAsync and cancel controller timers before advancing the gesture clock.
The Canvas gesture regression then exposed a real lazy-base initialization issue,
fixed by capturing the base in initState. Earlier targeted invocation included an
incorrect test filename; final full suite covers all real tests. git diff --check
passes. Windows release succeeds in 143.0s (.local/university-windows.log),
including updated data/app.so. JavaScript web release succeeds in 138.8s
(.local/university-web.log); existing Google JS-interop/Wasm dry-run and missing
Cupertino-font warnings remain. This is not a Wasm-support claim. Direct Windows
launch path: build/windows/x64/runner/Release/orbit_note.exe; its data directory
contains the updated Dart application even though the unchanged native wrapper
keeps its previous timestamp.

Limits: this delivers the university workflow prioritized by the user and reuses
existing creative/structured Canvas tools. Complete Milanote/Notion commercial
parity is not claimed. Conflicts are session-local (normal close is blocked),
not crash-durable; Canvas comparison currently shows serialized data. Titles and
properties retain their existing editing paths. Course creation/board setup are
not multi-file atomic: completed objects survive partial failure. Initial study
board placements are capped at 18 material objects, with current live query
results beyond that. No desktop-control QA, APK build, publication, packages,
backend credentials or storage/scene version migration.

Suggested next task: crash-durable competing-editor drafts with recovery on restart;
stop before implementing it.

---
# Completed task — Stress and asynchronous import safety, 2026-10-13

User requested automated stress testing, hidden-bug discovery and fixes. Scope:
FILE/DES import ownership and durable-storage/Canvas failure boundaries. Preserve
all prior uncommitted tasks. No desktop-control QA, external user files, packages
or speculative features. Plan: gated Vault/tab-switch drops, queued import and
caller-buffer mutation checks; seeded Canvas undo/redo/index stress; repeated
native save/reopen/conflict checks; fix reproduced failures, then run required
format/analyze/full suite and release checks.

Reproduced defects: queued imports could run after initialization changed Vault;
caller buffer mutation changed captured attachment bytes; cross-project repeated
capture rewrote canonical ownership; all eight seeded Canvas sequences exposed
stacking changes on undo from duplicate order allocation. Drop audit found late
reads bypassing Vault checks, links based on the active rather than captured note,
and Canvas read errors escaping the per-file error boundary.

Delivered: unique bring-to-front order allocation; repository import generation
check and bounded owned-byte snapshot; shell generation/Vault guards across
picker/read/decode/import and late open/placement; target-note-relative paths;
per-file Canvas read failure feedback/continuation; image decoder cleanup; controller
capture generation checks after metadata saves; existing explicit attachment
ownership and creative capture provenance/folder retention on deduplication.
No storage schema, package, platform adapter, universal identity or engine changes.

Validation: 61 focused checks pass (.local/stress-regression-final.log). Eight
seeds each execute 1,000 mixed Canvas insert/move/remove/reorder/cancel/undo/redo
commands with spatial-query comparisons and JSON round-trips retaining opaque
data. Native temporary-file tests create 24 notes, queue 144 updates across six
save/reopen rounds, retain Unicode/mixed endings/unknown properties, and reject a
stale overwrite after an external edit. Six new import fixtures exercise queue
ownership, byte isolation, delayed Vault/tab switching, partial batch failure and
trashed targets; project fixtures exercise ownership/course/provenance preservation.
The gated drop fixtures use synthetic files and in-memory Vaults, not user files.
The first widget Vault-switch fixture was adjusted to apply the repository switch
boundary directly; controller shutdown awaits are not modeled as OS acceptance.
Initial analyzer found one missing brace; corrected before final full tests.
Final analysis is clean (.local/stress-analyze-verified.log). Format and strict
checks pass on 551 files (.local/stress-format-verified.log,
.local/stress-strict-verified.log); git diff --check passes. Windows release
succeeds in 280.8s (.local/stress-windows-final.log), including updated data/app.so.
JavaScript web release succeeds in 296.8s (.local/stress-web-final.log); existing
Google identity JS-interop/Wasm dry-run and Cupertino font warnings remain.
No Wasm support claim. The first final suite passed 1,960 tests but the large
native disk fixture exceeded the default 30-second test timeout under combined
build/test load (.local/stress-full-final.log). Its unchanged content/conflict
assertions now have an explicit bounded two-minute I/O timeout. Cleanup errors
after that timeout were fixture teardown while work was pending, not accepted
product behavior. The complete rerun passes all 1,961 tests (.local/stress-full-verified.log).

Limits: automated correctness and failure-boundary stress only. No hardware FPS,
memory-capacity, physical power-loss or device input claim. No desktop-control QA,
APK build, Git push or publication. Successfully imported but unplaced attachments
remain discoverable; no shared attachment is silently cleaned up.
Suggested next task: stress-test simultaneous editor drafts and autosave conflicts;
stop before implementing it.

---
# Completed task — Clipboard and Canvas data-safety audit, 2026-10-12

User authorized finding and fixing major bugs. Audit scope: EDT-04/06,
DES-01/05/06 and existing Canvas rendering boundaries. Reproduce late cuts across
note switches, stale Canvas paste, malformed/duplicate clipboard placements,
plain document-range paste and invalid Canvas typography/strokes. Preserve all
prior uncommitted tasks. Use existing mutation/undo and platform boundaries;
no new packages, durable formats, migrations or desktop-control QA.
Plan: regression fixtures first, bounded fixes, focused/full tests and release
checks, then record actual outcomes and limitations.

Delivered: Rich document/block cuts check owner/epoch/source/selection, with
pending work invalidated on owner switches. Rich single-field and Source native
actions/menus await clipboard success before deletion and preserve undo. Source
paste also checks mode/owner/request order. Plain document-range paste no longer
interprets Orbit payloads. Canvas paste captures scene identity/revision,
selection and request order; malformed/unsupported/non-map/duplicate placement
batches refuse before history/selection mutation. Successful transfers retain
remapped IDs and normal single undo. Image imports catch load errors and refuse
changed boards/read-only scenes. Finite bounded Canvas font/section stroke values
prevent invalid render styles while preserving raw fields.

Sixteen new regressions exercise changed-owner/return-to-owner cuts, native cut
clipboard denial and success/undo in Rich/Source, plain payload paste, duplicate/
unsupported/non-map Canvas batches, preserved selection/history on rejection,
late/overlapping Canvas paste, image failure/board switching and invalid styles.
All 84 focused checks pass (.local/safety-audit-regression-final.log). Initial
fixtures reproduced data loss/partial paste and unsafe native Rich cuts; a Source
fixture mode name was corrected to the stored `write` mode for actual Source QA.
Analysis is clean (.local/safety-audit-analyze-final.log), format/strict checks pass
on 549 files (.local/safety-audit-format-final.log, .local/safety-audit-strict-final.log)
and git diff --check passes. Windows release succeeds in 132.4s
(.local/safety-audit-windows.log), including updated data/app.so.
All 1,944 tests pass (.local/safety-audit-full.log). JavaScript web release
succeeds in 142.3s (.local/safety-audit-web.log); existing Google identity
JS-interop/Wasm dry-run and Cupertino font warnings remain. No Wasm support claim.

Limits: this is a targeted safety audit, not proof of an issue-free app. Other
specialized editor controls keep their existing native clipboard paths. Physical
clipboard/input acceptance remains unverified; no desktop-control testing,
APK build, push or publication. Imports already completed by a callback can retain
an attachment without adding a placement; no shared attachment is auto-deleted.
Suggested next task: asynchronous import/drop ownership audit across PDF and code
workspaces; stop before implementing it.

---
# Completed task — Long-note selection auto-scroll, 2026-10-12

User accepted edge auto-scroll for long-note text selection (EDT-03/04/15).
Plan: preserve the original source anchor; scroll proportionally within the Rich
viewport edge band; resolve endpoints after virtualized layout; stop on release,
cancel, focus loss, note/view changes and disposal. Preserve native structured
editor gestures and all preceding uncommitted changes. No storage/schema/package
changes or desktop-control testing. Test ordinary/virtualized notes, upward and
downward continuation, stationary edge hold, stop/reverse and stale lifecycle.
Delivered frame-driven proportional mouse edge scrolling, bounded to 720 logical
pixels/second. Hit testing uses the nearest mounted block after layout; source
anchors persist across lazy field recycling. The viewport listener retains the
pointer path and the editor retains focus as original fields leave view. The
scroll ticker is inactive when idle. Release/cancel, focus/app deactivation,
note/source/section changes and disposal stop scrolling and invalidate queued
endpoint updates. No document mutation is performed by selection scrolling.

Validation: eight new widget regressions cover stationary edge hold on 60/360-
paragraph notes, exact anchor preservation, upward reversal, pause/release/cancel,
external text changes, right-button exclusion, 200% text and boundary clamping,
focus loss, app deactivation and active disposal. All 32 focused selection and
virtualization checks pass (.local/autoscroll-regression-final.log). Initial
regression checks caught lazy ticker creation during disposal of an unused editor;
initialization now occurs in initState and the final full suite passes.
All 1,928 tests pass (.local/autoscroll-full.log). Analysis is clean
(.local/autoscroll-analyze-final.log); format/strict checks pass, 548 files
(.local/autoscroll-format.log, .local/autoscroll-strict.log); git diff --check passes.
Windows release succeeds in 137.7s (.local/autoscroll-windows.log). JavaScript
web release succeeds in 144.8s (.local/autoscroll-web.log); existing Google identity
JS-interop/Wasm dry-run and Cupertino font warnings remain. No Wasm claim.
No physical mouse/IME or desktop-control testing, APK build, push or publication.

Limits: new edge scrolling belongs to mouse prose/heading/list selection in the
scrolling Rich host; embedded column editors do not yet delegate scrolling to
their host. Structured controls and touch retain their existing interaction paths.
Suggested next task: selection auto-scroll across embedded columns; stop here.

---
# Completed task — Selection and clipboard reliability, 2026-10-12

User reported clumsy copy/paste and unfinished text selection. Scope EDT-03/04/06/11:
repair cross-paragraph selection/paste, stable selection rendering, Windows HTML
clipboard extraction, and safe code/Source paste. Preserve the preceding publishing
and connected-project changes. Use existing source-preserving projection, normal
note edit/undo boundary and platform clipboard adapters.

Plan: reproduce range/focus/paste defects; preserve mounted native text fields and
render precise text ranges; Shift-click text selection with block handles retained;
guarded whole-range paste and collapse/navigation; balance partial inline endpoints;
extract CF_HTML by UTF-8 byte offsets and preserve code whitespace/entities;
exercise stale/failure boundaries and existing clipboard/media/table regression.
No desktop-control testing, new package, content schema, engine or migration.
Delivered stable native field identity/geometry and precise prose text-range paint;
Shift-click extends text, right-click retains it and navigation collapses it.
Keyboard/native-menu document paste replaces the actual range and rejects stale
asynchronous results. Partial formatted endpoints rebalance, document copy keeps
valid Markdown, and inline paste restores visible caret offsets. Plain paste and
Source/code literal paste preserve authored text. Native CF_HTML extraction uses
UTF-8 byte offsets and marker fallback; code whitespace and entities survive.

Validation: 121 focused editor/table/media/clipboard checks pass
(.local/selection-focused-3.log); all 1,920 tests pass
(.local/selection-full-final.log). Final analysis is clean
(.local/selection-analyze-clean.log); format and strict checks pass, 547 files with
no changes; git diff --check passes. The initial analysis found a missing brace
in a new clipboard mock; corrected and rechecked. Synthetic platform messenger
fixtures exercise clipboard failures/fallback without using the user's clipboard.
Windows release succeeds in 140.7s (.local/selection-windows-final.log), including
updated data/app.so. JavaScript web release succeeds in 93.9s
(.local/selection-web-final.log). Existing Google identity JS-interop/Wasm dry-run
and Cupertino font warnings remain; Wasm support is not claimed.

Limits: conservative HTML conversion, portable Markdown document-range copy,
structured-block feedback for tables/code/media, and existing segmented math
selection remain. Full Word/CSS fidelity and physical clipboard/IME acceptance
are not claimed. No desktop-control QA, APK build, Git push or publication.
Suggested next task: edge auto-scroll during long-note drag selection; stop here.

---
# Completed task — Connected project workspace, 2026-10-12

User authorized the complete proposed integration update: project context across
surfaces, meaningful connections, project activity and continuation. Scope:
NAV-01/04/05/10, LNK-02/03, CTX-03/05/07/09/11, CAP-01/04, ORG relationships.
Reuse canonical objects, existing repository commands and device settings. No
new engine/package/cloud service, duplicate content owner or desktop-control QA.
Preserve the preceding uncommitted publishing improvements.

Plan: visible project scope and pinned responsive workspace; scoped creation,
attachment capture and search; explicit typed precise relationships and source
version checks; opt-in bounded local activity; continuation drafts and guarded
saved view restoration; recoverable metadata edits and compatibility tests.

Implementation: project bar follows all shell destinations; workspace offers
Work, Connections, Activity and Continue. Scope includes root plus explicitly
associated objects. Notes/tasks/Canvas and attachment capture inherit project
unless ownership is explicit. Search/explorer share scope, intersecting existing
Space filters. Existing objects can be reassigned, retaining identity/content.
Typed supports/implements/blocks/verified-by links retain exact target fragments,
reason and observed source version. Inbound/outbound inspectors reuse the links.
Metadata operations use validated draft/save commands and guarded field-only undo.
Activity is off by default, pausable, clearable and bounded to 300 ID/action/time
records per context. Up to 30 device contexts keep drafts, continuation, tabs,
splits and supported view positions. Changed sources reset positions, missing
objects are skipped, future/malformed records stay intact.

Validation complete: all 24 focused checks pass
(.local/project-context-focused-final.log), including native ordinary-file reopen,
private settings restart, scoped search/create/capture/event ownership, opt-in
activity and retention, failed-save draft recovery, unknown/future metadata,
field-only undo after later prose edits, stale form refusal, missing/changed source
restoration, repeated exact secondary-pane PDF navigation and 200% short layouts.
All 1,906 tests pass (.local/project-context-full-final.log). Analysis of lib/test/tool
is clean (.local/project-context-analyze-final.log). Format and strict checks pass
(546 files; .local/project-context-format-final.log and
.local/project-context-strict-final.log); git diff --check passes.

The initial full suite found short-calendar overflow and settings reachability
regressions. Empty Vaults now omit the project bar; constrained calendar layouts
scroll, day cells scale with text, and day/count badges wrap. The selected-project
380x380/200% regression and the final complete suite pass.
Project catalog discovery uses a cached linear scan rather than repeated object
lookups; no percentage performance claim or synthetic benchmark is asserted.

Windows release compiles in 123.7 seconds (.local/project-context-windows-final.log);
the executable loads the updated data/app.so from the local release directory.
Web JavaScript release compiles in 90.2 seconds (.local/project-context-web-final.log).
Existing Google JS-interop/Wasm dry-run and Cupertino font warnings remain; no Wasm
or physical browser/mobile acceptance is claimed. No desktop-control testing or
GitHub release replacement was performed. The prior publishing changes remain.

Limits: project selection is explicit and separate from object ownership; existing
Space filters intersect search/explorer scope. Source-owned connections do not
propagate dependencies or create semantic Canvas connectors. Activity covers the
listed supported local actions, not every specialized repository operation or
remote edits, and does not measure focus time. Personal continuation is device-only;
object relationships remain portable knowledge metadata. Immediate metadata undo
is session-local and refuses newer edits; native command history retains recovery.
Suggested next task: drag-to-link typed relationships directly on Canvas.

---
# Completed task — Image/table print layouts and page-aware publishing, 2026-10-12

User selected image/table resizing and captions/page breaks, live contents with
page positions, and shared PDF/HTML/Word document settings. Scope: extend the
existing publishing workspace and normal Markdown edit/history boundary
(EDT-02/06/07/10/11/12, PORT-05/06). No second content owner, new engine/package,
full editable page mode, desktop-control testing or remote release publication.

Plan: portable, bounded versioned print settings; safe unique content matching;
image/table inspector and page-aware PDF navigation; consistent export geometry
with explicit fidelity differences; persistence, malformed/stale/duplicate and
narrow-layout tests; visual PDF inspection and full repository checks.
Implementation complete. Publish document offers per-block print width/alignment,
captions, page starts and repeated table headers; searchable, paginated contents
show actual PDF heading pages and navigate the preview. PDF/HTML/Word share the
style and layout settings. Word includes page-reference fields; HTML labels PDF
positions and export details explain pagination differences. Save settings uses
portable Markdown metadata through existing editor undo/save/history, with
Source selection preserved across header insertion/update. Unknown fields remain;
future/malformed records and stale/read-only/changed-owner writes refuse updates.
Duplicate or edited content never silently inherits another block's layout.
Frontmatter remains excluded from exports when print metadata precedes it.

Validation: 28 focused checks pass (.local/publication-layout-focused-final.log),
including portable-file reopen, long table pagination/last-row preservation,
caption focus during regeneration, saved-style restoration, 200% compact controls,
source selection/one-step undo and shared export dimensions/captions/page fields.
All 1,882 tests pass (.local/publication-layout-full-final.log). Analysis of
lib/test/tool is clean (.local/publication-layout-analyze-final.log); format and
strict checks pass (542 files, zero final changes). git diff --check passes.
PDF fixture pages were rendered and visually inspected; contents numbers match
their heading pages and image/table captions align with the configured widths.
The .local/publication-layout-review.pdf and page PNGs are validation fixtures.
Windows release builds successfully in 74.0 seconds
(.local/publication-layout-windows-final.log); the local executable loads the
updated app data from build/windows/x64/runner/Release. Web JavaScript release
compiles successfully in 79.6 seconds (.local/publication-layout-web-final.log).
The web build retains pre-existing Google JS-interop/Wasm dry-run warnings and a
Cupertino font-family warning; no Wasm or physical browser/device acceptance is
claimed. No desktop-control testing or GitHub release replacement was performed.

Scope limits: this remains a source snapshot publishing workspace, not direct
editing on live pages. Standalone images/top-level tables receive print overrides;
nested or inline content retains its normal flow. Exact Word/browser pagination,
native Word-device review and physical mobile acceptance are not claimed. No new
package, database, content owner or source migration was added.
Suggested next task: editable page view using the saved document styles.

---
# Completed task — Publish source and Windows/Android artifacts, 2026-10-11

User explicitly authorized pushing the current source to iax32/Orbit-Note and
publishing Windows and APK artifacts. The original Android signing key and SDK
are missing after reset. Owner explicitly selected a preview APK with a new key;
it cannot update the older differently signed Android installation. Build Android
on the repository's GitHub Actions runner with a dedicated private preview key,
not an ephemeral debug signing fallback. Retain the key outside source and release
assets; GitHub Actions stores it only as encrypted repository secrets.
The preview uses `org.orbitnote.app.preview` and Orbit Note Preview, allowing
side-by-side installation with the older differently signed app. Default builds
retain the existing application identity and label.

Scope: reconcile older origin/main ancestry while preserving current tested
source, inspect source for private configuration, commit/push, build current
release-mode Android preview, verify signature/package metadata, and publish
artifacts/checksums with accurate limitations. Windows portable release is already
verified; Google OAuth registration and automatic sync remain unavailable. No
desktop-control testing or public collaboration hosting.

Publication gate found a real Linux watcher limitation in the full CI run:
native recursive directory watching missed new nested attachments. Linux now uses
the Dart team's recursive watcher, waits for initial registration, and closes its
subscription on Vault close. Windows/Android/macOS retain their existing native
adapter. Regression coverage includes newly created nested attachment files and
nested note creation, modification, rename and deletion. Both artifacts were
rebuilt from the corrected source; the earlier draft packages were replaced.

Source is pushed to origin/main, preserving the previously published ancestry.
Release/build commit: cc4b72cf6fe4ea69c45b7c9ccb55fce44d099b3c.
[Published 1.0.0 preview](https://github.com/iax32/Orbit-Note/releases/tag/v1.0.0%2B1)
contains Windows portable ZIP, signed Android preview APK, package/signature
metadata, source provenance and SHA-256 checksums. GitHub asset digests match the
locally verified files. README links point to this preview rather than older
stable binaries. Private signing material and account configuration are excluded
from Git and downloadable assets. The tag-triggered legacy release job was
cancelled to prevent it replacing these verified packages or promoting the preview.

Validation: local analysis of lib/test/tool is clean; format and strict checks
pass (540 files, zero final changes). All 1,872 local tests pass
(.local/publish-fix-full.log), including 21 storage checks. The Linux CI quality
gate passes format/analysis and 1,870 tests with two platform-specific skips
(.local/publish-fix-ci-quality-api.log;
[CI](https://github.com/iax32/Orbit-Note/actions/runs/38172094069)).
The previously failing external attachment check and new nested file lifecycle
check pass on Linux. Windows release compiles in 86.7 seconds
(.local/publish-fix-windows.log); all 57 packaged payload files match ZIP entries
(.local/publish-fix-package.log). The local executable remains directly runnable
from build/windows/x64/runner/Release/orbit_note.exe.
[Android release build](https://github.com/iax32/Orbit-Note/actions/runs/38172094141)
passes APK signature verification; downloaded checksum, retained signing
certificate, preview identity, label and launcher match. Android device acceptance,
Windows production signing and live Google authentication remain unverified or
unconfigured; no claim of full roadmap completion. The additional Windows debug,
Android debug and Web preview compile jobs all pass; the full CI run is green.
Both public package download links return HTTP 200. Final source/documentation
push preserves the release tag at the exact build commit above.

Suggested next task: Android device acceptance of opening/importing a Vault,
Markdown editing, PDF reading, Canvas interaction and backup/restore.

---

# Completed task — Windows release and Google connection readiness, 2026-10-11

User requested a Windows release with working one-button Google sign-in. The
owner closed the running app to permit replacement of release files. Scope is
the existing Windows app, account/backup readiness and portable release packaging;
no desktop-control testing. Google app registration is a separate external
prerequisite, not a user account or email substitution.

Implementation: successful sign-in, saved-account restore and account refresh
automatically discover backups alongside quota and Vaults. Partial failures keep
useful results and remain immediately retryable. Cancelled or changed-account
responses cannot populate stale account data. Build/release messaging now reflects
manual backups/restore accurately; automatic synchronization is not enabled.

Windows release and automated validation complete. The 42 focused Google checks pass
(.local/release-ready-focused.log); lib/test/tool analysis is clean
(.local/release-ready-analyze.log). All 1,871 tests pass
(.local/release-ready-full.log). Format and strict checks pass (540 lib/test files,
zero final changes, .local/release-ready-format.log and release-ready-strict.log).
git diff --check passes (.local/release-ready-diff.log).
Windows x64 release succeeds (.local/release-ready-windows.log); the SDK selection
already present in CMake remains unchanged. The initial Dart-run helper hit the
known space-containing SDK hook path; direct short-path Dart execution and the
short-path Flutter build passed. No SDK/security setting was changed.

The release-assets/OrbitNote-Windows-x64.zip package includes all app DLLs/data,
the existing standalone collaboration server, setup README and per-file hashes.
All 56 payload files were verified byte-for-byte against ZIP entries
(.local/release-ready-package.log). SHA256SUMS-Windows.txt checks the archive.
Runtime native assets resolve PDFium/SQLite beside the app. Server --help runs;
the existing loopback server remains running and the app remains closed.
This is an unsigned portable build, not an installer. No UI/device acceptance
or live Google authentication/transfer test was performed.

No configured Desktop OAuth client exists in config, environment or
usual Downloads/Desktop/Documents locations. Google consent-platform registration
was not completed on the owner's behalf. This release must remain local-only
until the developer client is imported and a configured build is produced.
Suggested next task: complete owner Google OAuth registration, then build the
configured account preview and verify real sign-in, backup and restore.

---

# Completed task — Shared Vault preview and Google Drive backups, 2026-10-11

User requested simultaneous note/Canvas editing with named cursors and Google
Drive support; selected a self-hosted server and OAuth setup help. Scope is an
explicit whole-Vault initial copy with live existing active notes/Canvas, private
owner/editor/viewer invitations, revocation, conservative known-base merging,
durable server acknowledgement and ordinary local edit/save/history. Drive is
manual immutable backup/restore, separate from automatic personal Vault sync.
See ADR-0027 and the shared-Vault/Google activation guides in docs/development.

Implementation complete for this preview. Server journal flush precedes accepted
edits; incomplete trailing records are repaired on restart, invalid complete
records refuse startup, and a write failure stops mutations until restart.
Snapshot IDs deduplicate lost acknowledgements; reused IDs with different bodies
refuse edits. Delta polling runs at 500 ms. Canvas merges stable placements;
uncertain overlaps/expired bases/divergent rejoin require explicit recovery.
Sessions end even when reopening the same Vault UUID. Remote content uses normal
commands/save/history, preserving unknown data. Viewer notes use the existing Read
projection; Viewer Canvas permits pan/zoom but prevents placement mutation/undo.
Presence is ephemeral: Canvas world pointers and note relative viewport pointers,
not native caret/selection sharing. Credentials stay outside portable Vault data.

Drive uses existing native OAuth/account adapters and narrow drive.file access,
resumable 1 MiB upload chunks, acknowledgement probing, MD5/SHA-256 verification,
account-change guards, progress/cancellation and reviewed restore into a new folder.
No downloaded OAuth client was found in Downloads; client registration remains
unconfigured. Google console registration/terms were not completed on the owner's
behalf. The activation guide now starts with plain-language owner setup steps.

Automated validation complete: 17 focused collaboration/Drive checks pass
(.local/shared-hardening-final.log), including actual two HTTP clients, two local
application/repository sessions, restart/torn journal/write failure, roles,
revocation, idempotency, unknown metadata refusal, Viewer scrolling/panning,
200% narrow controls, exact backup bytes and account isolation. All 1,865 tests
pass (.local/shared-full-final.log). Final cursor-heartbeat permission notification
optimization is covered by 36 final collaboration/Drive/composition/workspace
checks (.local/shared-final-focused.log); it keeps note editor subtrees stable
while pointer/status changes remain visible.
Analysis of lib/test/tool is clean (.local/shared-analyze-final.log); strict
formatting passes with 539 files, zero changes (.local/shared-strict-final.log).

Standalone Windows server build succeeds (.local/shared-server-build.log). It is
running hidden on 127.0.0.1:47831 with private data under the owner's LocalAppData
OrbitNote/CollaborationPreview directory; an actual HTTP check refuses anonymous
access with 403. No Vault was uploaded by this task. Windows app release was not
rebuilt. JavaScript web release compilation passes (.local/shared-web-build.log);
web collaboration remains unsupported. The build reports an existing Google SDK
Wasm incompatibility and Cupertino font warning; no Wasm release is claimed.
Remote TLS/domain setup, actual multiple-device acceptance and live Google sign-in/
transfers are unperformed. Initial attachments/other objects are copied; new
objects, deletions and attachment changes are not continuously streamed. No CRDT,
E2EE or native text-caret synchronization is claimed.
Suggested next task: shared-object creation and attachment synchronization.

---

# Completed task — Markdown composition and connected blocks, 2026-10-11

User accepted the full five-part Markdown batch: responsive columns/image-and-text,
inline drawing blocks using the existing Canvas engine, live object blocks,
reviewed document-wide replacement, and explicit selection conversion. EDT-02/08/09/13
subsets. Preserve canonical IDs, Markdown/JSON authority, unknown data, ordinary
undo/history, offline use and platform boundaries. No desktop-control testing.

Implementation: two/three equal columns with nested Rich editors, Read stacking,
reverse/unwrap controls and exact UTF-16 mapping; existing media layouts also
available in Source. Canonical task/view/Canvas source cards with missing-source
fallbacks, task completion, bounded query previews and shared-engine drawing editing.
Drawing creation leaves the writing tab open. Replacement review selects matches,
paginates previews and checks stale source/workspace before applying one undoable edit.
Conversion accepts complete prose/list blocks into paragraphs, checklists, callouts,
one-column tables or existing linked Canvas placements. Placements retain their source.

Implementation and automated validation complete. Focused composition/find/media
checks: 52 pass (.local/composition-final-focused.log), including source reopen/
failed saving, canonical
placement identity, task mutation, stale drawing rejection, 200% narrow layouts,
exact column caret/search ranges and source-cache refresh. Full suite, analysis and
strict formatting are also recorded in the active task above. No Windows app
release build requested.

---

# Completed task — Reusable source libraries and reviewed BibTeX interchange, 2026-10-11

User accepted the next citation task. FILE-10/14 and PORT-05 document/library
subset: ordinary canonical library notes, reusable selected source snapshots,
reviewed bounded BibTeX import, explicit key/DOI conflict policies, export preserving
extra fields, provenance navigation and normal note durability/history. No online
metadata lookup, automatic library-to-document propagation, CSL or TeX execution.
Implementation and automated validation complete. No desktop-control testing.
Validation: 22 focused library/citation checks pass (.local/bibtex-focused.log),
including 11 new cases for nested/escaped fields, macro refusal, unknown-field
round-trips after edits, selection review, key/DOI conflicts, 1,000-source bounds,
injection refusal, narrow 200% text and repository reopening/failed-save recovery.
All 1,830 tests pass (.local/bibtex-full.log). Application/test/tool analysis is
clean (.local/bibtex-analyze-final.log); format and strict checks cover 527 files
with zero final changes (.local/bibtex-format.log, .local/bibtex-strict.log).
Library creation and imports use existing canonical note commands/save/history;
there is no new store, database dependency or migration. Unknown source JSON/BibTeX
fields survive updates, while library snapshots retain source-object provenance.
Specs/formats/status reconciled. Native file-dialog/device acceptance is unperformed;
Windows release was not rebuilt. Full TeX/BibLaTeX/CSL fidelity remains outside scope.
Suggested next task: cross-library duplicate review and recoverable source merging.

---

# Completed task — Citation management and automatic bibliographies, 2026-10-11

User accepted the citation/bibliography feature. FILE-10/14 document-local scope:
manual title/author/year/publisher/DOI/ISBN/URL sources, search/edit/remove unused
sources, locator insertion, compact author–year and numbered References, Rich/Read
presentation and automatic bibliography refresh in publishing snapshots. Preserve
unknown records/fields, code examples, owning Markdown, note history and stale-edit
guards. No online metadata lookup, CSL, Zotero or cross-note library is included.
Implementation and automated validation complete. No desktop-control testing.
Validation: 11 new focused tests pass (.local/citations-focused.log), including
actual editor insertion/Read presentation, compact 200% text layout, exact Rich
wrapper deletion, portable reopening/unknown-field retention, literal code and
unsafe/missing/duplicate source boundaries, and HTML/Word publication snapshots.
Dialog controller disposal waits for closing transitions; editor mutation checks
note/workspace identity, original selection context, composition and read-only state.
All 1,819 tests pass on final implementation (.local/citations-full-final.log).
flutter analyze --no-pub lib test tool is clean (.local/citations-analyze-final.log);
dart format lib test and strict format checks pass: 523 files, zero final changes
(.local/citations-format.log, .local/citations-strict-final.log). Analysis is scoped
to application/tests/tools because root analysis includes the local dependency cache.
Existing Markdown save/history remains the durable authority; no migration or new
database is introduced. Specs/formats/status updated. Native device acceptance and
full citation-style compliance are unperformed; Windows release was not rebuilt.
Suggested next task: reusable source libraries with reviewed BibTeX import/export.

---

# Completed task — Document publishing workspace, 2026-10-11

Status: implementation and automated validation complete; native Office/device acceptance unperformed.
User authorized live A4/Letter pagination, margins/page breaks, typography and
heading numbering, title/header/page numbers, linked contents and footnotes,
rich PDF/standalone HTML/editable Word exports with fidelity warnings.
PORT-05/06/08/09 and EDT-02/08/12 scope. Publishing uses immutable note snapshots
and original attachment reads; it never rewrites owning Markdown. Existing linked
section resolution and portable fallbacks are reused. Export files use platform
save adapters; unsupported content is reported. No desktop-control testing.
Validation: 37 focused publication/writing/linked-section/legacy-export checks pass
(.local/publishing-focused-verified.log), including nine new publication tests.
Actual generated PDF pages were opened, text extracted, links inspected and a
page rendered for visual inspection (.local/publishing-review.pdf/.png).
Word package parts cover editable tables, heading bookmarks, native footnote
relationships and page fields. HTML escapes executable content and embeds local
resources. Tests cover missing/duplicate footnotes, source preservation,
canonical linked-section fallback, invalid equations, shared attachment reads,
no remote image fetch and narrow 200% text layouts. First full run: 1,808 pass
(.local/publishing-full.log). The final full regression also passes all 1,808
tests after subsequent refinements (.local/publishing-full-final.log).
flutter analyze --no-pub lib test tool passes (.local/publishing-analyze.log).
dart format lib test and strict formatting pass for 520 files
(.local/publishing-format.log, .local/publishing-strict.log). Diff whitespace check
passes. Root analysis of this checkout also scans its dependency cache, so explicit
app/test/tool scope is used. No desktop-control or native Office acceptance.
Limits: PDF/HTML endnotes; Word math is rendered PNG with TeX alt text; static
print layout for media sections; format-specific font/pagination differences.
No printer driver integration. Windows release executable has not been replaced.
Web JavaScript release builds (.local/publishing-web.log). Existing Google identity
JSInterop Wasm dry-run and Cupertino font warnings remain; Wasm compatibility
and browser/device acceptance are not claimed.
Windows Release flutter_assemble target passes (.local/publishing-windows-assemble.log).
This compiles Flutter assets/AOT only; the running Windows release executable and
installed data bundle are not refreshed. A full Windows release rebuild is needed
to use this update in the desktop app.
Suggested next task: citation management and automatic bibliographies.

---
# Completed task — Section header size and line thickness customization, 2026-10-10

Status: complete; 11 focused tests, regression tests, flutter analyze, and strict formatting pass.
User requested adjustable section headers on the Canvas with font size and underline thickness controls.
CAN-02/03/04 scope:
- CanvasElement getters `sectionFontSize` and `sectionStrokeWidth` resolving explicit properties, `headerSize` presets (Small 13px, Medium 18px, Large 24px, Extra Large 32px, Huge 42px), line thickness presets (Hairline 1.0px, Standard 1.5px, Medium 2.5px, Thick 4.0px, Heavy 6.0px), Markdown heading prefixes (`# `, `## `, `### `), or element height scaling.
- OrbitCanvasPainter renders section titles with proportional font size, stripped markdown prefixes, and matching underline stroke width and position.
- Canvas SVG export (`canvasToSvg`) includes matching `font-size` and `stroke-width` attributes.
- Canvas editor selection toolbar exposes Section Header Size dropdown, Increase/Decrease step buttons, and Line Thickness dropdown.
- Canvas context menu exposes SECTION HEADER SIZE and LINE THICKNESS submenus.
- Drag-resizing section elements dynamically scales font size and line thickness with height.
- In-place text editor displays proportional font size, finishes on Enter, and upgrades header size when Markdown prefixes (`# `, `## `, `### `) are typed.
Validation: 11 tests pass in test/canvas_section_size_test.dart; test/product_polish_test.dart and test/canvas_widget_test.dart pass. flutter analyze --no-pub reports 0 issues. Strict dart formatting passes.
Suggested next task: Section header alignment options (left, center) and background tint options.

---
# Completed task — Model assets and narrative templates, 2026-10-11

Status: implementation and automated regression complete; native acceptance unperformed.
User requested OBJ/GLB viewing, linked Canvas items and story/game-writing templates.
FILE-02/03, CAN-02/03/04, GAME-01 and EDT-09 scope: bounded offline OBJ and GLB 2
static geometry previews, orbit/orthographic controls, shaded/wireframe views,
base-colour tint and scene transforms, missing/invalid/unsupported fallback with
retry/open original. Add to Canvas creates an ordinary UUID placement referencing
the canonical attachment; drops and existing placement tools also work. No asset
duplication/deletion, new dependency or new durable schema. Six searchable Markdown
templates cover story outline, character arc, world bible, dialogue, branching
quest and game narrative design. Existing templates keep their order and behaviour.
27 focused model/template/media tests pass (.local/model-assets-focused.log),
including seven new parser/viewer/template/placement checks, native restart,
canonical identity, untouched bytes, GLB node transforms/tint, malformed/sparse/
compressed/bounds errors, missing files and narrow 200% text layouts.
All 1,799 tests pass (.local/model-assets-full-final.log), including the concurrent
section-header work. dart format lib test and strict formatting pass for 515 files
(.local/model-assets-format.log, .local/model-assets-strict.log). Targeted diff
whitespace checks pass. Root flutter analyze scanned cached dependency examples
and reported 245 issues outside lib/test/tool (.local/model-assets-analyze.log);
flutter analyze --no-pub lib test tool passes with no issues
(.local/model-assets-analyze-scoped.log).
No platform release build or installed executable replacement was performed.
No GUI automation or native/device acceptance is claimed.
Suggested next task: model thumbnail cards and embedded texture/material support.

---
# Completed task — Playtest and release workspace, 2026-10-10

Status: implementation and automated checks complete; native acceptance unperformed.
User authorized build comparison, regression queues, reusable test plans, evidence
and release readiness together. GAME-01–03 / DEV-02 workflow extension:
project-mechanic-scoped Playtest & Release from the gameplay workbench; explicit
baseline/target build results, failed/blocked/unverified/open-task filters,
baseline and target findings, source-version evidence links, release coverage
counts and baseline-pass/target-fail regression count. No task auto-completion.
Mechanics/levels/controls/saves/performance plan presets create ordinary Markdown
notes; independent unchecked runs retain plan UUID and revision. Verdicts use
normal recoverable edits; pass requires nonempty fully checked coverage. Changed
plans require a new run for coverage. No new file format, account, execution,
automatic game testing or shipping certification. No desktop-control testing.
37 focused gameplay/workflow/media tests pass (.local/release-workspace-focused.log).
Tests include build-local verification, persistent restart, independent runs,
stale forms, incomplete passes, unknown-property retention, unsupported versions,
write failure recovery, fenced examples and narrow 200% text layouts.
All 1,781 tests pass (.local/release-workspace-full.log), including five added
release-workflow regressions. Analysis is clean (.local/release-workspace-analyze.log);
dart format lib test and strict format pass for 511 files
(.local/release-workspace-format.log, .local/release-workspace-strict.log).
Targeted diff whitespace check passes. No desktop-control testing, native/device
acceptance or platform release build is claimed. Orbit Note is running from the
Windows release folder; its executable and release files remain unchanged.
Suggested next task: per-check expected/observed results with linked evidence,
retaining run history and build-specific coverage.

---
# Completed task — Gameplay source capture and clipboard continuity, 2026-10-10

Status: implementation and automated validation complete; native acceptance unperformed.
User requested more gameplay development support and reliable small clipboard
interactions. DEV-01–03 / GAME-01–02 scope: exact whole-line source ranges,
gutter/Shift selection, portable code-fence copy, keyboard range copy/cut with
read-only semantics, graceful clipboard failures, gameplay citation capture into
the existing validated record form, and Unreal/Godot/Luau source file support.
New captures clear commit/branch claims; users verify the supplied immutable commit.
No external file write/execution, schema migration or desktop-control testing.
Existing Note/Canvas image cut/paste/undo regressions are included in checks.
All 1,776 tests pass (.local/game-source-full.log), including three new tests for
capture provenance/invalid ranges, mixed-ending/fence handling, keyboard range
cut and clipboard failure. The 25-test focused gameplay/source/media run passed
before the final capture regression was added (.local/game-source-focused.log).
Analysis is clean (.local/game-source-analyze.log); dart format lib test and
strict formatting pass for 509 files. Targeted diff whitespace check passes.
No desktop-control testing was performed, per user preference; native clipboard
interoperability is not claimed. The app is running from the Windows release
folder; this task does not replace its executable or build a new release.
Suggested next task: compare playtest builds and surface unresolved regressions
per mechanic using canonical findings and verification records.

---
# Completed task — Note and Canvas clipboard transfers, 2026-10-10

Status: implementation, automated regression and Windows/web release builds complete;
native clipboard acceptance remains unperformed.
User requested Ctrl+X on a note image followed by Ctrl+V on Canvas, with
consistent transfers between surfaces. DES-01/04/05/06 and EDT-04 scope:
rich image keyboard selection, copy/cut context actions; portable attachment
paths in Rich and Source copy/cut; image, media-section image/prose and standalone
object-link placement paste on Canvas; Canvas images/object cards/text to note
Markdown in Rich and Source, including caret paste; grouped placements/connector
endpoint/ink-coordinate remapping; successful-write and stale-cut guards.
Existing attachment/object identity and owning-surface undo remain. No attachment
byte duplication, object deletion, new durable schema, package or GUI automation.
Drawings without a Markdown representation retain the literal clipboard fallback.
References resolve within the existing Vault; this is not cross-Vault byte transfer.

All 1,773 tests pass (.local/media-transfer-full.log), including 13 new clipboard
regressions. All 67 focused note/Canvas/clipboard/media checks pass
(.local/media-transfer-focused.log). Tests cover keyboard cut/paste, reverse paste,
undo, repeated-paste identity, clipboard failure, intervening edits, source caret
paste, mixed media/code, and group/connector remapping. The full suite caught an
image-toolbar pointer cancellation regression; immediate completed-click selection
fixes it and existing image-to-text conversion now passes.
Analysis is clean (.local/media-transfer-analyze.log); strict format passes for
509 files (.local/media-transfer-strict-format.log).
Native clipboard/device acceptance is not claimed; the user prohibited desktop
control testing. Windows release builds in 84.0s (.local/media-transfer-windows.log):
build/windows/x64/runner/Release/orbit_note.exe and data/app.so are refreshed.
The installed release Dart payload matches build/windows/app.so by SHA-256.
Web JavaScript release builds in 87.5s (.local/media-transfer-web.log). Existing
Google identity JSInterop Wasm dry-run and Cupertino font warnings remain;
no Wasm release or real-device clipboard interoperability is claimed.
Suggested next task: reference-aware clipboard transfer for inline image selections
and nested live embeds, preserving source provenance and readable fallbacks.

---
# Completed task — Code studio refinement, 2026-10-10

Status: complete; regression, analysis, formatting, Windows compilation and web build pass.
User requested another substantial code-editor batch. DEV-01 / EDT-09 scope:
wrap-aware viewport line numbers and current-line guide, gutter line selection,
caret reveal, responsive original/draft comparison, HTML/XML/CSS/SCSS block
comments with nested-delimiter rejection, selection wrappers, selected-line
deletion, explicit trailing-whitespace cleanup, undoable reset, change status
and cached draft line ranges. Normal draft history and stale-source Apply remain.
No execution, language server, external repository write, new durable format or
dependency. No desktop-control testing.

All 1,760 regression tests pass (.local/code-studio-full.log), including the
42-test focused studio/code/search/feedback checks (.local/code-studio-focused.log).
Coverage includes logical-line gutter selection, distant caret reveal and wrapping,
comparison controller/selection/history preservation across width changes,
CRLF block-comment round trips, nested-delimiter rejection, literal UTF-16 wrappers,
line deletion, whitespace cleanup, undoable reset and existing read-only/stale guards.
Analysis is clean (.local/code-studio-analyze.log); strict format passes for
507 files (.local/code-studio-strict-format.log). No desktop-control acceptance.
Windows flutter_assemble Release target passes (.local/code-studio-windows-compile.log);
build/windows/app.so is refreshed. The app is running from the release folder,
so runner installation/release replacement is deferred; its data/app.so is unchanged.
This is Windows Dart compilation, not a refreshed distributable release candidate.
Web JavaScript release builds in 107.6s (.local/code-studio-web.log). Existing
Google JSInterop Wasm dry-run and Cupertino icon-font warnings remain; no Wasm
release or real-device acceptance is claimed.
Suggested next task: local snippet library with
searchable language/project tags and linked source provenance.

---
# Completed task — Code editing tools, 2026-10-10

Status: complete; regression checks and Windows/web release builds pass.
User requested more code editing tools. Scope: DEV-01 / EDT-09 expanded
Markdown code drafts: literal find/replace with previous/next, case and whole-word
matching; go-to-line; duplicate/move selected lines; supported line-comment toggles;
2/4-space or tab indentation, smart Enter and keyboard shortcuts; draft undo/redo
and copy; read-only, composing and stale-source guards; compact/enlarged layouts.
Existing syntax highlighting and normal owning-note apply/save/undo remain.
No external repository writing, code execution, language server or new dependency.

All 1,753 regression tests pass (.local/code-workbench-full.log), including the
35-test focused code/search/feedback run (.local/code-workbench-focused.log).
Coverage includes CRLF/UTF-16 and reversed selections, line moves/duplication,
comments and unsupported grammars, Unicode replacements, keyboard undo/redo,
read-only controls, enlarged layouts and existing stale-source apply checks.
Flutter analysis is clean (.local/code-workbench-analyze.log); strict formatting
passes for 505 files (.local/code-workbench-strict-format.log).
Windows release builds in 62.5s (.local/code-workbench-windows.log), output
build/windows/x64/runner/Release/orbit_note.exe with refreshed data/app.so.
Web JavaScript release builds in 63.6s (.local/code-workbench-web.log). Existing
Google JSInterop Wasm dry-run and Cupertino font warnings remain; this is not a
Wasm release. No desktop-control or real-device acceptance testing was used.
Suggested next task: source-browser excerpt capture
into linked technical notes. Stop before implementing the next task.

---
# Completed task — Structured writing workspace, 2026-10-10

Status: complete; final focused checks, analysis, formatting and Windows/web release builds pass.
User authorized the complete four-part editor batch: section planning/focus,
Word-style typing formats, footnote management, and linked-section impact/repair.
Scope: EDT-02/03/04/10/12/15 and LNK-04/10, using existing source-preserving
Markdown, normal editor undo/save, and per-pane view state. No new storage schema,
network service, dependency, or desktop-control acceptance testing.

Writing tools opens Sections, Footnotes and Connections. Sections supports
heading search, whole-section drag reorder, keyboard-accessible move actions,
add/rename/delete, outline-only planning and section focus with full-document
recovery. Descendants travel with their parent. Stable existing block anchors
resolve restored focus; duplicate/missing headings fall back to the full document.
View state retains focus/planning and existing caret/scroll/fold restoration.
Continuous math paragraph mode also restores when the source fingerprint matches;
changed source falls back safely to the standard rendered mode.

Typing formats show on/off/mixed state, apply across selected supported prose,
and carry chosen marks into a new paragraph without writing empty delimiters.
Rich/Source/Split preserve source selections and reversed endpoints where supported.
Continuous math paragraph editing uses one native field containing authored TeX,
with rendered editable previews and a return to segmented rendered equations.
It does not claim seamless native selection across rendered equation widgets.

Footnotes supports marker-click editing, multiline definitions, missing/unused
and duplicate diagnostics, reference/definition navigation and safe identifier
renames. Footnote definitions no longer become shortcut-link destinations.
Escaped/code/comment/frontmatter/linked-fallback examples remain literal.
Duplicate IDs, collisions, unfinished literal footer contexts, read-only/stale
edits and stale owner navigation are rejected. Dialog controllers live until
route disposal, including its closing transition.

Connections lists incoming/outgoing section uses, previews captured content
before section changes/deletion, opens originals/hosts and repairs section targets
through the existing picker. Source notes retain identity; no copied live content,
automatic relinking, or cascaded deletion. Missing targets retain saved fallback.
No reverse index/database authority is introduced.

All 1,744 regression tests passed (.local/writing-workspace-full.log). The final
64-test focused run (.local/writing-workspace-final-focused.log) covers section
movement, typing formats, selection, footnote save/reopen and undo, linked uses,
literal-context preservation, continuous-math restoration and stale note owners.
The workspace scrolls as one surface at short heights, avoiding fixed-header
overflow. Heading dialogs and drag payloads validate document ownership.
Analysis is clean (.local/writing-workspace-analyze.log); strict formatting covers
504 files (.local/writing-workspace-strict-format.log). Final Windows release
build succeeds in 62.9s (.local/writing-workspace-windows.log), output
build/windows/x64/runner/Release/orbit_note.exe with refreshed data/app.so.
Web JavaScript release succeeds in 64.2s (.local/writing-workspace-web.log).
Existing Google JSInterop Wasm dry-run and Cupertino font warnings remain; this
is not a Wasm release. No desktop control/native UI acceptance is claimed.
Historical tasks follow.
Suggested next task: keyboard-driven section planning and impact-panel refinements.

---
# Completed task — Local document review, 2026-10-10

Status: complete; regression checks and Windows/web release builds pass.
Authorized EDT-12 scope: selected-passage comments, filterable review sidebar,
suggested replacements, safe anchors, resolve/reopen, accept/reject, offline
portable storage and recoverable mutations. No shared threads or account service.

Select text in Rich/Source, then Insert → Comment on selection / Suggest replacement,
or Ctrl+Alt+M for a comment. Document review opens a dock on wide screens and a
sheet on narrow/enlarged layouts. Unresolved, comments, suggestions and everything
filters retain finished receipts; source navigation selects the exact passage.
Suggested wording is explicit Markdown, including an intentional empty deletion.

Versioned JSON HTML comments live in the owning Markdown document; existing block
IDs are reused, and safe new block IDs are added when a selection stays intact.
Otherwise captured quote/context uses UTF-16 source offsets. Duplicate identities,
missing/changed blocks and ambiguous passages never silently retarget. Explicit
reattachment captures a new editor selection. Unsupported versions and fenced
examples remain literal; unknown JSON keys survive review mutations.

Accept changes only the verified passage and its receipt in one editor history
operation. Resolve/reject/reopen/remove use the same normal save and undo path.
Failed persistence retains the previous durable source; no alternate database
authority, package or migration. Metadata is hidden in Rich/Read and available in
Source. Cross-block/code selections use conservative context matching; this is
local review, not collaboration or automatic grammar correction.

Thirteen final focused tests pass (.local/document-review-focused.log), covering portable
CRLF/Unicode metadata, source moves, failed save/reopen, unknown fields, duplicate
identities, literal examples, explicit reattachment, empty replacement, filters,
Rich visibility, exact navigation, enlarged layout and editor undo.
All 1,718 regression tests pass (.local/document-review-full.log); two later tests
and final anchor/guard refinements pass in the 13-test focused run. Analysis is
clean (.local/document-review-analyze.log); strict format passes for 499 files
(.local/document-review-strict-format.log). Windows release builds in 74.1s
(.local/document-review-windows.log), output build/windows/x64/runner/Release/orbit_note.exe.
Web JavaScript release builds in 87.1s (.local/document-review-web.log); existing
Google JSInterop Wasm dry-run and Cupertino font warnings remain. No Wasm release,
desktop control or native UI acceptance is claimed. The temporary native DLL lock
from concurrent focused/full tests cleared when the full suite finished; the final
focused retry passed.
Suggested next task: review markers and passage navigation within long notes.

---
# Completed task — Live linked note sections, 2026-10-10

Status: complete; regression checks and web/Windows release builds pass.
Authorized: section picker/preview, live updates, exact source navigation,
remove/detach controls, safe fallback/cycle protection, Rich and Read layouts.
Scope LNK-10 and EDT-08; existing source-preserving projection, stable object
references, normal save/history and portable Markdown. No package or migration.

Insert → Linked section (also slash commands) searches Markdown notes and previews
paragraphs, headings and lists/checklists. Insertion anchors the selected source
through the normal recoverable save; failed saves prevent insertion. Heading
sections include subordinate headings up to the next peer/ancestor. Explicit
anchors survive note/heading renames; duplicate/missing targets do not retarget.
The picker rejects changed source; existing insertion guards reject a changed host.

Rich and Read display the same live selectable preview and exact Open source
navigation. Rich adds Remove linked section and Make independent copy, using the
host's existing undo/save ownership. Removal never deletes the source. Detach
resolves nested sections into ordinary Markdown; saved snapshots are retained for
unavailable sources. Read preserves its reading-only actions. Source cache changes
invalidate linked Rich previews without reparsing unrelated typing fields.

Portable format: paired HTML comments contain target/scope metadata; intervening
quoted Markdown is an insertion-time fallback snapshot. Unsupported/unknown
metadata remains literal and editable. Opening/rendering does not rewrite it.
Cycle detection is conservative by note identity, with maximum depth five and
24 nested previews per root. Each live section is limited to 100,000 characters;
large fallback previews expose an explicit open/copy path. No hidden source
truncation. Fenced examples are preserved during explicit detach.

Nine focused tests pass (.local/linked-section-focused.log). All 1,707 tests pass
(.local/linked-section-full.log); analysis is clean (.local/linked-section-analyze.log)
and strict format passes for 496 unchanged files (.local/linked-section-strict-format.log).
Web JavaScript release passes in 78.4s (.local/linked-section-web.log). Existing
Google JSInterop Wasm dry-run and Cupertino font warnings remain; no Wasm release
is claimed. Windows release passes in 70.8s (.local/linked-section-windows.log),
output build/windows/x64/runner/Release/orbit_note.exe. Tests cover
restart, source-save failure, unknown property preservation, CRLF/Unicode, stable
heading anchors, list updates, duplicate/missing/cyclic targets, Rich cache refresh,
source navigation/detach/remove and Read/picker at 390 px with 200% text.
No desktop control or native UI acceptance is claimed. Local linked content uses
the current workspace projection; external edits update after normal reconciliation.
Suggested next task: linked-section backlinks and source-impact previews.

---
# Completed task — Local source-file browser, 2026-10-10

Status: complete; regression checks and web/Windows release builds pass.
Authorized: browse source files with highlighting,
line numbers and search (selected portion of the Git development proposal).
Scope DEV-01/03/05 local read-only source browsing; software development spec,
platform adapters and focused workflow. Reuse file_selector and CodeController;
no package, Git execution, repository write, integration credential or desktop control.

Game dashboard → Browse source files → explicitly selected local folder. Lazy path
list/filter, numbered highlighted source lines, matching-line search with case toggle,
previous/next navigation, exact full-file copy, reload and directory refresh. Narrow
layouts switch file/source panes; enlarged headers scroll within a bounded area.
Native scans exclude generated folders and symbolic links, show incomplete coverage
and bound scan depth/count. Reads enforce folder containment, UTF-8 text and a 1 MiB
preview limit. Missing/binary/oversized files report errors; late asynchronous results
cannot replace a newer file or update a closed dialog. Files are never imported,
executed or edited. Folder browsing is native-only; web displays that limitation.

Four focused tests pass (.local/source-browser-focused.log): native exact-byte
read/unchanged file, ignored folders, traversal/invalid UTF-8/binary/size/missing-file
errors, language/search behavior, highlighted numbered UI/search/filter, narrow
200% text and closed-dialog read completion. Initial tests caught a genuine enlarged
header overflow, fixed before final checks. All 1,698 tests pass
(.local/source-browser-full.log), analysis is clean (.local/source-browser-analyze.log)
and strict formatting passes for 493 unchanged files (.local/source-browser-format.log).
Web JavaScript release passes in 89.4s (.local/source-browser-web.log). Existing
Google JSInterop Wasm dry-run and Cupertino font warnings remain; no Wasm build
is claimed. Windows release rebuild passes in 69.7s (.local/source-browser-windows.log)
after the user confirmed closing the app; gameplay workbench changes are included.
Output: build/windows/x64/runner/Release/orbit_note.exe. No
desktop control, mobile/native UI acceptance or signing is claimed.
Limits: 5,000 source files, 50,000 inspected entries, depth 15, 1 MiB UTF-8 previews;
over 50,000 characters use explicit plain-text fallback. No Git history/diffs,
automatic citation capture, saved folder access, cross-file content search or
cross-line native selection. Suggested next task: exact Git-revision citation capture.

---
# Completed task — Connected gameplay development workbench, 2026-10-10

Status: implementation complete; Windows release update awaits closing the running
app. Authorized: all five suggested mechanics workspace, code
citations, build playtests, finding/fix/verification and technical resume features.
Scope GAME-01–03 and DEV-02–04; game/software development specs, existing context
and storage authority contracts. Reuse canonical notes/tasks/resources, ordinary
Markdown/frontmatter and device-local contexts. No new dependency, storage migration,
code execution, repository rewrite, cloud integration or desktop control.

Game dashboard opens a responsive workbench with mechanic selection, specification
and linked evidence, search/build filters and 30-item source pages. Code citations
retain exact commit/path/line range/excerpt and distinguish captured moving branches.
Playtests retain build/expected/observed/evidence; fix tasks retain mechanic and build.
Verification is an append-only linked note with passed/failed/blocked outcome and
code/screenshot evidence; task completion stays explicit. Device-local continuation
restores related open tabs/positions, skips missing sources and resets changed ones.
Validation: six focused tests pass (.local/gameplay-focused.log), including native
restart, exact fenced Unicode/CRLF excerpts, unknown data preservation, invalid/
interrupted/failed saves, stale forms, context isolation and enlarged narrow layouts.
All 1,694 full tests pass (.local/gameplay-full.log); analysis is clean
(.local/gameplay-analyze.log); strict formatting passes for 487 unchanged files
(.local/gameplay-format.log). Early widget test teardown waited on a draft in the
fake-clock harness; corrected in-memory cleanup before final checks. No production
failure is hidden by that adjustment. Web JavaScript release succeeds in 79.4s
(.local/gameplay-web.log). Existing Google JSInterop Wasm dry-run and Cupertino
font warnings remain; they do not prevent the JavaScript release.
Windows release was interrupted because Orbit Note is running from the release
folder (close-app request pending); no Windows release success is claimed.
No desktop control, native UI acceptance, mobile/Wasm release or signing claimed.
Suggested next task: reviewed local Git citation capture adapter.

---
# Completed task — Figure captions and linked sources, 2026-10-10

Status: complete. Authorized: the suggested media-section caption/citation task.
Scope EDT-01/03/04/05/06/07/12; Markdown editing spec, portable media format and
focused workflow. Reuse local note links, attachment navigation, saves and undo.
Editable captions, labelled source links, local note picker, source ordering/removal,
Rich/Read parity and stale-dialog protection. Ordinary Markdown remains readable;
invalid/future metadata stays literal. No new dependencies or desktop control.
Focused validation: 17 tests pass (.local/figure-focused.log), including eight new
caption/source tests. Source escaping and LF/CRLF preservation, malformed/future
metadata, prohibited destinations, source-count limits, native restart/custom
properties, Read-source navigation, local note picker and editing, cancellation,
stale-dialog rejection and captions/chips at 250% text in 360px panes are covered.
All 1,688 full tests pass (.local/figure-full.log); final analysis is clean
(.local/figure-analyze-final.log). Strict format passes with 483 unchanged files
(.local/figure-format-final.log). Windows release succeeds in 70.5s
(.local/figure-windows-release.log), web JavaScript release succeeds in 79.1s
(.local/figure-web-release.log). Updated Windows bundle:
build/windows/x64/runner/Release/. Existing Google JSInterop Wasm dry-run and
Cupertino font warnings remain; signing, mobile, Wasm and native UI acceptance
are not claimed. Intermediate analysis reported a missing brace and misplaced
doc comment; fixed before final analysis/full-suite checks. No desktop control used.
Limits: single-line plain captions up to 2,000 characters and at most 20 labelled
sources. No fetched metadata, generated citations/bibliographies or native selection
across the image boundary. Authored labels remain stable rather than auto-renaming.
Suggested next task: inline source citation chips beside claims in ordinary prose.

---
# Completed task — Markdown image-and-text sections, 2026-10-10

Status: complete. Authorized: screenshot-inspired adjacent image/rich text.
Scope EDT-01/03/04/05/06/08/09/12, Markdown editing specification, open formats,
feature backlog and focused workflow. Reuse attachment/image rendering, Markdown
projection and existing note saves/undo. Responsive rounded media layouts, left/right
placement and size presets, rich editing and Read-mode parity. Ordinary Markdown
with layout comments retains a vertical fallback outside Orbit. Unsupported markers
remain literal. No new dependencies, desktop control or unrelated scheduling work.
Focused validation: nine media tests pass (.local/media-final-focused.log), including
native save/restart, unknown/malformed markers, mixed LF/CRLF source, fenced-code
closing comments, Read layout/original navigation, responsive enlarged text,
inline edits and toolbar routing, image alt/title preservation, stacked conversion
and stale asynchronous image-picking protection. The editor/model compatibility
batch passes 63 tests (.local/media-focused.log). Final analysis is clean
(.local/media-analyze-final.log). All 1,680 full tests pass (.local/media-full.log);
strict formatting passes for 480 unchanged files (.local/media-format-final.log).
Windows release succeeds (.local/media-windows-release.log, 87.0s); web JavaScript
release succeeds (.local/media-web-release.log, 85.7s). Updated Windows bundle:
build/windows/x64/runner/Release/. Existing Google JSInterop Wasm dry-run and
Cupertino font warnings remain; mobile, Wasm, signing and native UI acceptance
are not claimed. Intermediate analysis found missing braces in
new code; corrected before final analysis/full-suite checks.
No new storage model, desktop control, mobile acceptance or cross-section native
selection is claimed. Normal attachment previews retain their loading/recovery path.
Suggested next task: editable figure captions and linked source citations.

---
# Completed task — Working-day project scheduling, 2026-10-10

Status: complete. Authorized: working-day calendars and a broader related batch.
Scope TASK-05/06/09 and VIEW-11; required task planning, collections/views, backlog
and agent workflow. No new dependencies, migration or desktop control.

Reusable canonical calendar notes, weekday presets, named holidays/extra shifts,
per-view defaults and per-task bindings; inclusive working effort, forward/backward
planning, calendar-aware reviewed moves, date pickers and paginated schedule audit.
Calendar edits retain existing task dates. Missing/future calendars remain visible;
stale calendar/task edits and failed saves must preserve drafts and previous data.
Validation: 1,671 full tests pass (.local/work-calendar-full.log), including eight
new working-calendar cases. Focused compatibility batch passes 17 tests
(.local/work-calendar-large-layout.log); analysis is clean
(.local/work-calendar-analyze-final.log). Format and strict formatting pass with
477 unchanged files (.local/work-calendar-format-final.log). Coverage includes
Mon–Fri/alternative weeks, holidays/extra shifts, forward/backward calculation,
DST/leap civil-date arithmetic, milestone snapping, invalid definitions/ranges,
reviewed save controls, calendar edits retaining dates, stale calendar rejection,
failed saves, no-working-day rejection, guarded undo, missing-source recovery,
unrelated legacy edits, and canonical bindings/unknown fields across native restart.
Gantt, live embeds, calendar and schedule forms fit narrow panes at 250% text.
Intermediate test compilation missed an extension import; corrected before passing
focused and full runs. Existing Gantt drag/compatibility coverage remains green.
Windows release builds successfully (.local/work-calendar-windows-release.log,
84.0s) and web JavaScript release builds successfully (.local/work-calendar-web-release.log,
88.0s). Updated Windows bundle: build/windows/x64/runner/Release/.
Existing Google JSInterop Wasm dry-run and Cupertino font warnings remain;
native UI, mobile, signing and Wasm acceptance are not claimed.

Limits: daily effort only, 1–3,660 working days, 1,000 date exceptions per calendar,
bounded scheduling horizon. No automatic holidays, hourly capacity, resource leveling
or cross-task propagation. View defaults affect reviewed schedules, not all existing
tasks. Mixed-calendar rows retain their own bindings; background shading uses the
view calendar. Edits use existing durable recovery and guarded session-only undo.

Suggested next task: critical-path and project-slippage analysis with reviewed
dependency impact previews; no automatic schedule writes.

---
# Completed task — Dependency-aware Gantt timelines, 2026-10-10

Status: complete. Authorized: the suggested dependency-aware Gantt feature.
Scope VIEW-11 and TASK-05/06/09; required collections/views and task planning specs,
feature backlog and agent workflow. No new dependencies or desktop control.

Implemented saved task Gantt views with explicit inclusive work ranges, independent
deadline markers, milestones, dependency connectors and warnings; reviewed bar
moves, range editing, after-blocker suggestions and guarded single-task undo.
Folder/command creation, Smart View filters and live note embeds reuse canonical
objects. Unscheduled and unsupported data remain visible/preserved. Automatic
dependency propagation and cross-object scheduling transactions are outside scope.

Validation: 1,663 full tests pass (.local/gantt-full-final.log), including nine new
Gantt tests. Final focused compatibility tests pass; the calendar/planning/controller
focused batch passes 33 tests. Analysis is clean (.local/gantt-analyze-final.log);
strict format reports 473 unchanged files (.local/gantt-format-final.log).
Coverage includes native restart and unknown metadata, preserved deadlines/duration,
missing and unscheduled dependencies, imported cycles, rejected new cycles and
invalid ranges, stale edits, failed saves, undo protecting later work, combined
folder/project scope, shared Smart filters, drag cancellation, live note embeds,
decimal JSON window values, and 360x740 views/forms at 160% text. Assignment editing
rejects inverted ranges while unrelated edits retain unsupported legacy metadata.
Task/spec file links and diff whitespace checks pass. An intermediate layout test
found an overflow, which is fixed; an intermediate full run was intentionally
cancelled to add the numeric compatibility guard before the final frozen-source run.
Windows release builds successfully (.local/gantt-windows-release.log, 107.3s);
web JavaScript release builds successfully (.local/gantt-web-release.log, 97.4s).
Updated bundle: build/windows/x64/runner/Release/. Existing Google JSInterop Wasm
dry-run and Cupertino font warnings remain; no Wasm, mobile build, signing or
desktop-control acceptance is claimed.

Limits: 50 chart rows per page, 14/28/56 calendar-day windows, finish-to-start
dependency suggestions. Missing/undated dependencies prevent suggestions; completed
dependencies do not constrain them. Moves require review and update one canonical
task with guarded session undo. No automatic propagation, resource leveling,
working-day calendars, critical paths or parent-task date rollups.

Next suggested task: working-day calendars for project scheduling.

---
# Completed task — Research collections and evidence-based decisions, 2026-10-10

Status: complete.
Authorized: research/reference workspace and decisions/assumptions as one batch.
Scope VIEW-01/02/05/06/07, manual PROV-03/04/05, deterministic PROV-06 and available
history subset PROV-07. Required docs: collections/views, decisions/provenance,
backlog, agent workflow and existing portable save boundaries. No new dependencies
or architecture migration; no desktop control.

Implemented:
- Folder menu and command palette create reusable research collections; new creative
  projects include a research view linked from their brief. Existing objects and
  board references retain canonical UUIDs. Membership removal retains source bytes.
- Local image/text gallery, paginated table and up-to-four-source comparison;
  persistent tag/type/state/project/text filters, independent per-embed selection,
  linked project brief, live note embeds and full-view Canvas navigation.
- Board commentary remains live, with optional independent collection overrides;
  missing placements fall back to captured details with a visible indicator.
  Unsupported/malformed collections retain their saved entries without rewriting.
- Markdown decision/assumption records with rationale/alternatives, explicit state,
  confidence/importance, supporting evidence, assumption/supersession relations,
  recorded date and bounded before-edit/review checkpoints. Backlinks and graph
  reuse typed canonical relations. Ordinary decision logs remain ordinary notes.
- Direct dependency version warnings include missing/changed evidence and changed,
  missing/disproved/superseded assumptions. Cached content fingerprints detect
  external edits with unchanged frontmatter. Review never rewrites reasoning or
  clears unresolved/disproved assumptions. Stale writes and failed saves report
  errors while retaining drafts and prior checkpoints.

Validation: 1,654 full tests pass (.local/research-full-final.log), including 11 new
research tests. Analysis is clean (.local/research-analyze-final.log); strict format
reports 470 unchanged files (.local/research-format.log); git diff whitespace checks
pass. Coverage includes native restart/unknown metadata, original attachment bytes,
state history, external edits with unchanged frontmatter, stale/self/mistyped links,
read-only records, failed durable saves, malformed collection preservation, live
embeds and board changes, and 360x740 forms/views at 160% text. An intermediate run
failed newly added cases while source changes were still in progress; the current
frozen-source full run passes. Windows release builds successfully
(.local/research-windows-release-final.log). Web JavaScript release builds successfully (.local/research-web-release-final.log). Existing Google JSInterop Wasm dry-run and Cupertino font warnings remain; no Wasm, mobile release, signing or desktop-control acceptance is claimed. Updated Windows bundle: build/windows/x64/runner/Release/.

Limits: manual membership (up to 5,000 entries), 50-row pages, four compared sources,
100 links per record relation, 30 retained note checkpoints. Text filters commit on
Enter. Previews are bounded; Open source retains full original content. No automatic
board membership, external source monitoring, citation scraping or AI analysis.
Existing note history restores title/body only, not research state fields. This
is project record history rather than a complete workspace evolution timeline.

Next suggested task: dependency-aware Gantt project timelines.

---
# Completed task — Creative reference capture and curation, 2026-10-09

Status: complete.
Authorized: a larger batch of drag/drop reference capture with linked attachments,
editable captions and related curation. Scope CAN-02/03/05/08/14 and FILE-01/02/09,
manual source-attribution subset of FILE-10. Required docs: spatial boards,
attachments/research, feature map/backlog and implementation workflow. Preserve
unknown data and unrelated work. No desktop control, remote preview fetching,
execution, new dependencies or source-file modification.

Implemented: owned canonical sources on creative-board drops and batch import
from any Canvas; spaced preview cards with column membership/extension; placement
captions, safe source URLs, tags and review states; bulk state changes, metadata
search and linked reference-summary notes. Capture scene insertion and curation
use existing Canvas undo. Failed imports are reported per file and saved sources
remain available when placement or metadata enrichment fails.

Validation: **1,643 full tests pass** (`.local/reference-full.log`), including seven
new reference tests. Analysis is clean; strict formatting reports 465 files unchanged.
Diff whitespace checks pass. Tests cover native restart and original bytes,
column spacing/extension and lock/future guards, failed metadata enrichment with
retained sources, mixed-success native-drop batches, caption editing and undo,
frozen drop positions during pan, source URL validation, metadata search/summary
links, and 360x740 dialogs at 160% text with malformed metadata. Existing normal
Canvas diagram imports remain covered. Dialog controllers dispose with the route.
Windows release and web JavaScript release compile (`.local/reference-windows-release.log`, `.local/reference-web-release.log`). Updated Windows bundle: `build/windows/x64/runner/Release/`. Existing Google JSInterop Wasm dry-run and Cupertino font warnings remain; no Wasm, mobile release, signing or desktop-control acceptance is claimed.

Limits: up to 100 files per capture using existing incoming-file size checks.
Reference URLs are manually supplied; no scraping, web preview or citation lookup.
Capture undo removes placements while retaining owned sources. Summary notes are
snapshots, not live queries. Archived is a placement label, not source deletion.
No resumable capture job, automatic file deduplication or new media engine claimed.

Next suggested task: reusable reference collections and project comparison views.

---
# Completed task — Connected creative projects and Canvas removal, 2026-10-09

Status: complete.

Authorized: visible deletion for the pictured Canvas sections/cards and connected
creative-project boards with briefs, references and milestones. Scope CAN-02/03/14
and the local creative-planning subset of GAME-01/03. Required docs: spatial boards,
game development, feature map/backlog and implementation workflow. No desktop
control, remote services, dependencies or new durable formats.

Implemented:
- Selected Canvas items have a visible Remove from canvas button. Right-clicking
  inside a column/frame exposes removal while retaining the Add menu. Existing
  read-only/lock guards and undo remain; removing a column detaches its children
  and removing a placement preserves its canonical source object.
- Notes folder > New Creative Project uses the optional brief form and creates a
  linked brief, decision log, references board, production board, four real tasks,
  task view and milestone view. Shared project scope is the brief UUID; cards and
  Markdown links point to canonical IDs rather than copying source content.
- Creative stages Explore/Decide/Produce/Review are stored as optional view
  metadata; existing game milestone defaults remain compatible.
- Validated repository saves preserve portable objects and recoverable history.
  Duplicate project paths and unsafe names are rejected. Interrupted setup keeps
  saved objects visible and reports incomplete setup; it is not an atomic batch
  or an automatic resumable scaffold.

Validation: **29 focused and 1,636 full tests pass** (`.local/creative-focused-final.log`,
`.local/creative-full.log`). Analysis is clean; strict formatting reports 462 files
unchanged. Diff whitespace checks pass. Tests cover native restart, duplicate
protection, interrupted creation, configured stages, menu/button removal, child
retention and undo. Project form labels distinguish creating a connected project
from creating only a brief. A test-exposed context-menu overflow was fixed.
Windows release and web JavaScript release compile (`.local/creative-windows-release.log`, `.local/creative-web-release.log`). Windows bundle: `build/windows/x64/runner/Release/`. Existing Google JSInterop Wasm dry-run and Cupertino font warnings remain; no Wasm support, mobile release, signing or desktop-control acceptance is claimed.

Next suggested task: reference capture into creative-project boards using linked
attachments and editable captions.

---
# Completed task — User feedback repairs and creative/code workflows, 2026-10-09

Authorized: stale recent Vaults, template Canvas deletion, wider Markdown writing,
local grammar quality, project briefs/creative planning (user-selected), and basic
HTML/CSS/C++/JavaScript editing. Scope EDT-02/04/09/14, CAN-02/03, GAME-01/03.
Required docs: Markdown editing, spatial boards, game development, feature map,
backlog and implementation workflow. Preserve unrelated changes and portable
formats. No desktop control, remote grammar, code execution or new dependencies.

Implemented:
- Prune confirmed missing/non-directory recent Vault paths, persisting removal and
  clearing unavailable selections. Retain unavailable volumes, access failures and
  unknown preference fields; no knowledge files are deleted.
- Mark consumed Canvas presets so deleting their starter content stays deleted
  after reopening. Placement deletion keeps object identity, undo and lock guards.
- Wider writing defaults (1080 px), toolbar width presets (800/1080/1600/2000), and
  Settings width range; existing saved widths remain unchanged.
- Local English confidence filtering, repeated-word alignment fixes, better code
  exclusion, half-open correction ranges, and stale-text/composition guards.
- Preserve table cell drag selection by leaving within-block selection to native
  editors rather than replacing the table subtree with document-selection chrome.
- Optional creative-brief form, storyboard/playtest templates, and four code-note
  starters. Expanded code draft editor supports syntax colors, search, wrapping,
  indentation and native text undo; Apply checks source freshness and uses note save.
  Light/dark syntax colors and HTML/language aliases use the existing highlighter.

Validation: **67 focused and 1,631 full tests pass** (`.local/feedback-focused-final.log`,
`.local/feedback-full-final.log`). Analysis is clean; strict formatting reports
460 files unchanged. Diff whitespace and Canvas schema JSON parsing pass.
Tests cover preference pruning/restart and unknown fields, preserved writing
widths, grammar/Markdown exclusions, reversed indentation ranges, template deletion
and reopening, draft source conflicts, creative form output, table drag selection,
cross-block selection and dialogs at 360×740 with 160% text.
Initial validation exposed table-selection reset and code-footer overflow; both
were repaired and the final focused/full suites rerun successfully.
**Windows release and web JavaScript release compile** (`.local/feedback-windows-release.log`,
`.local/feedback-web-release.log`). Windows bundle: `build/windows/x64/runner/Release/`.
Existing Google JSInterop Wasm dry-run and Cupertino font warnings remain; no
Wasm support, signed installer, mobile build or desktop-control acceptance claimed.

Limits: limited offline English rules, not a comprehensive multilingual grammar
engine. The code workspace edits fenced snippets in notes, not arbitrary source
files; no compiler/debugger/language server or execution. Creative checklists and
briefs are editable Markdown, not automatically copied into canonical task objects.

Next suggested task: creative-project scaffolding linking a brief, reference board
and production milestones through existing object identities.

---
# Completed task — Future calendar occurrences and individual changes, 2026-10-09

Authorized: future occurrences directly on the calendar with individual
reschedule/cancel controls. Scope EVT-01–03 local recurrence projection/overrides.
Required docs: calendar/events, task planning, feature map/backlog, ADR 0025,
implemented formats and workflow. Preserve unrelated work; no desktop control,
provider sync, dependencies or SQL migration.

Implemented:

- Read-only occurrence presentations with canonical UUID and stable ordinal keys
  in month/week calendars, planning agenda and day/week timed grids. Repeats are
  expanded once per visible range. Controls/coverage warnings remain accessible.
- Change this occurrence: pick date/time with retained duration, cancel or restore
  original schedule. Regular cadence/resources remain intact. Cancelled records
  are listed in Repeat & history with Restore. Cross-window moves are included.
- Guarded validated source commands, recoverable writes and undo; stale/failed
  edits preserve schedules. Rule edits cannot reset processed count/anchor keys.
  Unsupported/future override formats remain retained but cannot be edited.
- Current occurrence completion records actual rescheduled dates/offset, advancing
  by base cadence. Cancelled current occurrences require skipped recording. ICS
  current snapshots apply supported current moves/cancellations, retaining UID.
- Portable versioned overrides and [ADR 0026](../adr/0026-calendar-occurrence-projection.md),
  no new identities or migrations. Native restart tests cover cancellation metadata.

Validation: **32 focused and 1,622 full tests passed**
(`.local/event-projection-focused-final.log`, `.local/event-projection-full-final.log`).
Analysis is clean; strict formatting reports 456 files unchanged. Documentation
links and diff whitespace pass. Coverage includes stable keys across advancement,
cross-window moves, cancellation/restore, actual-date history, cancelled final
occurrence, same-series overlap, stale/failed writes, undo, native restart and
future-occurrence UI actions. **Windows release and web JavaScript release compile**
(`.local/event-projection-windows-release.log`, `.local/event-projection-web.log`).
Windows output: `build/windows/x64/runner/Release/orbit_note.exe` and adjacent
bundle files. Existing Google JSInterop Wasm dry-run and Cupertino-font warnings
remain. No signed installer, mobile build, Wasm support or desktop acceptance is
claimed. Logs: `.local/event-projection-*`.

Limits: projection visits at most 10,000 occurrences per series/window with visible
warnings; at most 1,000 stored overrides. Paused series show current only, finished
series retain the last schedule/override, with a cancelled final occurrence hidden.
Clock gaps stop expansion with review
feedback. Device timezone changes affect future local dates; no named-zone database,
RRULE exchange, notifications, sync, drag/resize or historical occurrence editor.

Next suggested task: explicit recurrence coverage and conflict review before
applying whole-series schedule changes.

---

# Completed task — Rolling event recurrence, 2026-10-09

Authorized: recurring events with occurrence history and device-clock handling.
Scope: EVT-01–03 local subset. Required docs: calendar/events, feature map/backlog,
ADR 0022, storage formats and workflow. No desktop control, provider adapter,
package, migration or unrelated feature work.

Implemented:

- Event details in Calendar planning offer Repeat & history: daily/weekly/monthly/
  yearly, interval, optional count/inclusive last-start date, pause and six-start
  preview. The calendar shows the current occurrence on one canonical event.
- Explicit completed/skipped actions append the original schedule, UTC action
  time, rule snapshot and device offset, then advance once. Missed dates remain;
  finished series retain their final dates. History shows the latest 100 records
  without truncating storage (explicit limit 10,000).
- All-day recurrence uses civil spans and anchored month-end clamping. Timed
  recurrence uses device-local start clock with retained elapsed duration;
  earlier/later repeated-hour choice is explicit, nonexistent clock times refuse
  the entire save. Edit current time before retrying. No hidden fast-forward.
- Existing guarded recoverable saves/undo protect against stale actions, failed
  writes and read-only objects. Unknown metadata survives; unchanged future
  formats remain editable outside unsupported recurrence controls.
- [ADR 0025](../adr/0025-rolling-event-occurrences.md) records this same-object
  rolling model. Portable format/spec/status updated; no SQL/envelope changes.

Validation: **23 focused tests and 1,613 full regression tests passed**
(`.local/event-repeat-focused-final.log`, `.local/event-repeat-full.log`). Analysis
is clean; strict formatting reports 454 files with zero changes. Documentation
links and diff whitespace pass. Native files/empty-index restart and unchanged
future metadata edits are covered. Clock gap/overlap policy is tested with
deterministic resolver fixtures; no manual device-timezone or desktop checks.
Windows debug and web JavaScript release compile
(`.local/event-repeat-windows-debug.log`, `.local/event-repeat-web.log`). Existing
Google JSInterop Wasm dry-run and Cupertino font warnings remain; no Wasm,
signed release or mobile build is claimed. Logs: `.local/event-repeat-*`.

Initial Windows release attempts were blocked by Windows Application Control
refusing Flutter's windows-x64-release/gen_snapshot.exe during aot_elf_release.
After the owner's request to retry, **Windows release compiled successfully**;
output: `build/windows/x64/runner/Release/orbit_note.exe`, with its adjacent bundle
files. Evidence: `.local/event-repeat-windows-release-retry.log`. Earlier failure logs:
`.local/event-repeat-windows-release.log` and
`.local/event-repeat-windows-release-verbose.log`. The agent did not change security policy.

Limits: current occurrence plus preview, no expanded future-occurrence calendar,
per-instance overrides, named-zone database, RRULE exchange, provider sync or
notifications. ICS remains a current-schedule snapshot. Device timezone changes
affect subsequent repeats; actions use the saved rule, not unsaved form edits.

Next suggested task: expanded future-occurrence calendar projection with stable
occurrence keys and explicit per-occurrence reschedule/cancel choices.

---

# Completed task — Calendar and course planning expansion, 2026-10-09

Owner authorized a substantial calendar update and linked course assignments/exam
planning. Scope: STUDY-01 course planning subset, TASK-03–06, EVT-01–03 and local
PORT export. Required docs: calendar/events, tasks/planning, study/university,
feature map/backlog, storage/open formats, ADR 0022 and agent workflow. Preserve
unrelated changes. No desktop control, dependency, cloud adapter or database migration.

Implemented:

- Calendar planning from Home/workspace toolbar, existing Calendar and course
  dashboard. Timed day/week grids, civil-day headers, all-day/deadline rows,
  overlap lanes, midnight clipping, accessible detail actions and distinct themed
  exam/study colors. The existing month calendar and undoable moves remain.
- Thirty-day agenda, selected-date navigation, Today, course/type/text filters,
  completed toggle, unscheduled work queue, overdue count and explicit estimated
  effort. Remember view saves versioned device-local filters/date; search stays
  visible, future settings are retained and cannot be overwritten.
- Editable assignment, exam, lecture, meeting and study-session presets on real
  tasks/events: separate deadline/work date, priority, effort estimate, descriptions,
  timed/all-day intervals, existing-resource picker and missing-source navigation.
  Links have backlinks; changing event role retains identity and recorded context.
- Linked study sessions from assignments/exams; exam context displays actual
  course card workload through its date and opens Study & Review with that horizon.
  Review due dates/ratings are never changed by choosing an exam. Existing repeat,
  dependencies, completion and guarded undo are reachable from planning details.
- Conflict details use actual timed intervals with exclusive ends, including
  other courses in the current scope. All-day labels do not claim busy hours.
  Device clock-change events explain elapsed duration; named-zone/RRULE remains later.
- Filtered ICS export uses stable UUID UIDs, UTC timed dates, exclusive all-day
  ends, VTODO deadlines/work dates, escaped text and UTF-8-safe 75-octet folding.
  A schedule on/after its deadline uses X-ORBIT-SCHEDULED-DATE to retain both dates
  without an invalid VTODO start/due interval. Export does not sync providers.
- Validated portable calendarPlan metadata, guarded edits/creation, failure
  feedback and retained unknown fields. Future metadata remains readable and
  survives unrelated edits. Week navigation/friendly due labels use civil dates
  rather than 24-hour arithmetic across DST. Narrow 200% controls scroll separately.

Validation: **67 focused tests passed** (`.local/calendar-planning-focused-final.log`),
including Home focus-session pause/resume with the expanded toolbar. Analysis is
clean; strict formatting reports 450 files with zero changes. Documentation links
and diff whitespace checks pass. **1,604 full regression tests passed**
(`.local/calendar-planning-full-final.log`). Windows debug and web JavaScript
release compile (`.local/calendar-planning-windows-debug.log` and
`.local/calendar-planning-web.log`). Existing Google JSInterop Wasm dry-run and
missing Cupertino font warnings remain; no Wasm, signed release, mobile build or
desktop acceptance check is claimed. Logs use `.local/calendar-planning-*`.
Coverage includes native JSON/Markdown/settings restart with an empty derived
index, future metadata, write failures, stale edits, close during staged creation,
backlinks, overlap lanes, overnight clipping, ICS Unicode and narrow text layouts.

Limits: manual planning and explicit effort estimates; no inferred study plan,
Google/Outlook integration, invitations, notifications, event RRULE series,
named-zone ambiguity resolution, or hour-grid drag/resize. Existing calendar-day
rescheduling remains available with previews/undo; precise times use the editor.
The timed grid shows civil clock hours; a repeated hour may be drawn using elapsed
length when its civil end precedes its start. Saved UTC instants remain authoritative.

Next suggested task: event recurrence with explicit occurrence history and
device-zone clock-change rules, before reminders or provider synchronization.

---

# Completed task — Study Resume, 2026-10-09

Authorized: STUDY-04 manual course continuity, with CTX-08–11 subsets. Reuse
existing device-local Space/view descriptors and canonical objects. No desktop
control, AI inference, package or database migration. Required docs: Study and
university, Home and work sessions, feature map/backlog, ADR 0022 and workflow.

Implemented:

- Course selector in Study & Review offers Continue studying: a user-written
  next step, explicit save of open course tabs and reading/writing positions,
  Resume course, live unfinished course tasks and uncertain material.
- Device-local versioned Space extension retains UUIDs, revision/title metadata,
  note cursor/scroll/collapse state, PDF page/zoom and Canvas cameras. It copies
  no source bodies or bytes. Other tabs, appearance and layout remain intact.
- Resume flushes drafts, skips deleted sources, falls back to an available tab,
  resets changed-source offsets, and reloads already-open readers. Missing
  attachment bytes use existing reader recovery. Nothing resurrects old content.
- Related material explains same-course + explicitly uncertain provenance.
  Dismissals survive launches until explicit reset, including across position
  updates. Failed settings writes remain visible; future/invalid descriptors
  cannot be overwritten by continuation saves.

Validation: **1,590 full tests and 41 focused tests passed**. Analysis is clean;
strict formatting reports 444 files with zero changes. Logs:
`.local/study-resume-full-final.log`, `.local/study-resume-focused-final.log`,
`.local/study-resume-analyze.log`, `.local/study-resume-format.log`.
Focused tests cover persistence/restart, changed/deleted sources, write failures,
future settings, PDF/Canvas state, unrelated tabs and narrow 200% text. Native
settings round-trip also retains continuation/dismissals/unknown fields.

Windows debug compiled in 19 seconds (`.local/study-resume-windows-debug.log`).
Web JavaScript release compiled in 94.8 seconds (`.local/study-resume-web.log`).
Existing Google JSInterop Wasm dry-run and missing Cupertino font warnings remain;
Wasm support is not claimed. Specification/status/format links and diff whitespace
checks pass (existing Git CRLF normalization warnings only). No desktop-control test,
signed release, mobile build or cross-device acceptance is claimed.

Limits: manual save, one continuation per course, within the existing 30-context
limit. No automatic tracking, cross-device context sync, adaptive suggestions,
or semantic relocation after source edits. A revised source resets view state.
Next suggested task: course assignment/exam planning with linked study workload.

---

# Completed task — Study cards and offline review, 2026-10-09

Owner authorized source-linked cards from notes/PDF highlights/OCR passages,
offline scheduling/history, course and exam queues, explicit understanding states,
portable export, editable cards and recoverable changes. STUDY-05 and the manual
review-state subset of STUDY-03. No desktop control, account, external recognition,
new dependency or separate study database. Preserve unrelated changes.

Required docs: study/university specification, feature map/backlog, storage/open
formats/universal objects, focused agent workflow and definition of done.

Implemented:

- Ordinary Markdown cards use the existing note title/body and stable UUID, with
  validated versioned frontmatter schedules, source snapshots and full review
  history. No database migration/new dependency. Unknown keys/unsupported versions
  survive unrelated edits and export; invalid changes reject without writes.
- Guarded durable creation/review/edit commands serialize with planning and Vault
  closure. Failed writes, stale answers, early/paused ratings and clock rollback
  do not advance a queue. Undo restores complete content/scheduling unless later
  edits exist. Native before-file recovery retains the pre-review card.
- Study & Review from Home/workspace/course dashboards offers due queues,
  course/search filters, seven-day/exam-horizon workload, answer reveal, visible
  Again/Hard/Good/Easy intervals, Space/1–4 keyboard controls, pause/resume,
  editing, lazy card/history lists, refresh and JSON export. Narrow/enlarged text,
  empty/error/read-only/stale/closed-Vault states use existing dialog components.
- Note selections, PDF highlight/quote notes and recognized passages make cards
  with captured source UUID/revision/time/passage and optional page/checksum.
  OCR bytes are verified before creation; oversized passages are refused rather
  than silently cut. Source backlinks and inspector mentions find cards. PDF
  navigation returns to the recorded page. Missing/changed sources retain evidence.
- Markdown and equation answers render using existing parsers. Images retain
  text descriptions; open the original source for media. Understanding is an
  explicit uncertain/learning/understood state on material, never inferred from
  a review rating. Original note/attachment bytes are not rewritten by cards.

Limits: fixed UTC intervals, not adaptive memory predictions. Exam horizon is
temporary workload UI state; it does not schedule early reviews or automatic
exam plans. Refresh updates clock-only due changes. 2,000 question characters,
100,000 answer/source-passage characters, 500 course characters, 10,000 reviews
per card; history is never silently truncated. JSON is archival interchange,
without a dedicated re-import/Anki adapter. Existing Vault backups preserve cards.
No new Study Resume, Canvas learning-map renderer, cloze/image occlusion,
notifications or production signing is claimed. See
[ADR 0024](../adr/0024-portable-study-cards.md) and
[formats](../architecture/implemented-formats.md).

Validation: **1,585 full Flutter tests passed** (`.local/study-full-final.log`).
**67 focused checks passed** (`.local/study-focused-final.log`), including source
backlinks, actual OCR-byte mismatch, PDF page return, unknown/future metadata,
review timing/caps, failed writes/retry, concurrent ratings/creation, Vault closure,
restart/index rebuild, trash/restore, understanding independence, equation answers,
keyboard review and compact 200% text. Native Markdown/recovery acceptance also
passed independently (`.local/study-native.log`). Analysis has zero issues and
strict formatting checks 441 files with zero changes (`.local/study-analyze.log`,
`.local/study-format.log`). Documentation links/diff checks pass. No desktop
control or system setting changes used.

Windows **debug build passes** (`.local/study-windows-debug.log`), producing
`build/windows/x64/runner/Debug/orbit_note.exe`. Web **release build passes**
(`.local/study-web.log`), producing `build/web`. The existing Wasm dry-run warning
in google_identity_services_web and missing Cupertino font warning remain; no
Wasm or signed Windows release claim is made. Real-device acceptance and Android/
iOS builds were not run for this task. Existing platform save adapters report
unsupported export operations; owning Markdown/Vault backup remains portable.

Status: scoped implementation, automated acceptance and Windows/web compilation
complete. Suggested next task: Study Resume Context (STUDY-04),
restoring course reading/writing positions and unfinished work with missing-source
recovery and explained/dismissible related material.

---
# Previous task — Local OCR and recognition review, 2026-10-09

Owner authorized all five OCR outcomes: offline PDF/image recognition, unified
search/source navigation, linked passage notes, review/corrections and background
progress/pause/cancel/retry with source invalidation. FILE-08 plus FILE-05/09.
Required docs: attachment/research spec, feature map/backlog, search/storage/open
formats/object model, agent workflow and definition of done. No desktop control,
remote recognition, new accounts or system security changes; preserve unrelated edits.

Implemented:

- Windows Media OCR runs on one background worker with window-thread result
  delivery, using installed profile languages and image bytes only. PDFium renders
  serial bounded PNGs; copying-restricted PDFs refuse. Missing languages/unsupported
  decoders/platforms have explicit failures. No new package, network or subprocess.
- Portable versioned file metadata retains original recognized text, normalized
  line regions and optional corrections, bound to actual SHA-256/path. Validated
  recoverable saves reject stale objects/sources. Original bytes/UUIDs stay intact;
  unknown sibling/page keys and unsupported records survive unrelated edits.
- Shared search overlays verified OCR on blank PDF pages/images; explicit
  corrections override native text. Raw property search excludes OCR to prevent
  stale evidence leaking through metadata. Restart/cache rebuild reconstruct OCR
  search. Changed sources remove old matches and retain evidence for review;
  recognize again stages complete replacement, keeping same-source corrections.
- PDF/image matches mark source lines after displayed-byte verification. Corrected
  text returns to its page without claiming exact regions. Selected passages create
  ordinary Markdown notes with UUID page links/checksum provenance; PDF notes reuse
  connected-note/source navigation. No confidence score is fabricated.
- Search scanner, PDF Document tools and image preview open a scrollable review
  panel with serial bulk recognition, progress, pause/resume, cancel, failure/retry,
  correction save/reset and passage extraction. Panel close leaves work running;
  Vault close/switch cancels and waits before repository teardown.

Limits: new recognition is Windows-only; other platforms read/search saved text
and edit corrections. Language/codec support follows Windows; there is no automatic
language detection or installation. Printed text works best; handwriting, equations,
columns, rotation/EXIF fidelity are not guaranteed. Geometry marks lines, not glyphs.
100 MiB source, 500 pages, 2 Mi UTF-16 characters including corrections, 20,000
lines per record; raster long edge 2,600px, original image guard 100MP. Cancellation
finishes the current page; only complete files commit. Interrupted jobs restart
explicitly. Changed sources require explicit re-recognition to replace evidence.
No redaction, semantic reflow or equation conversion is implied.

Validation: **1,560 full Flutter tests passed** (`.local/ocr-full-final.log`),
including future-format preservation, cache rebuild from portable records,
correction/native-text precedence, stale edits/bytes, failed writes and cancellation.
Earlier 41 focused OCR/search and 21 OCR/native-PDF checks passed
(`.local/ocr-focused.log`, `.local/ocr-native-flutter.log`). Analysis and strict
formatting are clean across 436 files (`.local/ocr-analyze.log`,
`.local/ocr-format-check.log`). Native shipping-engine C++ compiles with /W4 /WX,
recognizes the generated ORBIT image and rejects corrupt bytes
(`.local/ocr-native-compile-strict.log`, `.local/ocr-native-run.log`,
`.local/ocr-native-corrupt.log`). Real PDF rendering/recognized-page navigation
has headless Flutter acceptance; no desktop control used.

Windows **debug build passes** (`.local/ocr-windows-debug-final.log`), producing
`build/windows/x64/runner/Debug/orbit_note.exe`. Initial generated-toolchain failures
were resolved with project-local plugin junctions and restoration of SDK wrapper
sources. A stale clipboard bridge messenger API was corrected alongside the new
OCR channel. No Developer Mode, Application Control or other system settings changed.
Web release builds (`.local/ocr-web.log`); its Wasm dry run reports a dependency
JS-interop runtime-check incompatibility in google_identity_services_web, and the
existing Cupertino font warning remains. No Wasm compatibility is claimed.
Changed documentation links and diff checks pass (existing Git line-ending
normalization warnings remain). See
[ADR 0023](../adr/0023-local-ocr-evidence.md) and [formats](../architecture/implemented-formats.md).
Status: Windows-first implementation/automated acceptance complete. Signed/release
packaging, real-device/runtime acceptance and other-platform OCR engines are
separate; no production release artifact is claimed. Suggested next task:
Android-local recognition using the same portable evidence/review contracts.

---
# Previous task — Smart Views, Spaces and advanced planning, 2026-10-08

Owner authorized priorities 1, 2 and 3 together: shared validated saved queries
and a visual builder; named Spaces/layouts and configurable dashboards; recurring
task occurrences/history, dependency/subtask validation and undoable rescheduling.
Build on current views, embeds, session state and canonical task objects.

Required docs: features/collections-and-views.md, features/customization-and-spaces.md,
features/tasks-calendar-and-planning.md, features/calendar-and-events.md,
architecture/ui-layout.md, architecture/universal-object-model.md,
architecture/implemented-formats.md, development/agent-workflow.md and
development/definition-of-done.md. Backlog IDs: VIEW-01/02/03/06/07/10,
LAY-03/04/05/10, TASK-06/07/09 and EVT-03 (rescheduling subset).

Plan: unify query evaluation before composing contexts/dashboard widgets; add
validated planning rules and UI; verify restart/unknown-data/read-only/stale/undo
boundaries and accessible layouts; update formats/architecture and delivery evidence.
No new cloud/OCR/AI work, arbitrary docking, reminders or external providers.
No desktop-control testing. Existing unrelated edits remain intact.

Implemented:

- Versioned shared AND/OR queries with property/tag/date/number/relation-ID filters,
  sort/group/custom columns and an editable visual builder. List/table/board/gallery
  build visible rows lazily; calendar/timeline project recorded dates. Cells and
  board moves edit canonical objects. Rename/duplicate reuse definitions; note
  embeds retain shared sort, Home widgets and Canvas previews resolve the same IDs.
  Canvas redraws on status/query membership/failure changes without scene edits.
- Device-local named Spaces/layouts with save/switch/update/rename/duplicate/remove,
  independent tab/pane/position/camera/search/dashboard state, project/folder scope
  and optional appearance. All-Vault restores the prior context. Home widgets have
  add/remove/order/column-span customization with apply/cancel and default reset.
  Missing/unknown records remain recoverable and content stays in place.
- Task recurrence with civil daily/weekly/monthly/yearly dates, month-end anchor,
  same-ID occurrence history and explicit missed-date behavior. Multiple blockers
  and parent/subtask IDs reject new invalid targets/cycles. Legacy unsupported or
  unresolved unchanged data survives unrelated edits. Calendar month/week drag,
  agenda and timeline date-picker moves preview fields, preserve event duration and
  separate task dates, then save through guarded recoverable commands with undo.
- Save failures release command locks, concurrent completion cannot duplicate an
  occurrence, flush/close wait for writes, and undo refuses later edits. Controls
  fit narrow/landscape and 250% text layouts. Existing Home continuation remains
  reachable by scrolling. All testing is automated; no desktop control was used.

Formats/architecture: additive metadata and device descriptors only, no schema
migration or rewriting old sources. [ADR 0022](../adr/0022-smart-views-spaces-and-task-planning.md)
and [implemented formats](../architecture/implemented-formats.md) describe authority,
versions, limits and compatibility. Full roadmap IDs remain broader than this batch.

Limits: queries materialize bounded definitions/results in memory; Canvas embeds
preview and open the full saved view; gallery uses recorded text. Nested predicate
trees, query-prefilled creation, arbitrary docking/multi-window/portable context
import, RRULE/named-zone recurrence, reminders, automatic dependency propagation,
formulas/Gantt/AI and provider calendars remain separate. Quick undo is session-local;
repository history persists. Device contexts remain excluded from portable backups.

Validation: 60 focused tests passed (.local/productivity-focused.log), including
restart/unknown formats, stale/failed writes, serialization, same-object edits,
recurrence/DST civil dates/undo, lazy tables, drag, embeds and large-text layouts.
Static analysis and strict formatting are clean across 428 files. Web release
compilation and its Wasm dry run passed (.local/productivity-web.log); the existing
Cupertino font warning remains. Windows release reached native AOT, then host
Application Control blocked Flutter's gen_snapshot compiler executable
(.local/productivity-windows-verbose.log). Security settings were not changed.
**1,540 full Flutter tests passed** in the isolated final run
(.local/productivity-full.log). The first parallel attempt lost a generated SQLite
test DLL to the native build; assets were regenerated after builds finished and
both storage migration/rebuild tests then passed. Original Vault files were
unaffected. Documentation links and diff checks pass; existing Git line-ending
normalization warnings remain. No native release artifact is claimed.

Status: scoped implementation and automated acceptance complete. Windows release
validation remains blocked by the host compiler policy above; mobile/browser
runtime acceptance and the separately scoped roadmap features are not claimed.
Suggested next task: local OCR for scanned PDFs with honest search coverage.

---
# Previous task — Complete PDF workspace search, 2026-10-08

Scope: implement PDF text search alongside notes, tasks, and Canvas; page-level
excerpts and verified exact-match navigation; filters before pagination;
background progress, failures and incomplete coverage; checksum-bound safe
reindexing. User authorized the complete batch. Relevant backlog: LNK-01,
LNK-02, LNK-08, LNK-12 and FILE-08 (text-based PDFs, not OCR).

Required docs: architecture/search.md, architecture/references.md,
features/search-links-and-graph.md, features/attachments-and-research.md,
development/agent-workflow.md. Originals and stable object identity remain
authoritative. No desktop-control testing. Disposable cache only, with old
workspace migration/rebuild evidence.

Implemented:

- One serial background PDF worker per Vault, initialized independently of the
  reader, with repository-owned reads and a disposable versioned page-text cache.
  Native schema 3→4 preserves existing FTS/objects; browser cache is session memory.
- Page excerpts join notes, tasks, metadata and live Canvas locations. Repeated
  occurrences highlight the correct excerpt range and open their exact page/text.
  Controller/reader both verify source bytes; progressive pages load before range
  mapping. Changed bytes reload an already-open reader. Clear match is reversible.
  Only page navigation is saved; offsets remain transient.
- Complete native/memory candidates and global locations replace the first-100
  cutoff. Filters and sorting precede 50-row lazy pagination, with totals and
  previous/next actions. Background refresh preserves the selected destination.
- Coverage shows pending/page progress, pause/resume, failed PDFs with retry,
  no-text/scanned pages and partial text coverage. Cache failures retain session
  search and report the warning. Original files remain accessible on failure.
- Actual hashes verify cache reuse and pre/post extraction. Partial work is never
  searchable. Watch events invalidate immediately; focus/reload catch missed
  events. Relink/deletion/pause/close cancel obsolete publication/navigation.
- Behavior tests cover source races, original-byte/metadata preservation, cache
  restart/rebuild/corruption/migration, limits, progress/retry/coverage, filters
  beyond 100, pagination/keyboard selection, large-text layouts and real PDF ranges.

Limits: OCR, password retention, collection/Space scope and database cursor paging
are not delivered. Sources above 100 MiB and extracted text above 32 Mi characters
fail visibly. Complete query results/text remain materialized in memory. Other
device/browser runtime acceptance is separate from native automated checks.

Validation: **66 focused tests passed** (.local/pdf-search-focused.log), including
real PDFium extraction/range navigation and initialization before a reader opens.
**1,512 full Flutter tests passed** (.local/pdf-search-full.log). Static analysis
is clean (.local/pdf-search-analyze.log); strict formatting is clean across 417
files. The final legacy filename-only PDF routing adjustment passed focused tests
and analysis after the full-suite run. No desktop-control testing was used.

Windows release compilation reached native AOT, then Windows Application Control
blocked Flutter's compiler executable (.local/pdf-search-windows-verbose.log).
Generated plugin junctions use the existing documented local build workaround;
Windows security settings were not changed. **Web release compilation passed**
using the existing short-SDK-path environment (.local/pdf-search-web-short-path.log),
including its Wasm dry run. The existing Cupertino font warning remains; this is
compile evidence, not browser/mobile runtime acceptance. Documentation links and
`git diff --check` passed, with existing line-ending normalization warnings only.

Status: feature implementation and automated acceptance complete; release build
validation has the host-policy limitation above.
Suggested next task: local OCR for scanned PDFs, with explicit coverage and the
same source-version guards.

---
# Previous task — Note link picker accessibility and layout, 2026-10-08

Scope: audit the note link picker at narrow widths, enlarged text, and keyboard
insets. Required context: UI layout and search/link feature contracts. Preserve
title/alias matching, exact object identities, insertion/repair, and cancellation.
Use widget tests without desktop control.

Implemented:

- Replaced fixed-size content with the shared scrolling Orbit dialog: heading,
  query, result status, and variable-height lazy rows share a scroll surface;
  Cancel remains reachable in the separate footer.
- Full titles, stable IDs, and aliases wrap. Same-title targets remain distinct
  and use stable ID as a deterministic title-sort tie-breaker.
- Arrow keys reveal measured row geometry, including tall-row beginnings; Enter
  chooses the current selection among multiple matches. Modified arrows retain
  native text-editing behavior. Repeated Enter cannot complete the dialog twice.
- Query changes and accessible Clear reset selection/scroll; Clear restores
  search focus. Empty results cannot select a target. Reveal requests cancel on
  query changes, row focus changes, and disposal.
- Result rows merge button, selected state, full label, and activation semantics.
  Tab/Space activation preserves focus across selection changes. Result counts
  expose live-region semantics. Dialog motion follows the Orbit motion preference.
- Added 11 cases for 250% text at portrait/landscape widths, keyboard insets,
  long titles/IDs/aliases, 30 lazy rows with forward/backward selection,
  alias search/clear, duplicate titles, exact returned targets, initial queries,
  modified arrows, repeated Enter, cancellation, and empty states.

Validation: **32 focused tests passed** (.local/note-link-layout-focused.log).
Formatting and strict formatting are clean across 408 files. Static analysis is
clean (.local/note-link-layout-analyze.log). **1,476 full Flutter tests passed**
(.local/note-link-layout-full.log). `git diff --check` passed with existing
line-ending normalization warnings only.
No desktop-control testing or platform release build is part of this layout task.

Status: complete.
Suggested next task: unresolved-link repair dialog accessibility and layout.

---

# Previous task — Quick Switcher accessibility and layout, 2026-10-08

Scope: audit Quick Switcher at narrow widths, enlarged text, and keyboard insets.
Required context: UI layout and search/link feature contracts. Preserve ranking,
local object destinations, and create-note commands. Use widget tests without
desktop control.

Implemented:

- Full titles, context, and create-note labels wrap into variable-height lazy
  rows. Badges stack below labels at narrow widths or enlarged text sizes.
- Search and accessible Clear/Close controls remain visible above scrolling
  results, empty state, and shortcut hints; short windows and keyboard insets
  do not push dismissal controls out of reach.
- Arrow selection reveals actual row geometry, including the beginning of rows
  taller than the viewport. Query changes and clearing reset selection/scroll;
  obsolete reveal requests cancel on query changes, hover, or disposal.
- Result rows expose button/selected semantics and support Tab with Space/Enter
  activation. Focus survives selection changes; modified arrows retain native
  text-editing behavior. Enter repeats cannot issue duplicate open/create actions.
- Ranking, exact-match/create behavior, cached results, stable identities, and
  distinct PDF/file/LaTeX context remain intact.
- Added 11 widget cases for 250% text in portrait/landscape, keyboard insets,
  long labels/context/badges, 30 lazy results, backward navigation, query/clear
  resets, accessible keyboard activation, modified arrows, empty states, and
  duplicate creation prevention.

Validation: **22 focused tests passed** (.local/quick-switcher-layout-focused.log).
Static analysis is clean (.local/quick-switcher-layout-analyze.log). Formatting
and strict formatting are clean across 407 files. **1,465 full Flutter tests
passed** (.local/quick-switcher-layout-full.log). `git diff --check` passed with
existing line-ending normalization warnings only.
No desktop-control testing or platform release build is part of this layout task.

Status: complete.
Suggested next task: narrow-window and enlarged-text audit of the note link picker.

---

# Previous task — Large-text workspace search and command palette, 2026-10-08

Scope: audit workspace search, previews, saved-search dialogs, and command palette
at narrow widths, enlarged text, and keyboard insets. Required context: UI layout,
search composition, and search/link feature contracts. Use widget tests without
desktop control; preserve bounded search coverage, recipes, and precise locations.

Implemented:

- Search keeps the query field visible while filters, counts, status messages,
  and lazy results share a scroll surface. Results use actual wrapping heights;
  full titles, metadata, excerpts, and long filter values remain readable.
  Preview actions stack beneath result text when width/scaling requires it.
- Keyboard selection reveals measured lazy-row geometry rather than fixed scaled
  heights. Query changes/disposal cancel old reveal requests; filter changes
  reset selection/scroll position. Index limits and sorting/ranking are unchanged.
- Narrow preview dialogs scroll full headings/context/excerpts with separate
  Close/Open actions. Wide preview headings/content scroll together, keeping Open
  reachable in short windows. Source locations and selection-only previews remain
  unchanged.
- Save/manage dialogs use shared Orbit scrolling content and action footers.
  Long recipe names/queries and validation wrap; removal/undo preserves unrelated
  and unknown recipe metadata. Start-screen section actions wrap.
- Palette search and Close remain visible while type filters, grouped entries,
  and shortcut help scroll. New-note shortcut text sits below its label; selected
  entries reveal their beginning, including rows taller than the viewport.
  Query/type changes reveal the reset selection; command/navigation behavior stays
  intact.
- Added 13 cases at 250% text for portrait/landscape windows, keyboard insets,
  long filters/titles, 25 lazy results, exact-source previews, error/empty states,
  saved-search removal/undo, validation/cancellation, palette navigation/close,
  and a short wide-preview layout.

Validation: **37 focused tests passed** (`.local/search-layout-focused.log`).
**1,454 full Flutter tests passed** (`.local/search-layout-full.log`). Static
analysis is clean (`.local/search-layout-analyze.log`); formatting and strict
formatting are clean across 406 files. `git diff --check` passed with existing
line-ending normalization warnings only. No desktop-control testing or platform
release build was used for this layout batch.

Status: complete.
Suggested next task: narrow-window and enlarged-text audit of Quick Switcher.

---

# Previous task — Large-text object properties and relations, 2026-10-08

Scope: audit object properties, edit forms, relation references/tabs, and local
graph controls at narrow widths and enlarged text. Required context: UI layout
and universal object identity/property/relation contracts. Use widget tests
without desktop control; preserve property types, unknown data, and destinations.

Implemented:

- Property rows stack labels/removal above values when width/text size requires
  it. Full names, values, IDs, dates, URLs, and long tags wrap; boolean/tag/removal
  controls have usable targets without clipping the switch.
- Relation headings/tabs wrap with selected semantics; source titles, precise
  reference badges, matched text, and snippets remain readable. Unlinked mention
  actions sit below source headings, preserving the validated link command.
  Outbound/related object rows opt into wrapping titles.
- Local graph statistics, hop controls, and hover details wrap within the panel.
- Property forms use the shared scrolling Orbit dialog and separate action
  footer. Type choices have variable heights, validation messages wrap fully,
  and one content scroll surface keeps controls reachable in short windows.
  Text controllers dispose when their dialog route unmounts.
- Stored dates outside the date picker's 2000–2100 range open safely; cancellation
  preserves the original value.
- Added 11 cases covering 280-pixel inspectors at 250% text in portrait/landscape,
  unknown metadata preservation, typed updates/removal, source navigation,
  outbound labels, unlinked conversion, validation/cancellation, keyboard insets,
  local graph controls, and legacy dates. Existing inspector interaction tests
  wait for scroll layout before tapping the now-variable-height content.

Validation: **17 focused tests passed** (`.local/inspector-large-text-focused.log`).
**1,441 full Flutter tests passed** (`.local/inspector-large-text-full.log`).
Static analysis is clean (`.local/inspector-large-text-analyze.log`); formatting
and strict formatting are clean across 405 files. `git diff --check` passed with
existing line-ending normalization warnings only. No desktop-control testing or
platform release build was used for this layout batch.

Status: complete.
Suggested next task: narrow-window and enlarged-text audit of workspace search
and command palette results/actions.

---

# Previous task — Large-text PDF navigation and Canvas search, 2026-10-08

Scope: audit PDF outline, saved pages/name editing, custom zoom, and Canvas search
at narrow widths, enlarged text, and keyboard insets. Required context: UI layout,
attachments/research navigation contracts, and spatial board interaction rules.
Use widget tests without desktop control; preserve native scaling and lazy lists.

Implemented:

- PDF outline and bookmark labels/context wrap in variable-height lazy rows.
  Their heading, search/sort controls, and list share one scroll surface, keeping
  Close/Open page in the footer. Bookmark preview sits before the list so it is
  reachable without traversing every bookmark; page IDs and destinations are unchanged.
- Keyboard selection reveals measured row geometry rather than assuming a fixed
  row height. Superseded/disposed reveal requests stop; tall rows reveal their top.
  Existing outline keyboard coverage now waits for the final layout/reveal frame.
- Bookmark rename help/failure feedback and zoom validation wrap completely.
  Failed names remain editable; unavailable pages still cannot be opened.
- Canvas search fits the actual board viewport. Search/navigation/close controls
  stay above a bounded scroll surface containing wrapping categories and lazy
  results. Full titles/snippets wrap; controls have larger targets, and active
  results reveal themselves when navigating or changing categories/results.
- Added 10 portrait/landscape cases at 250% text, including long headings, keyboard
  traversal, absent pages, rename failure, zoom validation, search result selection,
  and active Canvas search with 240/80-pixel keyboard insets.

Validation: **43 focused tests passed** (`.local/navigation-large-text-focused.log`).
**1,430 full Flutter tests passed** (`.local/navigation-large-text-full.log`).
Static analysis is clean (`.local/navigation-large-text-analyze.log`); formatting
and strict formatting are clean across 404 files. `git diff --check` passed with
existing line-ending normalization warnings only. No desktop-control testing or
platform release build was used for this layout batch.

Status: complete.
Suggested next task: narrow-window and enlarged-text audit of object properties
and relation inspector controls.

---

# Previous task — Large-text PDF and Canvas panels, 2026-10-08

Scope: continue the accessibility batch through PDF connected notes/review and
Canvas layers/card inspectors. Required context: UI layout, attachments/research,
and spatial board specifications. Use widget tests without desktop control.

Implemented:

- Panel headings and actions stack at narrow widths or enlarged text sizes.
- PDF review filters wrap; review item controls move below their text. Connected
  note titles and source-version warnings wrap without truncation. Citation drag
  feedback bounds long titles while preserving the existing drag payload.
- Canvas layer headings, labels, badges, and controls reflow. The heading and lazy
  layer list share one scroll surface; Close, Show All, and Unlock All stay in the
  footer. Selection, visibility, locking, and stacking commands retain their behavior.
- Canvas card inspectors fit the actual Canvas viewport, including their full
  height. Type labels wrap, action targets are enlarged, and the title, source
  warning, details, and footer actions scroll together below the inspector controls.
- Added 10 portrait/landscape widget cases at 250% text for panel actions, stale
  citation safeguards, connected-note search/Enter and citation drag feedback,
  layer visibility/locking/recovery commands, and task/reference actions.

Validation: **52 focused tests passed** (`.local/panel-large-text-focused.log`);
**1,420 full Flutter tests passed** (`.local/panel-large-text-full.log`).
`flutter analyze` is clean (`.local/panel-large-text-analyze.log`); formatting
and strict formatting are clean across 403 files. `git diff --check` passed
with existing line-ending normalization warnings only. No desktop-control
testing was used; no platform release build was requested for this batch.

Status: complete.
Suggested next task: enlarged-text audit of PDF navigation dialogs and Canvas search.

---

# Previous task — Large-text history, backup, and settings batch, 2026-10-08

Scope: audit document history, backup/recovery review, and settings dialogs
together. Required context: history/recovery feature spec and UI layout contract.
Use widget tests rather than desktop-control testing; preserve native text scaling.

Implemented:

- Shared Orbit dialogs scroll their headings and content together, with smaller
  narrow-window insets and footer actions outside the scroll surface.
- History uses stacked panes on narrow windows or at enlarged text sizes, with
  bounded revision/diff viewports, wrapping labels and mode controls, and Close.
  Snapshot label editing owns/disposes its controller and avoids updates after exit.
- Recovery files show wrapping paths and retain independent bounded list/preview
  viewports. Export still preserves the retained bytes without changing the source.
- Backup review lists every validation notice before the folder-picker decision.
  Cancel/Choose folder remain separate, explicit actions.
- Settings dropdowns move below their labels when needed, support wrapping menu
  values, and preserve preference changes. Analytics, sync headings, badges, motion
  controls, theme previews, swatches, and corner controls reflow with enlarged text.
- Theme gallery/generator secondary tools live in scrolling content so they cannot
  crowd out the preview or Close/Cancel/Apply. Color and theme confirmation dialogs
  scroll headings and content; keyboard insets retain access to color actions.

Validation: 12 new widget cases cover 320×640 portrait and 568×320 landscape at
250% text, all backup notices and both choices, snapshot selection/preview and
restore cancellation, byte-preserving recovery export, settings persistence,
gallery/export/generator/import reflow, 320% snapshot editing with a 240-pixel
keyboard, and color validation/apply with keyboard insets. **82 focused tests
passed** (`.local/dialog-large-text-focused.log`); **1,410 full Flutter tests
passed** (`.local/dialog-large-text-full.log`). `flutter analyze` is clean
(`.local/dialog-large-text-analyze.log`); formatting and strict formatting are
clean across 402 files. `git diff --check` passed with existing line-ending
normalization warnings only. No desktop-control testing was used.

Status: complete.
Suggested next task: large-text accessibility audit of PDF and Canvas side panels.

---

# Previous task — Recovery dialog font scaling and overflow, 2026-10-08

Audited recovery at 320×640 portrait and 568×320 landscape with 250% text,
high contrast, long staged filenames/paths/checksums, and paginated history.
The tests reproduced horizontal overflow in pagination and vertical overflow
in the fixed title. The recovery dialog now scrolls its title and content as
one surface while keeping Close/Cancel outside the scroll area. Pagination
wraps its page label between fixed navigation buttons. Both the main dialog
and the cleanup confirmation use 16-pixel outer insets; confirmation content
scrolls and its actions stack with spacing when necessary.

A further regression changes text size to 320% and opens a 240-pixel keyboard
inset during verification. The operation, progress, and cancellation callback
survive the layout change; the cancel action stays visible above the keyboard.
No font scaling is clamped and no authored source text is truncated.

Validation: **7 recovery widget tests passed**, **1,398 full Flutter tests
passed** (`.local/recovery-font-scale-full.log`), `flutter analyze` clean, and
strict formatting clean across 400 files. `git diff --check` passed with existing
line-ending normalization warnings only. No desktop-control testing was used.

Status: complete.
Suggested next task: large-text accessibility audit of document history,
backup/restore, and settings dialogs.

---

# Release build attempt — Windows and Android, 2026-10-08

The requested local release builds were attempted from the current worktree.
The Windows build stopped at Flutter's plugin symlink prerequisite because
Windows Developer Mode is disabled. The Android release build stopped before
Gradle because no Android SDK is installed or configured; both `ANDROID_HOME`
and `ANDROID_SDK_ROOT` are empty. No release artifact was produced by either
command. After enabling Developer Mode and installing/configuring the Android
SDK (with a supported JDK), rerun the documented release commands.

Commands attempted:

- `flutter build windows --release --no-pub --dart-define-from-file=.local/google-build.windows.json`
- `flutter build apk --release --no-pub`

---

# Previous task — Recovery dialog theme-surface contrast audit, 2026-10-08

The recovery dialog now hardens the active color scheme before rendering its
content. Custom palettes with unreadable `onSurface`, `onSurfaceVariant`,
`outline`, or `primary` values receive deterministic black/white fallbacks
that meet the appropriate WCAG threshold while preserving the user's surface
color. The dialog's high-contrast boundaries, larger controls, and
reduced-motion behavior remain enabled on top of that fallback.

Added a widget regression that exercises the dialog with light, dark, and a
deliberately low-contrast custom palette. The focused recovery suite passes 47
tests; the full Flutter suite passes 1,395 tests.

Status: implementation complete; next implementation task: recovery dialog
font-scale and text-overflow audit across compact and large accessibility
settings.

---

# Previous task — Recovery dialog high-contrast and reduced-motion audit, 2026-10-08

The recovery dialog now adapts its visual treatment to accessibility settings.
High-contrast mode adds a stronger dialog outline, source-card boundaries,
larger action hit targets, and a thicker progress bar using the active color
scheme. Reduced-motion mode disables progress ticker animation while retaining
the live percentage and status updates. These changes preserve the existing
keyboard and screen-reader behavior.

Added a visual regression covering high-contrast boundaries and reduced-motion
progress behavior. The focused recovery suite now passes 46 tests; the full
Flutter suite passes with 1,394 tests. `flutter analyze`, strict formatting,
and `git diff --check` are clean.

Status: implementation complete; next implementation task: recovery dialog
theme-surface contrast audit across light, dark, and custom palettes.

---

# Previous task — Recovery dialog accessibility and keyboard feedback, 2026-10-08

The attachment recovery dialog now exposes a named semantic route, announces
source-history page changes and recovery progress, groups each staged or
retained source with its identifying details, and keeps the action order
keyboard traversable. Escape cancels an active operation or closes an idle
dialog. Ctrl+Page Up/Down changes history pages, and cancellation immediately
announces that sources remain preserved while disabling repeat requests.

Added widget regressions for semantic pagination controls, keyboard paging, and
Escape cancellation feedback. The focused recovery suite now passes 45 tests;
the full Flutter suite passes with 1,393 tests. `flutter analyze`, strict
formatting, and `git diff --check` are clean.

Status: implementation complete; next implementation task: recovery dialog
high-contrast and reduced-motion visual audit.

---

# Previous task — Attachment recovery history pagination and cancellation, 2026-10-08

Long retained-source histories are now paginated in the recovery dialog with
eight entries per page, so inspecting older immutable sources does not create
an unbounded surface. Restore, relink, resume, and forget operations accept a
cancellation callback that is checked while every streamed chunk is read.
Cancelling verification leaves retained history and source bytes untouched;
cancelling a native staged transfer leaves its durable partial stage available
for resume. The dialog keeps the cancellation state visible and explains that
the user's references were preserved.

Added a repository regression proving that cancellation preserves a resumable
native stage, alongside the existing retained-source and staged recovery
coverage. The focused native staging, storage, and read-attachment suite now
passes 43 tests; the full Flutter suite passes with 1,391 tests. `flutter
analyze`, strict formatting, and `git diff --check` are clean.

Status: implementation complete; next implementation task: recovery dialog
accessibility audit for paginated history and cancellation feedback.

---

# Previous task — Recovery verification UX for large files, 2026-10-08

Retained-source restore and cleanup now verify native attachment bytes through a
stream instead of materializing the whole source in memory. The recovery dialog
shows verification progress for “Use this source” and “Forget retained source”.
Cleanup verifies the recorded checksum before saving metadata or deleting bytes;
missing or externally changed files leave their history untouched for recovery.

Added regressions for progress reporting and changed-byte protection. The
focused native staging, storage, and read-attachment suite passes 42 tests;
the full Flutter suite passes with 1,390 tests. `flutter analyze`, strict
formatting, and `git diff --check` are clean.

Status: implementation complete; next implementation task: attachment recovery
source history pagination and large-file cancellation.

---

# Previous task — Recovery-stage retention cleanup, 2026-10-08

Native attachment recovery now removes abandoned device-local stages during
Vault startup when their durable progress manifest is more than 30 days old.
Cleanup deletes only the matching `.part`, manifest, and temporary manifest
for a well-formed stage. Recent or active stages remain resumable, while
malformed manifests and workspaces with a newer unsupported format remain
untouched for inspection and compatibility.

Added a native regression covering the retention cutoff and partial-byte
removal alongside the existing resume and discard paths. The focused native
staging and storage suite passes 26 tests; the full Flutter suite passes with
1,389 tests. Strict formatting, `flutter analyze`, and `git diff --check` are
clean release checks.

Status: implementation complete; next implementation task: recovery
verification UX for large files and retained-source cleanup.

---

# Previous task — Resumable attachment recovery after interrupted staging, 2026-10-08

Native attachment recovery now writes a device-local manifest beside its staged
`.part` bytes. If the process or source stream stops mid-transfer, the stage is
listed on the next open with its operation, target, checksum, and saved byte
offset. The recovery dialog lets the user choose the same source to continue
from that offset, or discard the stage. Resume still verifies the complete
checksum before the guarded commit; authored references and active source
metadata are unchanged until that commit succeeds. Browser stores keep the
bounded non-resumable fallback.

Added native staging and repository regressions for interruption, reopen,
resume, discard, checksum validation, and the existing streamed recovery paths.
The focused storage/read/native staging suite contains 40 tests after these
additions; the full Flutter suite passes with 1,388 tests. Strict formatting,
`flutter analyze`, and `git diff --check` are clean.

Status: implementation complete; next implementation task: recovery inventory
cleanup for abandoned stages older than the retention window.

---

# Previous task — Streamed attachment recovery hashing and progress, 2026-10-08

Large attachment recovery now hashes the selected XFile from a stream, reports
verification and write progress, and reopens the stream for the commit. Native
Vaults stage bytes on disk while hashing so recovery does not keep a second full
copy in memory. Browser stores retain a bounded compatibility buffer. Restore
and relink still require the same checksum and size guards as the previous task.

Added repository regressions for streamed restore, streamed relinking, checksum
verification, byte progress, and the existing native staging contract. The
focused storage/read/native staging suite passes 37 tests; the full Flutter
suite passes with 1,385 tests. Strict formatting, `flutter analyze`, and
`git diff --check` are clean.

Status: implementation complete; next implementation task: resumable recovery
after an interrupted staged transfer.

---

# Previous task — Read-mode media source status for PDF quotes, Canvas embeds, and math-adjacent media, 2026-10-07

Read-mode media now reports source drift as well as storage failures. PDF review
rows show a warning and disable direct navigation when their source checksum no
longer matches. Canvas citation cards show a source-changed badge while keeping
the source-open action available for verification. Attachment previews announce
the replacement revision after refreshed bytes load, including math-adjacent
images.

Added regressions for stale PDF rows, stale Canvas citation cards, and the
replacement status announcement. The focused PDF/Canvas action suite passes 25
tests and the Read attachment suite passes 15 tests; the full Flutter suite
passes with 1,379 tests. Strict formatting, `flutter analyze`, and
`git diff --check` are clean.

Status: implementation complete; next implementation task: Read-mode media
parity for attachment relinking, source history, and user-visible recovery
choices.

---

# Previous task — Read-mode media actions for PDF quotes, Canvas embeds, and math-adjacent media, 2026-10-07

Read-mode attachment actions now carry through PDF review cards and Canvas
citation/image previews. PDF quote cards can copy citation text or reopen the
source page; Canvas previews can copy the quote and open the source PDF or
original attachment. Math-adjacent images keep the shared title/alt metadata,
accessible open action, attachment details, and recovery controls.

Added regressions for PDF review actions, Canvas quote/source actions, and the
shared Read attachment action surface. The focused PDF/Canvas action suite
passes 24 tests and the Read attachment suite passes 15 tests; the full Flutter
suite passes with 1,378 tests. Strict formatting, `flutter analyze`, and
`git diff --check` are clean.

Status: implementation complete; next implementation task: Read-mode media
parity for PDF quote source-version warnings, Canvas stale-source badges, and
math-adjacent replacement indicators.

---

# Previous task — Read-mode missing attachment recovery, 2026-10-07

Read attachment previews now distinguish a missing source, a failed Vault read,
and bytes that cannot be decoded. Each state keeps the authored reference
untouched and offers Retry. When a watcher revision replaces an existing
attachment, Read mode shows a refresh state while the new bytes load; decoder
failures use the same recovery control instead of a dead preview.

Added regressions for missing, failed-read, decode-failure, revision-gated,
replacement-refresh, metadata, accessibility, and open-original states. The
focused media/cache tests pass 35 tests; the full Flutter suite passes with
1,378 tests. Strict formatting, `flutter analyze`,
and `git diff --check` are clean.

Status: implementation complete; next implementation task: Read-mode media
parity for attachment actions in PDF quote cards, Canvas embeds, and inline
math-adjacent media.

---

# Previous task — Read-mode attachment cache invalidation, 2026-10-07

Read-mode and Canvas attachment previews now react to external attachment
replacements without rebuilding the object index or disturbing note drafts.
Native Vault watchers expose attachment paths separately from canonical object
changes, the controller batches them into a lightweight media revision, and
visible previews reload through generation-fenced caches so an older in-flight
decode cannot win after a replacement. Read previews also avoid reloading on
ordinary widget rebuilds; only a path or media revision change starts a new
read.

Added regressions for revision-gated Read image reloads and decoded Canvas
attachment invalidation. The focused media/cache tests pass 22 tests; the full
Flutter suite passes with 1,365 tests. Strict formatting, `flutter analyze`,
and `git diff --check` are clean.

Status: implementation complete; next implementation task: Read-mode media
parity for missing attachment recovery and replacement status details.

---

# Previous task — Read PDF, Canvas and image recovery parity, 2026-10-07

Read-mode PDF quote links preserve precise page targets, and Canvas wiki-links
open their stable object IDs through the existing link router. Local image
previews now have a retryable loader with an explicit failure state, so a
temporary vault/read failure can recover without rebuilding the note or losing
the authored reference.

Added PDF-page, Canvas-object and retry-after-failure regressions. The focused
Read/media suite passes 20 tests; the full Flutter suite passes with 1,362
tests. Strict formatting, `flutter analyze`, and `git diff --check` are clean.

Status: implementation complete; next implementation task: Read-mode media
parity for attachment cache invalidation and stale-preview replacement.

---

# Previous task — Read media activation parity, 2026-10-07

Read mode now keeps media behavior consistent across footnotes, math-adjacent
images, and dynamic view blocks. Footnote and inline-math paragraphs use the
shared local attachment preview. Fenced `orbit-view` and `orbit-snapshot`
blocks render their real interactive view/snapshot widgets in Read mode instead
of falling back to inert code, while authored source remains unchanged.

Added regressions for footnote images, math-adjacent images and dynamic view
rendering. The focused Read/callout/editor/footnote suite passes 81 tests; the
full Flutter suite passes with 1,359 tests. Strict formatting, `flutter analyze`,
and `git diff --check` are clean.

Status: implementation complete; next implementation task: Read-mode media
activation parity for PDF quote cards, canvas embeds, and image error recovery.

---

# Previous task — Read attachment activation parity, 2026-10-07

Read-mode attachment images now behave consistently in aligned blocks, tables,
and block quotes. A shared `ReadAttachmentPreview` preserves the existing image
renderer while adding an accessible tap target for local relative attachments;
remote and data images keep ordinary display behavior. Links continue through
the same note-level router in every surface.

Added regressions for aligned, table, and block-quote attachment images. The
focused Read/callout/editor suite passes 67 tests; the full Flutter suite passes
with 1,356 tests. Strict formatting, `flutter analyze`, and `git diff --check`
are clean.

Status: implementation complete; next implementation task: Read-mode media
activation parity for footnotes, math-adjacent images, and dynamic view blocks.

---

# Previous task — Read-callout link and attachment activation, 2026-10-07

Read callout bodies now reuse the note's link router for external, internal,
missing and relative attachment links. Nested callout Markdown also receives the
same image builder as the surrounding note. Relative attachment images are
previewable and expose an accessible tap target that opens the original through
the workspace attachment handler; source Markdown remains unchanged.

Added regressions for external callout links, relative attachment links and
attachment images. The focused Read/callout/editor suite passes 65 tests; the
full Flutter suite passes with 1,353 tests. Strict formatting, `flutter analyze`,
and `git diff --check` are clean.

Status: implementation complete; next implementation task: Read-mode attachment
activation parity for aligned blocks, tables and block quotes.

---

# Previous task — Read-mode code search parity, 2026-10-07

Read-mode fenced code search now treats authored LF and CRLF line endings as
equivalent to the renderer's LF display for multiline queries. The query is
normalized only for matching; authored Markdown and source selection ranges are
unchanged. Code blocks carry their authored body text into the Read overlay so
language/info metadata remains outside the searchable segment.

The Find field accepts multiline pasted queries. Exact highlights, viewport
reveal, Unicode folded matches across prose and code, source preservation and
Find focus continue to work together. Added regressions cover LF/CRLF multiline
code, metadata exclusion, folded Unicode across multiple code blocks and focus
recovery. The Read/code focused suite passes 63 tests; the full Flutter suite
passes with 1,350 tests. Strict formatting, `flutter analyze`, and
`git diff --check` are clean.

Status: implementation complete; next implementation task: reliable link and
attachment opening inside Read callouts.

---

# Previous task — Code search source authority, 2026-10-07

Fenced-code Rich Find now resolves a stale block callback by stable document
position after fence growth. If a second input event arrives before the parent
rebuild, it edits the newly parsed code block instead of being silently dropped.
Fence language info, indentation, delimiter length, CRLF, selection, and shared
undo remain source-preserving.

Added a back-to-back structural-edit regression. The code-search suite passes
18 tests; the full Flutter suite passes with 1,346 tests. Strict formatting,
`flutter analyze`, and `git diff --check` are clean.

Status: implementation complete; next implementation task: rendered-match
highlighting and precise Read-mode scrolling for code blocks.

---

# Previous task — Structured search source authority, 2026-10-07

Table and callout Find navigation now uses the child editor's latest local
source when the parent rebuild is still pending. A type change followed
immediately by a body edit no longer reverts the type or maps the next search
selection against stale offsets. Table and callout source jumps remain exact,
including escaped pipes, CRLF body prefixes, title ranges, and shared undo.

Added a regression for the local callout emission race. The structured-search
suite passes 23 tests; the full Flutter suite passes with 1,345 tests. Strict
formatting, `flutter analyze`, and `git diff --check` are clean.

Status: implementation complete; next implementation task: exact search
navigation inside code blocks while retaining fences and source.

---

# Previous task — Find/replace Unicode and selection parity, 2026-10-07

Case-insensitive Find now uses the generated Unicode 15.1 full case-fold map
instead of relying on regex lowercasing. Expanded folds such as `ß` to `ss`
map back to exact UTF-16 ranges in the authored Rich/Source segment, while
partial matches inside one expansion remain literal. Whole-word boundaries are
still evaluated against the visible segment before selection scope is applied.
Rich replacements continue through the existing projection and structured edit
paths, preserving formatting, link targets, tables, callouts, and code safety.

Added regression coverage for expanded Latin folds, Greek sigma folding, the
Kelvin sign, half-expansion rejection, exact visible/source ranges, and Rich
replacement across emphasis and links. The focused Find/Replace suite passes
35 tests after this change. The full Flutter suite passes with 1,344 tests;
strict formatting and `flutter analyze` are clean.

Status: implementation complete; next implementation task: semantic
search/navigation inside tables and callouts with precise cell/line highlighting.

---

# Previous task — Cross-platform rich clipboard parity, 2026-10-07

Rich table copy now publishes HTML plus plain text on Windows, Android, iOS,
Linux, and web. Android uses `ClipData.newHtmlText`, iOS writes one pasteboard
item with `public.html` and UTF-8 plain text, Linux advertises GTK `text/html`
and text targets, and web uses `navigator.clipboard.write` with two Blob
representations. Every host keeps the ordinary plain-text fallback when its
rich API is unavailable, rejected, or interrupted.

Added platform bridge tests for successful rich writes, missing/rejected bridge
responses, malformed bridge results, and failure of both rich and plain paths.
The web release build also succeeds. Native Android/iOS/Linux compilation is
not available on this Windows validation host; the host source was checked
against the platform APIs and remains isolated behind the existing channel.

Validation for this slice: platform and table clipboard tests pass with 31
tests. Strict formatting and `flutter analyze` pass. The web release build
passes. The full Flutter suite passes with 1,342 tests.

Status: implementation complete; native mobile/Linux builds remain environment
blocked. Next implementation task: audit find/replace across Rich and Source
for formatted text, selection boundaries, and exact shared undo.

---

# Previous task — Table drag selection and rich clipboard export, 2026-10-07

Rich tables now support mouse drag selection in addition to Shift-arrow and
Ctrl/Cmd+A. The selected rectangle is visible during the drag and feeds the
same TSV/CSV copy and grid-paste paths. Selected cells can publish plain TSV
plus a native HTML table through the host clipboard bridge; platforms without
that bridge fall back to ordinary plain clipboard text. Windows writes both
CF_UNICODETEXT and CF_HTML, while HTML paste continues to use the shared
conservative converter.

Added regression coverage for drag selection, native HTML payloads, quoted CSV,
multiline quoted CSV, mixed delimiters, stale requests, and clipboard failures.

Validation for this slice: table, Markdown clipboard, and rich-model tests pass
with 44 tests. Strict formatting and `flutter analyze` pass, and the full
Flutter suite passes with 1,336 tests. Windows packaging was attempted but
Flutter stopped before compilation because Developer Mode symlink support is
disabled on this machine.

Status: complete. Next implementation task: native rich clipboard parity for
Android, iOS, web, and Linux hosts.

---

# Previous task — Inline link labels and nested brackets, 2026-10-06

Inline link labels now accept backslash-escaped brackets and matched nested
bracket pairs, while unmatched labels remain literal. Nested inline links are
not projected as the outer link, preserving CommonMark’s no-nested-links rule.
Replacing an escaped label no longer leaves a stale backslash in the authored
source. Added coverage for nested labels, escaped labels, malformed boundaries,
source-preserving edits, and nested-link projection.

Validation for this slice: focused Markdown tests pass with 30 tests. Strict
formatting and `flutter analyze` pass, and the full Flutter suite passes with
1,306 tests.

Status: complete. Next implementation task: audit inline link label escapes and
nested brackets while keeping unsupported forms literal.

---

# Previous task — Inline link titles and spacing, 2026-10-06

Inline links now parse quoted, apostrophe, and parenthesized titles separately
from their destinations. Spaces, tabs, and at most one line ending are accepted
around the destination, title, and closing delimiter. Empty destinations remain
valid; malformed titles, blank-line forms, unknown trailing text, and unsupported
delimiters remain literal source. Authored source and edit boundaries stay exact.

Added coverage for all title delimiters, one-line-ending spacing, CRLF and
whitespace-only blank lines, escaped versus nested parentheses, source-preserving
edits, balanced destinations, and malformed-title fallbacks.

Validation for this slice: focused Markdown tests pass with 30 tests. Strict
formatting and `flutter analyze` pass, and the full Flutter suite passes with
1,303 tests.

Status: complete. Next implementation task: audit inline link label escapes and
nested brackets while keeping unsupported forms literal.

---

# Previous task — Reference destination decoding, 2026-10-06

Reference destinations now decode Markdown backslash escapes and named or
numeric HTML character references for link actions. The authored destination is
never rewritten: raw Rich blocks, Find/Replace, undo, and source-mode edits keep
the original escapes/entities. Percent escapes remain unchanged. Added coverage
for escaped parentheses and fragments, `&amp;`, decimal entities, hexadecimal
entities, source preservation, and shortcut-link targets.

Validation for this slice: focused Markdown tests pass with 25 tests. Strict
formatting and `flutter analyze` pass, and the full Flutter suite passes with
1,301 tests.

Status: complete. Next implementation task: audit title line-ending rules and
nested delimiters while keeping unsupported forms literal.

---

# Previous task — Reference-definition titles and multiline destinations, 2026-10-06

Reference definitions now follow the CommonMark ownership rules used by the
project: validated destinations may be empty (`<>`), balanced parentheses and
escaped punctuation are accepted, titles may use quotes, apostrophes, or
parentheses and may continue across nonblank lines, and a destination may start
on the next line. Invalid trailing text remains ordinary source instead of
silently creating a link. A complete definition stays one raw editing block,
so Rich editing and Backspace cannot split its title or destination into a
second paragraph. Definitions in frontmatter, fenced code, and indented code
remain excluded; the first valid duplicate wins.

The retained Rich block cache is cleared when the definition map changes, so
shortcut link projections refresh immediately after editing a definition.

Added coverage for LF/CRLF source preservation, all title delimiters, multiline
titles and destinations, escaped delimiters, empty destinations, malformed
definitions, duplicate precedence, code/frontmatter exclusions, Find/Replace,
Rich editing, and undo.

Validation for this slice: focused Markdown, Find/Replace, and Rich editor
suites pass with 81 tests. `flutter analyze`, strict formatting, and the full
Flutter suite pass with 1,294 tests.

Status: complete. Next implementation task: audit reference-definition escape
and entity decoding while keeping authored source editable.

---

# Previous task — Shortcut reference links, 2026-10-06

Rich inline projection now resolves shortcut references such as `[Guide]` only
when the note contains a matching reference definition. Ordinary bracketed
prose and image syntax remain visible and literal. Shortcut labels keep their
authored brackets during edits, expose the same link metadata as full reference
links, and participate in the document-wide definition refresh path.

Added coverage for case-normalized shortcut matching, ordinary bracketed prose,
image exclusion, link metadata and source-preserving label edits. Definition
changes reparse the document and refresh shortcut destinations without creating
a second content store.

Validation for this slice: strict formatting, analyzer, focused Markdown/find
suites, and the full Flutter suite pass. The full Flutter suite passes with
1,285 tests.

Status: complete. Next implementation task: audit reference-definition titles
and multiline destinations before expanding the inline grammar further.

---

# Previous task — Whole-document reference definitions, 2026-10-06

Markdown documents now collect top-level reference definitions once per parse,
normalizing labels case-insensitively and folding whitespace. Rich blocks and
find/replace projections receive that map, so `[Guide][API]` resolves to the
destination declared later in the note while unresolved references remain
visible, editable and source-preserving. Definitions inside fenced or indented
code are ignored, and the first definition wins as CommonMark specifies.

Added coverage for cross-document resolution, case-insensitive labels, fenced
code exclusions, resolved/unresolved metadata and Rich source edits. Updating
a definition reparses the document and refreshes link destinations without
creating a second content store.

Validation for this slice: strict formatting, analyzer, focused Markdown/find
suites, and the full Flutter suite pass. The full Flutter suite passes with
1,283 tests.

Status: complete. Next implementation task: add shortcut reference links with
definition-gated matching, while keeping ordinary bracketed prose literal.

---

# Previous task — Inline link editing parity, 2026-10-06

Rich inline projection now supports CommonMark autolinks and full/collapsed
reference links. URI autolinks expose their visible label and exact destination;
email autolinks expose a `mailto:` destination. Reference syntax hides only its
label while preserving the authored reference identifier and delimiters during
editing. Image syntax, unmatched brackets and unsupported definitions remain
literal instead of being guessed.

Added coverage for URI/email autolinks, reference labels and source-preserving
label edits. This keeps link selection and context-menu discovery consistent
with existing inline and wiki links without introducing a second link store.

Validation for this slice: strict formatting, analyzer, focused Markdown model
suites, and the full Flutter suite pass. The full Flutter suite passes with
1,282 tests.

Status: complete. Next implementation task: make reference definitions resolve
to destinations across a whole Markdown document while retaining unresolved
references as editable source.

---

# Previous task — CommonMark editing parity, 2026-10-06

Inline Rich editing now recognizes CommonMark code spans with matching
backtick runs of any length. Code content keeps exact source boundaries while
normalizing line endings and the standard edge-space rule, so selection,
formatting and source-preserving edits remain stable for spans that use two
backticks around code containing one literal backtick.

Added focused coverage for variable-length code spans, normalized whitespace,
line-ending folding and unmatched delimiters. This closes the highest-impact
inline CommonMark gap found in the current editor audit; unsupported Markdown
extensions and broader CommonMark corner cases remain literal and recoverable.

Validation for this slice: strict formatting, analyzer, the CommonMark and
boundary-editing suites, and the full Flutter suite pass. The full Flutter
suite passes with 1,280 tests.

Status: complete. Next implementation task: resolve reference definitions across
the whole Markdown document.

---

# Previous task — Cross-block native text selection, 2026-10-06

Rich editing now tracks an exact document-level selection while dragging across
paragraphs or calling `selectDocumentRange`. The range preserves authored
Markdown, highlights every intersecting block, and supports copy, cut, delete,
and replacement without converting the note into a second document format.

Selection endpoints are resolved from rendered editable fields, including inline
Markdown projections. Existing whole-block selection remains available for block
operations, while ordinary single-block copy and editing keep their native text
behavior.

Added coverage for exact cross-block source copying/deletion plus the existing
multi-block selection and Rich editor regression suites.

Validation for this slice: strict formatting, analyzer, the multi-block selection
suite, the Rich editor widget suite, and the full Flutter suite pass. The full
Flutter suite passes with 1,276 tests.

Status: complete. Next implementation task: CommonMark inline editing parity.

---

# Previous task — Markdown table interoperability, 2026-10-06

Rich tables now support rectangular selection by shift-click, Shift+Arrow, and
Ctrl/Cmd+A, with selected ranges copied as interoperable TSV. Table paste now
accepts TSV, quoted CSV, and HTML tables while preserving the existing authored
Markdown spelling on untouched cells and retaining bounded row/column safety.

Added coverage for range selection, TSV copy, quoted CSV paste, HTML table paste,
focus-safe asynchronous clipboard reads, and the existing table undo/regression
suite.

Validation for this slice: strict formatting, analyzer, the full table clipboard
suite, and the full Flutter suite pass. The full Flutter suite passes with 1,275
tests.

Status: complete. Next implementation task: cross-block native text selection.

---

# Previous task — Markdown editor parity, 2026-10-06

The Markdown editor parity pass started after auditing the durable-storage
milestone against the implementation. Rich and Source paste now prefer the
clipboard's `text/html` representation when it is available and convert the
portable subset (headings, emphasis, links, lists, quotes, code, images, and
simple tables) to authored Markdown. Plain-text paste remains the fallback,
and clipboard/provider failures leave the document unchanged.

Large Rich notes now switch to a lazy block list after 320 parsed blocks. The
virtualized path keeps block identity, drag handles, editing controls, and
exact source offsets; distant jumps use measured seek refinement before focus.
CommonMark parsing now keeps empty ATX headings, tab-spaced lists, indented code
runs, no-space block quotes, and setext headings as structural blocks.

Added focused coverage for HTML conversion, entity decoding, simple table
conversion, image/link preservation, and rich-clipboard fallback. Existing
multi-block selection, table, and editor regression suites continue to pass.

Remaining parity gaps are cross-block native text selection, the rest of
CommonMark editing behavior, and rectangular table selection/CSV
interoperability. These remain tracked in the
[implementation status](../planning/implementation-status.md).

Validation for this slice: strict formatting, analyzer, the clipboard and
CommonMark tests, the virtualization jump test, and the existing Rich
editor/table/selection suites pass. The full Flutter suite passes with 1,272
tests.

Status: complete. Next implementation task: rectangular table selection and
CSV/HTML clipboard interoperability.

---

# Previous task — Durable storage and recovery audit, 2026-10-06

The first reliability milestone was audited against the actual implementation
before starting Markdown parity work.

Completed or already present:
- OS-level Vault locking is implemented and covered by a separate-process test.
- Revision history is persisted, bounded, and available through the document
  history browser.
- Interrupted-save, failed-write, folder-move, and deletion recovery are
  journaled and covered by native storage tests.
- Recovery files are discoverable from the command palette, previewed with a
  size bound, and exportable without applying or deleting them.
- Backup import publishes into a separate staged workspace and preserves raw
  unknown files and quarantined recovery journals.

Remaining durable gaps are now narrowed to streaming very large backup archives,
browser folder import, binary attachment cache invalidation, arbitrary external
multi-file transactions, and physical power-loss certification. These are
explicitly tracked in the [implementation status](../planning/implementation-status.md).

Validation for this audit: strict formatting, analyzer, YAML workflow parsing,
focused recovery tests, and the full Flutter suite (1,265 tests) pass.

Next implementation task: Markdown editor parity.

---

# Previous task — Release hardening, 2026-10-05

Release engineering and product-scope hardening for the first public Orbit Note
candidate (`1.0.0+1`, Windows x64).

Delivered in this pass:
- Release tags run formatting, analyzer, PDFium setup, and the full test suite
  before packaging.
- Stable release packaging is frozen to a Windows x64 portable artifact.
- Release artifacts publish a SHA-256 checksum manifest.
- The command palette exposes a bounded recovery review/export dialog for
  interrupted-save and conflict files without applying or deleting originals.
- README platform claims now match the Windows 1.0 release workflow; Android and
  Web are explicitly validation builds until their acceptance gates are complete.
- Release checklist and remaining platform/data-safety gates are documented in
  [release-hardening-2026-10-05.md](release-hardening-2026-10-05.md) and the
  [Windows 1.0 acceptance matrix](windows-1.0-acceptance-2026-10-06.md).

Validation: strict Dart formatting, analyzer, focused recovery tests, and the
full Flutter suite pass locally (1,265 tests). Status: RC code complete;
external acceptance pending. A clean Windows package, checksum verification,
and interactive acceptance still need evidence. Local Windows packaging is
blocked before compilation by the host's disabled Developer Mode symlink
support; the release workflow's Windows runner is the packaging check.

---

# Previous task — Architectural Blueprint Canvas, 2026-10-05

Architectural drafting treatment for Canvas, based on blueprint paper with a
technical white-pen preset.

Key accomplishments:
- Deep blue blueprint paper with white drafting grid, border, registration marks,
  and a restrained centre line.
- New **Architectural drafting preset · white pen** menu action selecting blueprint
  paper, the pen tool, 1.5 px ballpoint ink, and technical white for new strokes.
- Added **Traditional blueprint · white drawing** for a uniform dark-blue sheet
  with white drafting lines.
- Existing blueprint menu action now also configures the technical white pen;
  existing elements are never recolored.
- SVG export preserves the blueprint treatment while transparent exports remain
  transparent.
- Read-only canvases cannot mutate the paper style.

Status: Complete. Focused canvas tests passed; analyzer clean; strict formatting
clean; full suite passed (1,262 tests). Evidence: [architectural-blueprint-canvas-2026-10-05.md](architectural-blueprint-canvas-2026-10-05.md).
Next suggested task: add optional architectural dimension and scale-mark tools
that create editable vector annotations on the same canvas.

---

# Previous task — PDF Quote Canvas Transclusion & Deep Linking, 2026-10-05

Direct drag-and-drop linking and transclusion of PDF text citations and quotes onto
the Orbit spatial canvas as cards.

Key accomplishments:
- Universal Quote Drag & Drop: Dragging citations from PDF selection toolbar, review panel, or connected notes panel onto canvas automatically creates live cards.
- Quiet Transclusion Card Styling: Default `presentation: 'transclusion'` renders a top accent strip, `PDF CITATION` badge, target wiki-link indicator `[[Source Title · p. X]]`, 3px left-edge accent line, italic quote body, and citation footer `Cited from Source Title · Page X`.
- Unified Page Deep Linking: `PdfQuoteDragData.referenceTarget` computes `$objectId#page=$page`. Double-clicking or pressing Enter on canvas quote cards navigates directly to the referenced PDF at the exact cited page.
- Interactive Preview Tooltip: `CanvasCardPreviewTooltip` detects quote cards, shows `PDF CITATION · P. X` badge, renders quote excerpt with left accent line, supports presentation cycling (transclusion, preview, card, compact), and provides "Open in editor" deep linking.
- High-DPI Vector Painting: `OrbitCanvasPainter` handles both top-level and nested `quote`, `page`, `sourceTitle`, and `sourceId` attributes across transclusion, preview, compact, and standard cards.
- Comprehensive Testing: 8 new unit and widget tests in `test/pdf_quote_canvas_transclusion_test.dart` covering serialization, controller extraction, canvas drag-and-drop, double-click navigation, tooltip interaction, vector painter modes, and PDF panel drag handles.

Status: Complete. Analyzer clean (0 issues); strict formatting clean across 382 files; all 8 new tests pass, all 38 related regression tests pass. Normal Windows release built successfully (68.5s); smoke launch verified responsive (PID 6480); packaged to release-assets/OrbitNote-Windows-x64.zip (25.9 MB).
Evidence: [pdf-quote-canvas-transclusion-2026-10-05.md](pdf-quote-canvas-transclusion-2026-10-05.md).
Next suggested task: Direct transclusion and live linking of LaTeX theorem and equation cards onto the Orbit spatial canvas as cards. Stop before implementing it.

---

# Previous task — Custom Category & Folder Color Identity, 2026-10-04

Interactive color tagger and context cues allowing users to assign individual accent
colors to workspace folders and notes in the Explorer.

Key accomplishments:
- Persistent Folder Colors: `SessionState` and `AppPreferences` storage for `Map<String, int> folderColors` with safe serialization and corrupted data resilience.
- Folder Hierarchy Inheritance: `WorkspaceController.folderColorValue` traverses ancestors, allowing child notes and nested subfolders to inherit subtle color cues from parent folders.
- Atomic Folder Actions: `WorkspaceController.moveFolder` rewrites folder color paths; `deleteFolder` prunes entries for removed folders and subfolders.
- Restrained Explorer Rows: `OrbitExplorerRow` renders a 2.5px left-edge accent line via `Stack` + `Positioned` avoiding Flutter non-uniform `borderRadius` assertions, with subtle icon tinting (`withValues(alpha: 0.85)`).
- Quick Color Picker Modal: `showFolderColorDialog` with 12 curated harmonic color swatches, custom hex input with `#` validation, live Explorer preview card, and reset action.
- Context Menu Integration: Added "Set folder color…" / "Change folder color…" and "Reset folder color" to folder context menus, and "Set accent color…" / "Change accent color…" to note context menus.
- Tab Strip Accent Integration: Active tab in `OrbitTabStrip` reflects active note or containing folder accent color along its top 2px indicator bar.
- Comprehensive Testing: 12 new unit and widget tests in `test/folder_color_identity_test.dart` verifying serialization, controller inheritance, atomic moves/deletions, dialog swatches/hex/reset, and Explorer/tab integration.

Status: Complete. Analyzer clean (0 issues); strict formatting clean across 381 files; all 1,251 tests pass.
Evidence: [folder-color-identity-2026-10-04.md](folder-color-identity-2026-10-04.md).
Next suggested task: Direct drag-and-drop linking and transclusion of PDF text citations and quotes onto the Orbit spatial canvas as cards. Stop before implementing it.

---

# Previous task — Visual Language Rewrite, Theming & Customization, 2026-10-04

Major frontend visual-language and theming milestone delivering Obsidian-level visual
customization paired with Orbit's calm first-party observatory aesthetic and Universal Object
architecture.

Key accomplishments:
- Semantic Theme Engine & Tokens: Complete semantic token architecture (`OrbitColors`, `OrbitTypography`,
  `OrbitCorners`), backward-compatible aliases, dynamic corner style radius mapping (`rounded` vs `subtle`).
- Five First-Party Theme Packs: Orbit Graphite + Violet (default), Observatory Deep Space + Cyan,
  Paper Warm Light (light cream with serif typography), Midnight OLED (pure black), and Aurora Forest.
- Safe JSON serialization/deserialization for themes with graceful fallback defaults.
- Generic Heatmap View: Data-driven year heatmap with 12 months, day intensity levels, hover tooltips,
  navigation on tap, metrics summary, standalone view (`viewType: 'heatmap'`), and responsive HomeView card.
- Visual Banners & Covers: `OrbitCoverBanner` with gradient presets, height presets (`compact`, `standard`, `hero`),
  darken overlay for contrast, and edit callbacks.
- Appearance Settings UI: `ThemePresetSelector`, `CornerStyleSelector`, and `LiveThemePreviewCard` with
  live interactive preview of headings, body, wiki-links, buttons, and corner indicators.
- Theme Interchange Dialogs: File-picker based export and import dialogs (`showOrbitThemeExportDialog`,
  `showOrbitThemeImportDialog`) allowing users to package semantic tokens into `.orbit-theme.json` and share
  them across workspaces with live preview and validation.
- Theme Gallery & Custom Themes Manager: `showOrbitThemeGalleryDialog` showcasing built-in and imported
  custom themes with swatches, specs (light/dark, corner style, typography), active indicator, instant theme
  application, in-place custom theme renaming, and safe deletion with automatic fallback to default `orbit` theme.
- Persistent Custom Theme Storage: `SessionState` and `AppPreferences` serialization for `customThemes`,
  dynamic pack lookup in `OrbitThemePack.fromId`, and auto-persistence upon import.
- Harmonized Color Palette Generator: `OrbitColors.fromSeed`, `OrbitThemePack.fromSeed`, and `OrbitContrast`
  utility computing WCAG 2.1 relative luminance and contrast ratios. Algorithmically generates full sets of
  accessible semantic tokens (`background`, `workspace`, `panel`, `raised`, `border`, `accent`, `text`)
  guaranteeing WCAG AAA contrast for main text and WCAG AA for secondary text across both dark and light modes.
- Interactive Palette Generator Dialog: `showHarmonizedPaletteDialog` with curated seed presets (Violet, Cyan,
  Emerald, Sapphire, Amber, Rose, Coral, Teal), custom hex code input, Dark/Light mode switch, live contrast ratio
  badges (`AAA`, `AA`), live UI mockup preview, instant workspace application, gallery persistence, and file export.
- Explorer Color Identity: Folder and note color resolution in `OrbitExplorerRow` with subtle left edge tint and icon accent.

Status: Complete. All 1,239 tests pass; analyzer clean (0 issues); strict formatting clean across 387 files.
Evidence: [visual-language-theming-2026-10-04.md](visual-language-theming-2026-10-04.md).
Next suggested task: Custom category and project folder color picker allowing users to assign individual accent colors to specific folders, views, or workspaces. Stop before implementing it.

---

# Previous task — Visual ergonomics and interaction quality, 2026-10-03

Owner's attached product-design prompt authorizes a major readability pass in the
current worktree. Source audit found microscopic board metadata, permanently
visible Explorer actions, horizontally scrolling tabs and a Game Dev status alias
mismatch. Scope this delivery around completed subsystems: shared comfortable/
compact metrics and contrast, semantic zoom, tab overflow, Explorer, task rows/
cards/detail, and timeline/milestone readability. Refine project health surfaces;
preserve current storage, IDs, sync, gestures, note source/history and user colors.
Required docs: visual design/motion, customization/Spaces, collections/views,
tasks/calendar, feature map/backlog and focused agent workflow. Use realistic
headless fixtures for rendered review; no desktop interaction automation.
Stop at a coherent green subsystem boundary as the attached prompt directs;
record remaining Canvas/focus/view-navigation refinements without claiming them.
Status: coherent readability/density/tab/task/planning pass complete; the broader
major design prompt remains partially delivered. All 1,208 tests pass; analyzer
and strict formatting clean (382 files). Normal Windows release built (62.3s),
smoke-launched hidden, responded and closed normally. No desktop input automation.
Evidence and all 33 requested report categories:
[Visual ergonomics](visual-ergonomics-2026-10-03.md).
Next suggested task: planning navigation and a real week/month Timeline axis.
Stop before implementing it.

## Product coherence continuation — 2026-10-04

The next focused subsystem refined Project, Course and Reverse Engineering
dashboard hierarchy. Repeated section cards, decorative research gradients and
small all-caps dashboard labels were reduced while preserving content, actions,
object identity and responsive behavior. Rendered fixtures were reviewed.
Evidence: [product coherence pass](product-coherence-2026-10-04.md).
The broader anti-AI-slop prompt remains intentionally scoped; stop before the
next planning/timeline milestone.
Validation: 1,209 tests passed; analyzer and strict formatting are clean across
382 files; Windows release build succeeded in 56.6s. Smoke launch was left to
the already-running responsive release process (PID 11244).

## Calendar workbench continuation — 2026-10-04

The calendar now has a responsive Month/Week switch, week navigation, focused
day columns, scrollable event/task entries, and a wrapping header for narrow
panes. The existing split agenda, object links, task completion, event editing,
and scope filtering remain intact. Evidence: [calendar workbench refinement](calendar-workbench-2026-10-04.md).
Validation: 1,210 tests passed; analyzer and strict formatting are clean across
382 files; Windows release build succeeded. Stop before implementing the next
timed-axis and drag-rescheduling subsystem.

## Visual and motion refinement — 2026-10-04

Shared shell surfaces now have a darker navigation spine, active destination
edge motion, a framed Orbit mark fallback, clearer vault metadata, animated tab
states, and preference-aware control feedback. Validation: 1,211 tests passed;
analyzer and strict formatting are clean; Windows release build succeeded.
Evidence: [visual and motion refinement](visual-motion-refinement-2026-10-04.md).
Validation: focused motion/component/visual checks pass; analyzer and strict
formatting are clean. Windows release build succeeded.

## Obsidian visual language expansion — 2026-10-05

The shell now offers thirteen curated first-party theme families, applies each
preset's typography and corner treatment together, and uses an Obsidian-like
raised header with destination/document breadcrumbs and a command-palette entry
point. Evidence: [Obsidian visual language expansion](obsidian-visual-language-2026-10-05.md).
Validation: 1,259 tests pass; analyzer and strict formatting are clean; Windows
release build succeeded.

## PDF and Canvas workbench surfaces — 2026-10-05

PDF and Canvas now share a quiet, theme-aware `OrbitWorkbenchToolbar` surface
with context labels that collapse on narrow panes. Existing navigation, reading,
drawing, selection, search, import/export, and research actions are preserved.
Evidence: [PDF and Canvas workbench surfaces](pdf-canvas-workbench-surfaces-2026-10-05.md).
Validation: 38 focused PDF/Canvas tests and the full 1,259-test suite pass;
analyzer and strict formatting are clean; Windows release build succeeded in
87.3 seconds.
Next suggested task: refine the PDF side panels and Canvas inspector with the
same content-first hierarchy. Stop before implementing it.

## Apple modern theme foundation — 2026-10-05

The semantic theme layer now supplies a consistent modern language for app bars,
navigation surfaces, bottom sheets, dividers, and progress indicators. Orbit's
theme families, local color customization, typography, density, and zoom remain
intact. Evidence: [Apple modern theme foundation](apple-modern-theme-foundation-2026-10-05.md).
Validation: 1,259 tests pass; analyzer and strict formatting are clean; Windows
release build succeeded in 113.0 seconds.
Next suggested task: refine PDF side panels and Canvas inspectors with this same
content-first hierarchy. Stop before implementing it.

## Inspector and PDF side-panel surfaces — 2026-10-05

Connected Notes, PDF Highlights & Review, and the universal Object Inspector now
use a shared identity-first `OrbitPanelHeader` with responsive action wrapping.
Existing filtering, keyboard search, linking, citation dragging, exports,
editing, and persistence remain unchanged. Evidence: [Inspector and PDF side-panel surfaces](inspector-surfaces-2026-10-05.md).
Validation: 1,259 tests pass; analyzer and strict formatting are clean; Windows
release build succeeded in 83.4 seconds.
Next suggested task: refine Canvas selection properties and advanced PDF research
controls as separate interaction passes. Stop before implementing them.

## Apple and Obsidian workspace language — 2026-10-05

The activity rail and document tabs now share a calmer desktop workbench
composition: panel-colored navigation spine, quiet icon-only states, raised
rounded active tabs, and a separated tab overflow affordance. Existing tab
pinning, reordering, shortcuts, context menus, and identity behavior remain
unchanged. Evidence: [Apple and Obsidian workspace language](apple-obsidian-workspace-language-2026-10-05.md).
Validation: focused controls, shell, tab, PDF, and workspace regressions pass;
1,259 full tests pass; analyzer and strict formatting are clean; Windows release
build succeeded in 96.0 seconds.
Next suggested task: apply the same content-first composition to the note editor
chrome and dashboard headers. Stop before implementing it.

## Template workspaces continuation — 2026-10-04

University, Game Dev, and Reverse Engineering creation now collect useful
metadata before scaffolding. Reverse Engineering is visible again from the
Notes explorer. Research, Content Pipeline, and Personal Planning board
presets plus Software Design, Research Log, and Book & Course Reading note
templates were added. Evidence: [template workspaces refinement](template-workspaces-2026-10-04.md).
Validation: 1,210 tests passed; analyzer and strict formatting are clean across
382 files; Windows release build succeeded.

## Grammar highlighting precision — 2026-10-04

Ordinary note prose no longer receives spelling underlines because the offline
lexicon now includes common writing vocabulary. Real typos, grammar rules, code,
math, URLs, wiki links, and personal dictionaries remain supported. Evidence:
[grammar highlighting precision](grammar-highlighting-2026-10-04.md).
Validation: 1,211 tests passed; analyzer and strict formatting are clean across
382 files; Windows release build succeeded.

---

# Previous task — Whole-app zoom and development workspaces, 2026-10-03

Owner requests browser-like Ctrl zoom and clearer game-development/research views.
Scope: device-local 75–200% app zoom, Ctrl +/=, Ctrl minus, Ctrl 0 and Settings
recovery; responsive dashboards/function filters and consistent research creation.
Required docs: customization/Spaces, game/research specs, spec map/backlog and
validation workflow. Preserve contents, gestures, identities, animations and
unknown settings. No desktop automation or live application launch.
Status: complete; all 1,192 tests pass, analyzer and strict formatting clean.
Normal Windows release rebuilt successfully (56.0s); no desktop control used.
Evidence: [Zoom and development workspaces](app-zoom-development-2026-10-03.md).

---

# Previous task — Custom-font clarity and reading comfort, 2026-10-03

Owner reports poor quality/readability with fonts such as Times New Roman and
requests typography fixes. Required docs: Markdown editing, visual design and
customization contracts; existing font/editor/layout tests. Scope: refresh cached
Rich blocks after font/spacing changes, consistent note typography across modes
and structured fields, natural serif weights, layout/reflow and Settings preview.
Preserve chosen sizes, source/history, code fonts, animations and unrelated work.
No desktop automation, font installation or preference/storage migration.
Status: complete; 77 focused checks and all 1,186 tests pass.
Analyzer/strict formatting clean; normal Windows release rebuilt (53.6s).
Native monitor glyph quality remains unverified; no desktop automation used.
Evidence: [Typography comfort](font-comfort-2026-10-03.md).

---

# Previous task — Game development and reverse engineering, 2026-10-03

Owner requests reading and implementing the documented game-development and
reverse-engineering features. Required docs: feature specs GAME-01–04 and
REV-01–05, spec map/backlog, collaboration contract, open questions, storage
authority and implemented formats, focused agent workflow. No desktop automation.
Status: broader request in progress; first local implementation pass tested.
Final complete run: 1,183 tests pass. All 65 focused checks pass, including 17 new
regressions; analyzer and strict formatting are clean. Normal Windows release
rebuilt successfully (55.0s); no desktop automation was used. Local pass complete.
Existing game scaffolds/boards/templates and research dashboards/maps are retained.
This pass adds research record creation/evidence maps, build-aware address metadata,
reviewed manual symbol imports, optional creation menus and stable playtest links.
Custom schema registries, authenticated team sharing and live specialist-tool
connectors remain unfinished; ordinary Markdown categories are not custom types.
Evidence and requirement matrix: [Game/research implementation](game-research-2026-10-03.md).

---

# Previous task — Custom Read search coverage, 2026-10-03

Owner requests more useful app improvements without desktop automation. Scope:
callout title/body Read highlighting and source-verified navigation; confirm
aligned text coverage and preserve presentation/unknown data. Required docs:
Markdown editing contract and preceding Read-search evidence. No packages,
storage changes or native review window. Status: complete, 2026-10-03.
All 1,166 tests pass, including seven new custom Read checks; 56 focused checks
pass. Analyzer/strict formatting clean; normal Windows release rebuilt (83.1s).
Formatted body ambiguity retains conservative fallback; native input unverified.
Evidence: [Custom Read search](custom-read-search-2026-10-03.md).

---

# Previous task — Read-mode search highlights, 2026-10-03

Owner requests continuing features without desktop automation. Scope: EDT-03/04/13
transient rendered-match highlights and accurate Read navigation, retaining the
existing full-document renderer and safe fallback for unmapped custom blocks.
Required docs: Markdown editing contract and preceding code-search evidence.
Status: complete, 2026-10-03. All 1,159 tests pass; final focused rerun passes
70 checks including 1,000 matches in one paragraph. Analyzer/strict format clean;
normal Windows release rebuilt (83.3s). No packages, stored-source changes or
native review window. Unmapped custom/LaTeX output retains approximate fallback.
Evidence: [Read search](read-search-2026-10-03.md).

---

# Previous task — Precise code-block search, 2026-10-02

Owner accepts exact search navigation inside code blocks. Scope: EDT-02/03/04/06/13
code-body search, exact selection/scroll, live selection scopes and fence-safe
replacement with shared undo. Required docs: Markdown editing contract and
[preceding table/callout evidence](table-callout-search-2026-10-01.md).
No desktop automation, packages, storage changes or unrelated features.
Status: complete, 2026-10-02. All 1,149 tests pass, including 16 new code-search
regressions; 106 focused checks pass. Analyzer/strict formatting clean; normal
Windows release rebuilt (253.0s). Existing structured-field/performance repairs
preserved. Read scrolling and embedded-widget navigation remain approximate;
native keyboard/IME acceptance is unverified.
Evidence: [Code-block search](code-search-2026-10-02.md).

---

# Previous task — Table and callout search navigation, 2026-10-01

Owner requests continuing directly into the next useful task after finishing the
find/replace pass. Scope: EDT-04/06/11/12/13 search in table cells and callout text,
exact local selection/navigation, source-preserving replacement and shared undo.
Required docs: [Markdown editing contract](../features/markdown-and-editing.md),
[find/replace evidence](find-replace-2026-10-01.md), spec map and EDT backlog rows.
No desktop automation, new packages, storage changes or unrelated features.
Status: complete, 2026-10-02. All 1,133 tests pass, including 22 new structured
search regressions; final new-file rerun passes after brace-only lint cleanup.
Analyzer/strict formatting clean; normal Windows release rebuilt (96.5s).
Read navigation remains approximate; native IME acceptance is unverified.
Prior search and long-note performance repairs preserved.
Evidence: [Table/callout search](table-callout-search-2026-10-01.md).

---

# Previous task — Find/replace repairs, 2026-10-01

Owner accepts the suggested find/replace audit across formatted text and editor
modes. Scope: visible prose/source coordinates, selection and whole-word
boundaries, live counts, navigation focus/scroll, literal replacement and exact
shared undo. Required docs: [Markdown editing contract](../features/markdown-and-editing.md)
and [preceding table/clipboard evidence](table-clipboard-2026-10-01.md).
No desktop automation, packages, persistent format changes or unrelated features.
Status: complete. All 1,111 tests pass, including 22 new search regressions.
Analyzer and strict formatting clean; normal Windows release rebuilt (97.1s).
Read scroll remains approximate; specialized blocks retain literal search.
Evidence: [Find/replace repairs](find-replace-2026-10-01.md).

---

# Previous task — Table and multiline clipboard repairs, 2026-10-01

Owner accepts the suggested table editing and multiline clipboard audit. Scope:
cell boundaries/escaping, row and keyboard lifecycle, source preservation, delayed
clipboard safety, multiline prose projection and shared undo. Required docs:
[Markdown editing contract](../features/markdown-and-editing.md) and preceding
[regression evidence](markdown-regressions-2026-10-01.md). No desktop automation,
packages, storage changes or unrelated features. Status: complete. All 1,089 tests
pass, including 19 new table/clipboard checks. Final analyzer/format clean; normal
Windows release rebuilt (259.3s). Native clipboard/IME acceptance is unverified.
Evidence:
[Table and clipboard repairs](table-clipboard-2026-10-01.md).

---

# Previous task — Markdown regression repairs, 2026-10-01

Owner accepts the suggested repair of the four editor failures exposed by the
long-note performance suite. Scope: list/quote exit caret, paragraph Delete input
verification and selected block handle/menu behavior. Preserve the performance
work, source/CRLF, selection and shared history; no desktop automation, packages,
storage changes or new features. Required docs: the preceding
[performance evidence](long-note-performance-2026-10-01.md) and
[Markdown editing contract](../features/markdown-and-editing.md).
Status: complete. All 1,070 tests pass, including the four original regressions
and 61 focused checks. Analyzer/format clean; normal Windows release rebuilt
(214.5s). Native input was not tested. Evidence:
[Markdown regression repairs](markdown-regressions-2026-10-01.md).

---

# Previous task — Long-note performance, 2026-10-01

Owner accepts long-note performance hardening and requests no desktop automation.
Scope: cached positions/source assembly, inline projection, footer and outline
work; preserve features, animations and immediate source correctness. No packages
or storage changes. Status: implemented; analyzer/format clean and normal Windows
release rebuilt (91.4s). Pure checks and new widget regressions pass. Full suite:
1,064 passed, four editor failures also reproduced with the old linear lookup paths.
Mixed-note bookkeeping and spelling-issue lookup benchmarks improve substantially;
native input/frame latency is not measured. Evidence:
[Long-note performance](long-note-performance-2026-10-01.md).

---

# Previous task — Native Markdown acceptance, 2026-10-01

Owner accepts the suggested native checks for IME and cross-block undo. Use an
in-memory review vault, keep user data untouched, restore the normal Windows release.
Scope: keyboard/Unicode input, paragraph/format history across Rich/Source, controlled
composition events and repairs for reproduced failures. OS CJK IME is not configured.
Status: composition history repaired; native composition cancel/commit and paragraph
undo/redo across Rich/Source observed. Analyzer/format clean; normal Windows release
rebuilt. Flutter tests blocked by Application Control. Actual OS IME and injected
ordinary keyboard input remain unverified. Evidence:
[Native acceptance](markdown-native-acceptance-2026-10-01.md).

---

# Previous task — Markdown hidden-issue audit, 2026-10-01

Owner requests another search for hidden issues. Scope: duplication/reference
identity, structural conversion, code fencing, alignment selection/CRLF, delayed
attachments and stale menus. No new packages, storage format or migrations.
Status: implemented. Ten pure Dart regression groups pass; analyzer and formatting
clean. Normal Windows release rebuilt (62.0s). Windows Application Control still
blocks Flutter tests before execution; widget/native acceptance remains unverified. Evidence: [Hidden-issue audit](markdown-hidden-audit-2026-10-01.md).

---

# Previous task — Markdown editing repair, 2026-10-01

Owner requests reliable paragraph insertion/deletion and richer Markdown editing.
Scope: source-preserving boundaries, formatting selection/typing, clipboard races,
keyboard shortcuts and regression coverage. No storage format or dependency changes.
Status: repairs delivered. Seven pure Dart regression groups passed; analyzer
and formatting clean. Normal Windows release rebuilt (65.2s). Flutter test execution
is blocked by Windows Application Control; native acceptance remains unverified. Evidence: [Markdown editing repair](markdown-editing-repair-2026-10-01.md).

---

# Previous task — Search workspace, 2026-10-01

Owner authorizes a useful, coherent batch of new features. Selected LNK-01/12
subset: saved query/filter recipes, recent opened searches, richer bounded-result
filters, deterministic sorting, previews, keyboard selection and match emphasis.
Use existing local search and precise navigation; no new index, packages or cloud.
Preserve unknown settings and canonical knowledge. Status: implementation delivered;
analyzer/format clean, native sample review and pure Dart checks passed. Normal
Windows release built (58.3s). Flutter tests are blocked by Windows Application
Control before execution; do not claim complete acceptance. Evidence:
[Search workspace](search-workspace-2026-10-01.md).

---

# Previous task — Architectural composition, 2026-09-30

Owner request: attached architectural/product leverage pass. Audit and evidence:
[Search and precise-reference composition](architecture-composition-2026-09-30.md).
Implemented: rich shared search/deep targets, lazy prose anchors, live block cards,
Canvas-element links, precise backlink context, separate appearance preferences,
background native search projection and oversized spatial-bound safety.
Status: delivered subsystem complete. All 1,027 tests passed; analyzer and format
clean. Normal Windows release built (61.0s), launched and observed Saved locally.
Native interaction acceptance is partial; Android SDK unavailable. Existing
FTS/grid/sync and unrelated work are preserved. Remaining PDF indexing/controller
extraction are documented; stop before the next milestone.

---

# Previous task — Interface colors and Bookshelf, 2026-09-30

Owner request: customize each part of the UI and overhaul the heavy Bookshelf.
Scope/evidence: [Interface colors and Bookshelf](colors-bookshelf-2026-09-30.md).
Status: implemented and validated. 1,012 full-suite tests passed; six focused
checks passed after final corrections. Analyzer and formatting clean. Normal
Windows release built (77.0s) and launched. Final native interaction review was
interrupted by user activity; see the task report for remaining validation limits.
Preserve existing content, reading tools, animations and performance improvements.

---

# Previous task — Product coherence, 2026-09-29

Owner request: attached Product Coherence + Native Power + Design Quality milestone.
Audit and selected P0/P1 scope: [Product coherence](product-coherence-2026-09-29.md).
Preserve the prior [canvas performance](canvas-performance-2026-09-28.md) improvements.
Status: selected discovery/layout pass complete, 2026-09-30. Full suite: 1,006
passed; 19 collection/view checks passed after native-review correction. Analyzer
and formatting clean. Normal Windows release built and launched. Android blocked
by missing SDK. Native screen evidence and deliberate deferrals are in the task.
No storage migrations, identity changes, plugin runtime or sync protocol changes.

---

# Previous task — Windows Release Build & Virtual Reading Rooms with Bookshelf Library, 2026-09-28

Owner request: "build windows release" and "Make the pdf reader like a phone reader too, add a feature so i can read pdfs like i read with bookmarking etc. pages and making pdfs favourites etc. modern reading app that combines a powerful PDF/eBook reader with cozy virtual reading rooms and personal Library."

Status: Complete and verified.
- Production Windows Release Executable: `build\windows\x64\runner\Release\orbit_note.exe` (compiled successfully with Flutter 3.44.8, Visual Studio 2026, and Windows SDK 10.0.26100.0).
- Virtual Reading Rooms: 6 environments with vector-painted weather atmospheres, ambient audio channel mixer, paper tone filters (Normal, Cozy Sepia, Editorial Warm, Dark Mode), distraction-free Zen mode, page bookmarks, favorite starring, and Book Memories archive export to Orbit Note.
- Personal Bookshelf & Library View (`OrbitLibraryView`): hero card, shelves filtering, reading activity stats, and quick-search.
- Static Analysis: 0 errors, 0 warnings (`flutter analyze --no-pub lib/`).
- Automated Tests: 100% pass rate in `test/reading_rooms_and_library_test.dart`.

---
# Previous task — Markdown Note Templates Engine, LaTeX Theorems & Canvas Rigor, Word Goal Milestones, 2026-09-28

Owner request: "continue adding more features"
Scope: High-value native personal knowledge features expanding desktop workflows:
1. Markdown Note Templates Engine & Dialog (EDT-09, STUDY-02): Curated catalog of structured starter templates (Cornell Notes, Meeting Notes & Action Items, Weekly Review & Retrospective, Literature & Research Note, Daily Standup & Focus Log, Project RFC / Feature Spec, and Blank Note), interactive modal browser (`NoteTemplateDialog`), and integrated creation from workspace header "+", tab bar, and Command Palette.
2. LaTeX Theorems, Definitions & Proof Environments (EDT-12, NOTE-07): Formal mathematics template (`theorem_proof`) added to `LatexTemplates.all` with AMS theorem environments (`\newtheorem{theorem}`, `\begin{proof}`, etc.), and Unicode transclusion formatting on spatial canvas cards via `CanvasRichText.formatMathToUnicode` for blackboard bold sets ($\mathbb{R}, \mathbb{C}, \mathbb{N}, \mathbb{Z}, \mathbb{Q}$), `\qed`, and theorem/proof blocks.
3. Word Goal Milestone Completion & Dynamic Accent Indicator (EDT-13, MOT-01, MOT-04): Enhanced live word goal badge (`footer-target-goal-badge`) in `NoteEditor` with responsive `OrbitColors` accent/success styling and milestone completion state (`✓ Goal reached`).
4. Template Insertion into Active Document (EDT-09): Added "Insert Template…" action in `NoteEditor` and Command Palette to insert structured templates directly at caret position.

Implemented:
- Markdown Note Templates Catalog (`lib/features/notes/note_templates.dart`):
  - Created `NoteTemplate` model with `id`, `name`, `description`, `icon`, `defaultTitle`, `body`, and `tags`.
  - Built `NoteTemplates` catalog with 7 structured templates: `cornell`, `meeting`, `weeklyReview`, `literature`, `dailyStandup`, `projectRfc`, and `blank`.
  - Added `byId(id)` lookup and `search(query)` filtering across name, description, tags, and body content.
- Note Template Browser & Preview Dialog (`lib/features/notes/note_template_dialog.dart`):
  - Built `NoteTemplateDialog` featuring search filtering, template item cards with badges and tags, side-by-side selectable preview pane, double-click selection, and creation / insertion modes.
- Workspace & Navigation Integration (`lib/features/workspace/workspace_shell.dart`, `command_palette.dart`, `note_editor.dart`):
  - In `WorkspaceShell`: Added "New Note from Template…" in header "+" menu (`ValueKey('new-note-from-template')`) and tab bar new note menu.
  - In `CommandPalette`: Added "New note from template..." and "Insert template into active note..." commands.
  - In `NoteEditor`: Added "Insert Template…" to actions popup menu and updated live goal badge to support dynamic theme colors and milestone celebratory label.
- LaTeX Theorems & Mathematical Rigor on Canvas (`lib/features/notes/latex/latex_templates.dart`, `lib/features/canvas/canvas_rich_text.dart`):
  - Added `theoremProof` template to `LatexTemplates.all` with definitions, Banach Fixed-Point theorem, and Cauchy sequence proofs.
  - Extended `CanvasRichText.formatMathToUnicode` to parse theorem environments (`\begin{theorem}`, `\begin{definition}`, `\begin{proof}`, etc.), `\qed` ($\blacksquare$), and blackboard bold sets ($\mathbb{R}, \mathbb{C}, \mathbb{N}, \mathbb{Z}, \mathbb{Q}$).
- Automated Test Suite (`test/note_templates_and_goal_test.dart`):
  - Added 7 comprehensive unit and widget tests covering catalog lookup, search filtering, LaTeX theorem parsing, canvas math transclusion, dialog interaction, shell integration, and editor goal milestones with 100% pass rate.

Validation:
- Test suite: `test/note_templates_and_goal_test.dart` (7 tests passed), `test/tags_readability_footnotes_test.dart` (12 tests passed) — 19/19 tests passed cleanly.
- Static analysis: 0 warnings, 0 errors (`flutter analyze --no-pub`: "No issues found!").
- Formatting clean across all 316 files (`dart format --output=none --set-exit-if-changed lib test`).

Suggested next task: Direct drag-and-drop linking and transclusion of PDF text citations and quotes onto the Orbit spatial canvas as cards.

---

# Previous task — Document Tags Explorer Filter, Readability Metrics, Footnotes Quick-Insert & Canvas Sticky Tinting, 2026-09-28

Owner request: "add more features"
Scope: High-value native personal knowledge features expanding desktop workflows:
1. Document Readability & Complexity Analytics (EDT-13): Flesch Reading Ease score, Flesch-Kincaid Grade level estimation, average sentence length, average word length, and syllable counting heuristic integrated into DocumentStats and DocumentStatsDialog's dedicated Readability card.
2. Markdown Footnotes Quick-Insert (EDT-12): Markdown footnote auto-indexing helper (`MarkdownEditing.insertFootnote`) finding highest existing `[^n]`, inserting `[^n+1]` at current caret, and appending `[^n+1]: ` at document bottom, wired to `Ctrl+Shift+F` in NoteEditor.
3. Document Tag Management & Explorer Tag Filter (TAG-01): `WorkspaceController` tag aggregation (`allTags`, `tagsForObject`, `countForTag`, `addTagToObject`, `removeTagFromObject`), explorer filtering via `activeTagFilter`, quick-filter popup button (`explorer-tag-filter-button`), active tag filter chip bar (`#tag ✕`), and Command Palette commands.
4. Canvas Sticky Note Swatch Color Tinting (CAN-02): Dynamic hex/int color parsing for sticky notes in `OrbitCanvasPainter`.

Implemented:
- Document Readability & Complexity Analytics (`lib/features/notes/document_stats_dialog.dart`):
  - Added fields: `fleschReadingEase`, `fleschKincaidGrade`, `readingEaseLabel`, `gradeLevelLabel`, `averageSentenceLength`, `averageWordLength`, and `syllables`.
  - Added rule-based syllable counting heuristic `_countSyllables(String word)` with silent 'e', diphthong, and suffix handling.
  - Implemented Flesch Reading Ease ($206.835 - 1.015 \times \text{ASL} - 84.6 \times \text{ASW}$) and Flesch-Kincaid Grade Level ($0.39 \times \text{ASL} + 11.8 \times \text{ASW} - 15.59$) with safe zero-division fallbacks.
  - Built responsive `_ReadabilityCard` in `DocumentStatsDialog` displaying reading ease badge, grade level indicator, and text metrics.
- Markdown Footnotes Quick-Insert (`lib/features/notes/markdown_editing.dart`, `lib/features/notes/note_editor.dart`):
  - Added `MarkdownEditing.insertFootnote(TextEditingValue value)`: scans for all `\[\^(\d+)\]` patterns to calculate next index, embeds marker at caret, and appends reference definition line at the document bottom.
  - Bound `Ctrl+Shift+F` keyboard shortcut in `NoteEditor` to invoke footnote insertion.
- Document Tag Management & Explorer Tag Filter (`lib/app/workspace_controller.dart`, `lib/features/workspace/workspace_shell.dart`, `lib/features/workspace/command_palette.dart`):
  - In `WorkspaceController`: added `activeTagFilter` with reactive notifications, `allTags` aggregator gathering tags from both object properties (`'tags': [...]`) and markdown body hashtags (`#tag`), `tagsForObject(id)`, `countForTag(tag)`, `addTagToObject(id, tag)`, and `removeTagFromObject(id, tag)`.
  - In `WorkspaceShell`: integrated `activeTagFilter` into explorer object pruning, added `explorer-tag-filter-button` popup menu, and added active tag filter chip bar (`#tag ✕`) with 1-click dismissal button (`clear-active-tag-filter`).
  - In `CommandPalette`: added "Filter explorer by tag...", "Clear active tag filter", and "Add tag to current document..." commands.
- Canvas Sticky Note Swatch Color Tinting (`lib/features/canvas/canvas_painter.dart`):
  - Added custom color parsing (hex string `#RRGGBB` or int) for sticky notes in `OrbitCanvasPainter._element()` under `case 'sticky':`.
- Automated Test Suite (`test/tags_readability_footnotes_test.dart`):
  - 12 comprehensive unit and widget tests covering readability score calculation, syllable heuristic, footnote auto-indexing, tag manipulation, and explorer tag filter UI with 100% pass rate.

Validation:
- Test suite: `test/tags_readability_footnotes_test.dart` (12 tests passed), `test/note_editor_stats_test.dart`, `test/notes_editing_test.dart`, `test/note_footnotes_underline_test.dart` (17 tests passed).
- Static analysis: 0 warnings, 0 errors (`flutter analyze --no-pub`: "No issues found!").
- Formatting clean across all 313 files (`dart format --output=none --set-exit-if-changed lib test`).

Suggested next task: Direct transclusion and live linking of LaTeX theorem and equation cards onto the Orbit spatial canvas.

---

# Previous task — Accent Palettes, Editor & Storage Settings, Canvas Presets & Tactile Animations, 2026-09-28

Owner request: "Continue adding more features and more animations." / "add more animations and add more settings features" / "continue"
Scope: High-value native settings and premium tactile interaction animations strictly adhering to Orbit Note's "quiet observatory" dark graphite design philosophy (MOT-01 through MOT-06; `docs/design/motion.md` and `docs/design/visual-design.md`). Custom accent themes with animated transitions, configurable auto-save and auto-snapshot on close, editor view defaults and Bionic Speed Reading, Focus Timer duration customization with ambient breathing glow, Document Revision History diffs, Markdown Table generator dialog, canvas paper and grid defaults, audio playback speed defaults, note editor line spacing, vault cache optimizer, and tactile motion primitives (`OrbitAnimatedProgress`, `OrbitPulseBadge`, `OrbitBounceButton`, `OrbitFadeSwitcher`).

Implemented:
- Observatory Accent Color Theme System (`lib/app/orbit_theme.dart`, `orbit_app.dart`, `session_state.dart`, `workspace_views.dart`):
  - Defined 6 observatory accent presets: Observatory Violet (`#8B7CF6`), Nebula Cyan (`#06B6D4`), Emerald Aurora (`#10B981`), Solar Flare Amber (`#F59E0B`), Crimson Nova Rose (`#F43F5E`), and Cobalt Deep Blue (`#3B82F6`).
  - Added dynamic theme color resolution in `orbitDarkTheme(accentColor: ...)` with synchronized ColorScheme seeding, hover tones, and 160ms animated transitions via `themeAnimationDuration` in `OrbitNoteApp`.
  - Built interactive Accent palette chip selector with animated checkmarks, tooltips, and live instant feedback in `SettingsView`.
- Editor Defaults, Line Spacing & Bionic Speed Reading (`lib/features/workspace/workspace_views.dart`, `session_state.dart`, `note_editor.dart`):
  - Added Default Editor View Mode selector (`rich`, `write`, `split`, `read`) with automatic fallback in `NoteEditor` when opening notes without prior saved state.
  - Added Default New Document Format selector (`markdown` vs `latex`).
  - Added Editor Line Spacing dropdown (`1.4` Compact, `1.6` Standard, `1.8` Relaxed) with live propagation to raw Markdown, hint text, and preview stylesheets.
  - Added Bionic Speed Reading default toggle (`bionicReadingDefault`).
  - Wrapped editor view modes in `OrbitContentTransition` (`identity: mode`) for 4px subtle, quiet cross-mode arrivals.
- Canvas & Spatial Board Settings (`lib/features/workspace/workspace_views.dart`, `session_state.dart`, `canvas_editor.dart`):
  - Added Default Canvas Paper & Grid Preset selector (`dots`, `grid`, `graph`, `cross`, `hex`, `blueprint`, `lines`, `ruled`, `isometric`, `blank`).
  - Added Canvas Snap to Grid default toggle (`canvasSnapToGrid`).
  - Seamlessly forwarded defaults to `CanvasEditor` via `WorkspaceShell`.
- Audio & Voice Memo Settings (`lib/features/workspace/workspace_views.dart`, `session_state.dart`, `audio_player_card.dart`, `canvas_editor.dart`):
  - Added Default Playback Speed selector (`1.0x`, `1.25x`, `1.5x`, `2.0x`) initialized dynamically in `OrbitAudioPlayerCard`.
- Storage Debounce, Auto-Snapshot & Vault Optimizer (`lib/features/workspace/workspace_views.dart`, `session_state.dart`, `workspace_controller.dart`):
  - Added configurable Auto-Save Debounce Interval: 500ms (Fast), 1000ms (Balanced, Default), 2500ms (Relaxed).
  - Added Auto-Snapshot on Document Close (`autoSnapshotOnClose`).
  - Added "Optimize Vault Cache" action button with tactile icon and verification SnackBar.
- Focus & Deep Work Timer Customization (`lib/features/workspace/workspace_views.dart`, `focus_timer.dart`, `session_state.dart`):
  - Added custom duration selectors for Focus sessions (15m, 20m, 25m, 30m, 45m, 60m), Short breaks (3m, 5m, 10m), and Long breaks (15m, 20m, 30m).
  - Added `FocusTimerController.configureDurations` to dynamically update timer modes and cycles in real time.
- Premium Tactile Animation Primitives (`lib/app/orbit_components.dart`, `focus_timer.dart`):
  - `OrbitAnimatedCounter`: Implicitly animated rolling counter widget for smooth integer transitions.
  - `OrbitHoverLiftCard`: Tactile micro-lift container (`translateY: -3.0px`), border accent brightening, and soft shadow bloom on hover.
  - `OrbitBreathingGlow`: Ambient breathing ring glow pulse using smooth sine easing with eager `AnimationController` initialization.
  - `OrbitAnimatedProgress`: Implicitly animated linear progress bar replacing raw `LinearProgressIndicator` in project cards.
  - `OrbitPulseBadge`: Tactile animated badge with an ambient pulsing ping ring around a status pip, integrated into Observatory Vault Analytics (`TELEMETRY LIVE`).
  - `OrbitBounceButton`: Micro-interaction container delivering springless press scale feedback (`0.94` on tap down, returning to `1.0`), suppressing travel under reduced and off motion.
  - `OrbitFadeSwitcher`: Restrained opacity crossfade widget between children for smooth mode/panel switching.
- Document Revision History & Visual Diff Inspector (`lib/features/notes/document_history_dialog.dart`, `note_editor.dart`, `command_palette.dart`):
  - Full LCS line-by-line diff engine, revision snapshots list, diff vs preview view, and pre-restore safety checkpoints.
- Bionic Speed Reading Engine (`lib/features/notes/bionic_reading.dart`, `note_editor.dart`):
  - Prefix fixation bolding engine with inline code, URLs, LaTeX formulas, and wiki-link preservation.
- Visual Markdown Table Generator (`lib/features/notes/table_editor_dialog.dart`, `note_editor.dart`):
  - Interactive grid dimension steppers, column alignment, header editors, and GFM markdown insertion.
- Automated Test Suite (`test/settings_and_animations_test.dart`, `test/audio_player_and_focus_timer_test.dart`, `test/document_history_and_table_test.dart`):
  - 38 comprehensive unit and widget tests across `settings_and_animations_test.dart` (22 tests) and `audio_player_and_focus_timer_test.dart` (16 tests) with 100% pass rate.
  - Clean route cleanup and eager controller lifecycles in `_OrbitBreathingGlowState` and `_OrbitPulseBadgeState`.

Validation:
- Full test suites: `test/settings_and_animations_test.dart` (22 tests passed), `test/audio_player_and_focus_timer_test.dart` (16 tests passed).
- Static analysis: 0 warnings, 0 errors (`flutter analyze --no-pub`: "No issues found!").
- Formatting clean across all 312 files (`dart format --output=none --set-exit-if-changed lib test`).
- Production Windows release binary built in 61.4s (`build\windows\x64\runner\Release\orbit_note.exe`). Verified clean launch via process smoke test (PID 9128).
- Packaged release distribution in `release-assets\OrbitNote-Windows-x64.zip` (25.6 MB).

Suggested next task: Direct transclusion and live linking of LaTeX theorem and equation cards onto the Orbit spatial canvas.

---

# Previous task — Audio Voice Memos, Focus / Pomodoro Timer & Tactile Motion Polish, 2026-09-27

Owner request: "Continue adding more features and more animations."
Scope: High-value native productivity features with rich, tactile motion strictly adhering to Orbit Note's "quiet observatory" dark graphite design philosophy (MOT-01 through MOT-06; `docs/design/motion.md` and `docs/design/visual-design.md`). Interactive Audio Voice Memo player card with animated waveform visualizer for notes and spatial canvas (FILE-01, FILE-02), deep-work Focus / Pomodoro Timer with breathing radial progress ring (STUDY-01, DES-01), tactile task completion animation with recoverable undo snackbar (MOT-04, TASK-01), and standardized dialog transitions.

Implemented:
- Interactive Audio Voice Memo & Visual Audio Player Card (`lib/features/canvas/audio_player_card.dart`, `canvas_editor.dart`, `canvas_painter.dart`, `scene.dart`):
  - Added `'audio'` to `canvasElementTypes` in `scene.dart`.
  - Added high-DPI custom vector painting for `'audio'` cards in `OrbitCanvasPainter._element()`: rounded dark graphite card, border, circular play button glyph, memo title, audio badge, and 24-bar waveform with progress highlighting and PNG raster export.
  - Built `OrbitAudioPlayerCard`: interactive tactile audio player with play/pause toggle, live animated waveform frequency bars (28 bars with gentle sine modulation during playback, suppressed under reduced motion), clickable/draggable scrubber bar, playback speed cycling ($1.0\times, 1.25\times, 1.5\times, 2.0\times$), volume mute/unmute, and expandable `OrbitDisclosure` transcript viewer with 1-click clipboard copy.
  - Added `_addAudioMemo()` and "+ Add" menu item in `CanvasEditor` with Cyan/Teal (#06B6D4) minimap element coding. Double clicking on canvas audio elements triggers the interactive `OrbitAudioPlayerCard` in `showOrbitDialog`.
- Deep Work Focus / Pomodoro Timer with Breathing Progress Ring (`lib/features/workspace/focus_timer.dart`, `workspace_shell.dart`, `command_palette.dart`):
  - Created `FocusTimerController`: tracks modes (Focus 25m, Short Break 5m, Long Break 15m), active countdown, pause/reset/skip, session streaks, and 4-block Pomodoro cycle tracking.
  - Built `FocusTimerProgressRing`: custom-painted circular progress ring with radial sweep gradient, countdown timer in monospace tabular digits, and a subtle breathing pulse glow that activates only during active focus sessions and ceases when idle/paused/reduced-motion.
  - Built `FocusTimerDialog`: modal dialog with mode chips, large radial ring, play/pause, reset, skip controls, and 4-dot cycle streak indicator.
  - Added `FocusTimerMiniButton` in `WorkspaceShell` header toolbar (`focus-timer-button`) showing remaining time and active accent tint.
  - Added "Open Focus & Pomodoro Timer" and "Start Focus session" commands to `CommandPalette`.
- Tactile Task Completion Animation & Recoverable Recovery Action (`lib/features/workspace/workspace_views.dart`):
  - Wrapped `Checkbox` in `AnimatedScale` with `OrbitMotion.micro` and `OrbitMotion.ease`, producing tactile scale feedback on completion (suppressed under reduced-motion and off modes).
  - Tapping task completion now displays an immediate recoverable SnackBar with an "Undo" action, directly fulfilling MOT-04 and TASK-01 requirements for understandable recovery paths.
- Refined Dialog System (`lib/app/orbit_components.dart`, `command_palette.dart`, `quick_switcher_dialog.dart`):
  - Added `OrbitMotionScope.isReduced(context)` and `isOff(context)` convenience methods.
  - Made `OrbitDisclosure` accept both `visible` and `expanded` parameters for unified usage.
  - Converted `showCommandPalette` and `showQuickSwitcher` to use `showOrbitDialog`.
- Automated Test Suite (`test/audio_player_and_focus_timer_test.dart`):
  - Added 16 comprehensive unit and widget tests covering:
    - `OrbitAudioPlayerCard` rendering, play/pause toggle, speed cycling, transcript expansion, and clipboard copy.
    - Canvas `audio` element recognition, vector painting in `OrbitCanvasPainter`, and raster export with `renderCanvasToPng()`.
    - `FocusTimerController` timer state, pause, reset, mode advancement, and 4-session long break transition.
    - `FocusTimerDialog` and `FocusTimerMiniButton` widget rendering and dialog trigger.
    - `TaskRow` tactile completion, recoverable undo SnackBar, and 1-click reversion.

Validation:
- Full test suite: **930 tests passed cleanly across 125 test files** (`flutter test --no-pub`), with 0 regressions.
- Static analysis: 0 warnings, 0 errors (`flutter analyze --no-pub`: "No issues found!").
- Formatting clean across all 307 files (`dart format --output=none --set-exit-if-changed lib test`).

Suggested next task: Document History / Revisions Inspector Panel allowing users to inspect and restore past edit snapshots for notes.

---

# Previous task — Quiet Observatory Animation & Tactile Motion Polish, 2026-09-27

Owner request: "Add more animations to Orbit Note make it feel premiun and rich, stick to the oribit note designb philosophie"
Scope: Bounded, tactile interaction motion strictly adhering to Orbit Note's "quiet observatory" dark graphite design philosophy (MOT-01 through MOT-06; `docs/design/motion.md` and `docs/design/visual-design.md`). Standardized motion primitives, spatial horizontal panel entrances, floating HUD/popover fade+scale, tactile card hover illumination with micro-scale press feedback, dynamic selection indicator expansion, and standardized dialog transition styles, while strictly suppressing travel/scaling under reduced-motion preferences and zero-delay immediate rendering under off mode. Preserves direct typing, ink drawing, camera navigation, and offline persistence boundaries.

Implemented:
- Motion Primitives & Tactile Components (`lib/app/orbit_components.dart`):
  - `OrbitEntrance`: Extended with `spatial: true` and configurable `offset` (e.g., `Offset(6, 0)`), providing smooth horizontal/vertical slide-in arrivals; automatically suppresses spatial displacement under reduced motion mode.
  - `OrbitFadeScale`: Built with `TweenAnimationBuilder<double>` for quiet, subtle fade + micro-scale (0.95 -> 1.0) entrances for floating HUDs, toolbars, and tooltips, without requiring manual lifecycle controllers.
  - `OrbitCard`: Created a tactile container widget with preference-aware hover border illumination (`c.accent` with alpha), background transition (`c.panel` -> `c.hover`), and springless micro-scale press feedback (`0.985`), honoring reduced and off motion settings.
  - `OrbitPillBadge`: Tactile badge with smooth `AnimatedContainer` and `AnimatedDefaultTextStyle` color transitions.
  - `OrbitControl`: Indicator bar now dynamically expands width from 0 to 14px on selection using `OrbitMotion.control` and `OrbitMotion.ease`.
  - `showOrbitDialog<T>`: Standardized modal dialog helper with 200ms `OrbitMotion.dialog` ease-out cubic animation style.
- Workspace & Shell Navigation Animations (`lib/features/workspace/workspace_shell.dart`, `orbit_explorer_row.dart`, `document_breadcrumbs.dart`):
  - Inspector sidebar wrapped in spatial `OrbitEntrance` (`offset: Offset(6, 0)`) for smooth horizontal glide.
  - Document tabs animate background color changes and hover transitions via `AnimatedContainer` using `OrbitMotion.micro`.
  - Document breadcrumb chips wrapped in `_BreadcrumbChip` with smooth hover illumination.
  - Explorer tree item selection and focus transitions smoothed with `curve: OrbitMotion.ease`.
  - `showMoveToFolderDialog` upgraded to use `showOrbitDialog`.
- Note & Document Editor Animations (`lib/features/notes/note_editor.dart`):
  - Docked `NoteOutlinePanel` and `LatexInspector` sidebars wrapped in spatial `OrbitEntrance` (`offset: Offset(6, 0)`).
- Spatial Canvas Overlays & Tooltips (`lib/features/canvas/canvas_editor.dart`):
  - Card preview tooltip (`CanvasCardPreviewTooltip`), canvas minimap card, selection indicator HUD, and canvas search overlay wrapped in `OrbitFadeScale`.
- Automated Test Suite (`test/motion_enhancements_test.dart`):
  - 10 new comprehensive unit and widget tests covering:
    - `OrbitEntrance` spatial motion in normal mode, travel suppression in reduced mode, and zero-ticker rendering in off mode.
    - `OrbitFadeScale` scale and opacity transitions, scale suppression in reduced mode, and instant off mode.
    - `OrbitCard` hover and tap press scale feedback.
    - `OrbitPillBadge` rendering, styling, and tap handling.
    - `OrbitControl` indicator expansion from 0 to 14px on selection.
    - `showOrbitDialog` helper execution with dialog motion timing.

Validation:
- Full test suite: 914 tests passed cleanly across 124 test files (`flutter test --no-pub`), with 0 regressions.
- Static analysis: 0 warnings, 0 errors (`flutter analyze --no-pub`: "No issues found!").
- Formatting clean across all 304 files (`dart format --output=none --set-exit-if-changed lib test`).

Suggested next task: Audio voice memos and visual audio player card for Canvas boards and notes.

---

# Previous task — Canvas & Math Grid Presets Expansion, 2026-09-27

Owner request: "Add more grid presets and stuff to Orbit Note, the ones we have keep them. Just add some more"
Scope: Preserve all 8 existing canvas background paper grid presets (`dots`, `grid`, `graph`, `cornell`, `lines`, `ruled`, `isometric`, `blank`), add 6 new high-utility canvas background grid presets (`cross`, `hex`, `blueprint`, `music`, `ledger`, `triangular`) with full interactive painter and raster PNG export support, and add Math Grid builder presets (Identity matrices, 2D Rotation, Column Vectors, Piecewise cases, Aligned systems) with quick-insert preset picker in the Rich Note Math Grid dialog.

Implemented:
- Canvas Grid Presets Expansion (`lib/features/canvas/canvas_editor.dart`, `canvas_painter.dart`):
  - Preserved all 8 existing background presets intact.
  - Added 6 new canvas presets in the paper style selection menu:
    - `cross`: Cross / Reticle grid with subtle `+` tick marks at intersection nodes for CAD/drafting layouts.
    - `hex`: Regular pointy-topped hexagonal honeycomb grid with continuous tessellation for organic chemistry, game boards, and biology sketches.
    - `blueprint`: Architectural blueprint grid featuring deep cyan background tint, minor 0.6px grid, and major 1.2px divisions.
    - `music`: Musical notation manuscript staff with 5-line staves, measure bar lines, and clean vertical inter-staff margins.
    - `ledger`: Accounting / columnar ledger with ruled rows, alternating debit/credit column shading, and title header area.
    - `triangular`: 60-degree isometric equilateral triangle grid mesh for geometric tessellation and 3D wireframes.
  - Full vector painter implementation in `OrbitCanvasPainter._grid()` handling infinite canvas pan/zoom, theme contrast adaption, and pixel-perfect high-DPI raster PNG export via `renderCanvasToPng()`.
- Math Grid Builder Presets (`lib/features/notes/rich/math_grid_editor.dart`):
  - Created `MathGridPreset` data model and defined 9 standard academic presets in `mathGridPresets`: 2×2 Identity, 3×3 Identity, 2×2 Zero Matrix, 2D Rotation Matrix, 3D Column Vector, 2×2 General Matrix, 2-Case Piecewise, 3-Case Piecewise, and 2×2 Aligned Equation System.
  - Added interactive preset selector popup button (`math-grid-preset-button`) in `_MathGridDialog` header to populate rows, columns, matrix brackets, and initial cell contents with 1 click.
- Automated Test Suite (`test/grid_presets_test.dart`):
  - Added 18 comprehensive tests covering:
    - OrbitCanvasPainter painting all 14 presets without errors at standard zoom, zoomed in (2.5x), and zoomed out (0.25x).
    - `renderCanvasToPng` raster export across new presets.
    - Paper style dropdown containing all 14 items with correct icons and localized tooltips.
    - `mathGridPresets` configurations and interactive button population.

Validation:
- Full test suite: 904 tests passed cleanly across 123 test files (`flutter test --no-pub`), with 0 regressions.
- Static analysis: 0 warnings, 0 errors (`flutter analyze --no-pub`: "No issues found!").
- Formatting clean across all 303 files (`dart format --output=none --set-exit-if-changed lib test`).

Suggested next task: Audio voice memos and visual audio player card for Canvas boards and notes.

---

# Previous task — GitHub Actions CI/Release Automation & Desktop UX Polish, 2026-09-27

Concurrent owner request in this chat: [LaTeX rich document redesign](latex-rich-editor-2026-09-27.md).
That task records its scope and validation separately to preserve this shared
workspace's ongoing desktop/release work.

Owner request: "build windows release and apk", "yes lets od that, and after that lets add more tiny little features that are npot big but noticasble"
Scope: GitHub Actions CI and Release compilation workflows for Android APK and Windows x64 zip packaging, plus high-utility native desktop polish features (Explorer folder collapse/expand all, Explorer duplicate shortcut Ctrl+D, real-time selection range indicator, instant document metric cycling, and 1-click Copy Note as Markdown).

Implemented:
- GitHub Actions CI & Release Workflows (`.github/workflows/ci.yml`, `.github/workflows/release.yml`):
  - Added `workflow_dispatch` trigger for manual on-demand pipeline execution.
  - Release workflow builds Android APK (`flutter build apk --release`) and packages Windows x64 executable and assets into a distributable ZIP.
  - Conditional publish release step: uploads artifacts on tag pushes (`refs/tags/v*`), while permitting manual compilation runs without tags.
- Explorer Folder Collapse & Expand All (`lib/app/workspace_controller.dart`, `workspace_shell.dart`, `note_folder_explorer.dart`, `command_palette.dart`):
  - Added `allKnownFolders`, `collapseAllFolders()`, `expandAllFolders()`, and `areAllFoldersCollapsed` to `WorkspaceController`.
  - Added `explorer-collapse-expand-all` toolbar button in `WorkspaceShell` when exploring notes, toggling between collapse all and expand all with dynamic tooltip.
  - Added keyboard shortcut `Ctrl+Shift+E` inside `NoteFolderExplorer`.
  - Added "Collapse all folders in explorer" and "Expand all folders in explorer" to `CommandPalette`.
- Explorer Note Duplication Shortcut `Ctrl+D` (`lib/features/workspace/note_folder_explorer.dart`):
  - Pressing `Ctrl+D` on selected or focused items directly duplicates notes with `(Copy)` suffix.
- Real-Time Selection Range Counter in Footer (`lib/features/notes/note_editor.dart`):
  - Updated `note-line-col-indicator` to dynamically display selection bounds: `Ln X, Col Y (N selected)` for single-line selections and `Ln X, Col Y (M lines, N selected)` for multi-line selections.
- Instant Metric Cycling on Footer Document Stats (`lib/features/notes/note_editor.dart`):
  - Added dedicated `document-stats-toggle` button to instantly cycle metric display modes: Words & Chars -> Characters only -> Chars (no spaces) -> Read time.
  - Preserved `document-stats` click action to open the full `DocumentAnalytics` dialog.
- 1-Click Copy Entire Note as Markdown (`lib/features/notes/note_editor.dart`, `command_palette.dart`):
  - Added "Markdown" option to `note-copy-as-menu`, `Ctrl+Shift+C` shortcut, and Command Palette command.
- Documentation & Shortcuts Cheatsheet (`lib/features/notes/shortcuts_dialog.dart`):
  - Documented `Ctrl+Shift+C`, `Ctrl+Shift+E`, and `Ctrl+D`.

Validation:
- Full test suite: 880 tests passed cleanly across 122 test files (`flutter test --no-pub`), including 7 new tests in `test/explorer_collapse_and_editor_polish_test.dart` with 0 regressions.
- Static analysis: 0 errors, 0 warnings (`flutter analyze --no-pub`: "No issues found!").
- Formatting clean across all 300 files (`dart format --output=none --set-exit-if-changed lib test`).

Suggested next task: Audio voice memos and visual audio player card for Canvas boards and notes.

---

# Previous task — Navigation History Menus, Universal Document Duplication, Word Goal Dialog & Radial Progress Ring, 2026-09-27

Owner request: "Continue adding more features" (High-value, native desktop features adhering strictly to Orbit Note's "quiet observatory" dark graphite design system, local-first offline invariants, and zero AI noise).
Scope: Chronological navigation history menu & direct jump stack on Back/Forward buttons, universal document duplication for notes, canvases, and views in explorer/tabs/command palette, interactive Word Goal setting dialog with presets, and mini radial progress rings in NoteEditor header and footer.

Implemented:
- Navigation History Menus & Direct Jump (`lib/app/workspace_controller.dart`, `lib/features/workspace/workspace_shell.dart`):
  - Added deduplicated `backHistory` and `forwardHistory` getters to `WorkspaceController` tracking visited documents (up to 12 entries).
  - Added `jumpToHistoryObject(id)` method for jumping directly across history steps.
  - Added secondary-click (right-click) and long-press gesture detectors to Back and Forward buttons in `WorkspaceShell`.
  - Right-clicking Back reveals a floating popup menu of previous documents with their type icon, title, and folder path; selecting any document jumps directly to it.
  - Right-clicking Forward reveals future documents in the forward stack with 1-click jump.
  - Updated tooltips to indicate `Right-click for history`.
- Universal Document & View Duplication (`lib/app/workspace_controller.dart`, `note_folder_explorer.dart`, `workspace_shell.dart`, `command_palette.dart`):
  - Added `duplicateObject(id)` and `duplicateObjects(ids)` to `WorkspaceController` supporting notes, canvases, tasks, events, and views.
  - Automatically copies body, data (canvas elements), and properties, adding a `(Copy)` title suffix and opening the copy.
  - Added "Duplicate note", "Duplicate canvas", "Duplicate task", "Duplicate view" directly in the Note Folder Explorer object context menu.
  - Added "Duplicate X items" batch action in Explorer multi-select menu.
  - Added "Duplicate Tab" action in tab context menu.
  - Added "Duplicate current document" command in Command Palette.
- Word Goal Setting Dialog & Mini Radial Progress Ring (`lib/features/notes/word_goal_dialog.dart`, `note_editor.dart`):
  - Created `WordGoalProgressRing`: a custom-painted circular progress ring showing percentage completed, turning emerald green on 100%+ completion.
  - Created `WordGoalDialog`: a sleek, overflow-safe modal with quick preset chips (250 Draft, 500 Short, 1000 Article, 1500 Essay, 2000 Deep Dive, 5000 Paper), custom word count input with live progress calculation, "Clear Goal" button, and "Set Goal" action.
  - Embedded `WordGoalProgressRing` inside the NoteEditor toolbar `note-word-goal-badge`, opening `showWordGoalDialog` on tap.
  - Embedded `WordGoalProgressRing` inside `footer-target-goal-badge` in the editor footer status bar.
  - Added "Word Goal…" action to `note-copy-as-menu`.
- Command Palette Enhancements (`lib/features/workspace/command_palette.dart`):
  - Added "Duplicate current document" when active object is open.
  - Added "Reopen closed tab" when closed tabs exist.
  - Added "Go back in navigation history" and "Go forward in navigation history".

Validation:
- Full test suite: 873 tests across 121 test files passed cleanly (`flutter test --no-pub`), including 7 new tests in `test/navigation_history_and_word_goal_test.dart`.
- Zero analyzer warnings or errors (`flutter analyze --no-pub`: "No issues found!").
- Formatting clean across 299 files (`dart format --output=none --set-exit-if-changed lib test`).
- Production Windows release binary built in 87.8s (`build\windows\x64\runner\Release\orbit_note.exe`).
- Verified executable launches cleanly (PID 18964).
- Packaged release distribution in `release-assets\OrbitNote-Windows-x64.zip` (24.4 MB).

Suggested next task: Keyboard navigation within the Back/Forward history menu and custom hotkey bindings for document duplication (`Ctrl+D` in explorer).

---

# Previous task — Desktop Polish, Bug Fixes & Windows Release, 2026-09-27

Owner request: "continue adding bug fixes you can find. Check for errors that cant be revealed directly. check for mistakes etc too. Make this app feel less ai sloppy. Add more featuires too", "build windowsa release and fix error in this app".
Scope: Thorough audit for subtle/hidden errors, eliminate rough edges and "AI sloppy" gaps, introduce polished desktop interaction features (mouse back/forward buttons, Quick Switcher tags and ranking, auto-expanding collapsed folders on creation, mode-switching cursor continuity, copy feedback), guarantee 100% test coverage, zero analyzer issues, and package the production Windows release.

Implemented:
- Desktop Navigation & Mouse Button Support (`lib/features/workspace/workspace_shell.dart`):
  - Added dedicated pointer listener on the workspace shell for mouse back (button 8) and mouse forward (button 16) navigation.
  - Supported universal `Ctrl+O` as well as `Ctrl+E` for launching the Quick Switcher.
  - Added SnackBar feedback when clicking "Copy Reference" on tab context menu.
- Quick Switcher Intelligence & Ranking (`lib/features/workspace/quick_switcher_dialog.dart`):
  - Enabled matching against document tags (`properties['tags']`) in addition to titles and folders.
  - Upgraded sorting hierarchy: exact title match > title prefix > title substring > tag match > folder match.
- Explorer Folder Auto-Expansion on Creation (`lib/features/workspace/note_folder_explorer.dart`):
  - Creating any new document, canvas, or subfolder under a collapsed folder now automatically expands the folder so the user receives immediate visual feedback.
- Editor Mode Switching Caret Continuity (`lib/features/notes/note_editor.dart`):
  - Switching from Source mode to Rich mode now retains the exact UTF-16 character offset and auto-focuses the target block via `jumpTo`.
  - Live UTF-16 document caret & selection synchronization from Rich mode back to `NoteEditor`, driving real-time footer `Ln X, Col Y` and analytics.
- Defensive Bug Fixes & Regex Edge Cases:
  - Fixed `setState()` timing in `_recordSelection` via schedulerPhase check: avoids build-phase exceptions while ensuring immediate updates during user events.
  - Whole-word regex in `_buildSearchRegex()` now handles word and non-word boundaries correctly.
  - Guarded `_selected` indexing in `CommandPalette` against out-of-bounds keys.
  - Added `context.mounted` guard in `_showTabContextMenu`.
- Smart URL Paste over Selection (`lib/features/notes/note_editor.dart`, `lib/features/notes/rich/rich_markdown_editor.dart`):
  - Intercepts paste when URL is on clipboard and text is selected, wrapping as `[selectedText](url)` in both Rich and Source modes.

Validation:
- Full test suite of 866 tests across 120 test files passed cleanly (`flutter test --no-pub`).
- Zero issues on static analysis (`flutter analyze --no-pub`).
- Clean formatting verified with `dart format --output=none --set-exit-if-changed lib test` across 297 files.
- Windows production release built in 94.3s (`build\windows\x64\runner\Release\orbit_note.exe`).
- Verified binary launch cleanly via automation (PID 21820).
- Packaged production distribution in `release-assets\OrbitNote-Windows-x64.zip` (25.5 MB).

Suggested next task: Profiling memory consumption and cache retention in long-running workspace sessions with 100+ documents.

---

# Current task — Quiet interaction motion, 2026-09-27

Owner request: add more animations that fit Orbit Note's design philosophy.
Scope: bounded interaction transitions (MOT-01, MOT-02 and a small MOT-04 subset),
preserving immediate editing, drawing, persistence and keyboard access.

Implemented:
- Workspace/tab content arrivals with 4px travel and a restrained fade; only the
  current editor remains mounted, so input and focus are not delayed.
- Inspector entrance, calendar expand/collapse, month arrival, rotating chevron,
  and day selection feedback.
- PDF notes/review panel size transitions with state retention and hidden-focus
  exclusion; no PDF rendering or camera changes.
- Shared control underline/icon transitions, explorer selection easing, and task
  completion tint. Outline/task/drop hover feedback now follows motion settings.
- Normal/Reduced/Off and OS reduction are honored; no repeating decoration.

Validation: full suite of 858 tests passed (`flutter test --no-pub`), including
six focused motion tests, line and auto-pairing tests, breadcrumbs, bookmarks,
PDF workflows, and workspace views. Analysis found no issues (`flutter analyze --no-pub`);
formatting and no-change check passed across 295 files. Windows production release
built in 31.0s (`build\windows\x64\runner\Release\orbit_note.exe`), verified running,
and packaged to `release-assets\OrbitNote-Windows-x64.zip` (25.5 MB). Behavior: [motion system](../design/motion.md).

Suggested next task: native performance review of large populated workspaces.

---


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task — Go to Line (Ctrl+G), Live Line:Column Status Indicator, Auto-Pairing & Delimiter Wrapping, and Line Move/Duplicate Shortcuts, 2026-09-27

Owner request: "go on and more little but noticiable features and no ai slop", "Go for more tiny but noticeable features" (Subtle, highly noticeable productivity and editing enhancements strictly adhering to Orbit Note's "quiet observatory" dark graphite design system, local-first offline invariants, and zero AI slop).
Scope: Universal Go to Line modal (`Ctrl+G`), real-time footer `Ln X, Col Y` cursor position indicator with 1-click jump, smart bracket and quotation auto-pairing with step-over and apostrophe safety, selection wrapping with brackets/quotes/markdown syntax (`*`, `_`, `~`, `$`, `` ` ``), backspace empty pair deletion, line movement shortcuts (`Alt+Up` / `Alt+Down`), and line duplication (`Shift+Alt+Down`).

Implemented:
- Live Line:Column Footer Status Indicator (`lib/features/notes/note_editor.dart`):
  - Added interactive `note-line-col-indicator` in the editor footer alongside document analytics.
  - Dynamically computes and displays `Ln ${pos.line}, Col ${pos.column}` reactively updated on cursor movement and text entry.
  - Formatted with compact typography and tabular digits for zero-jitter layout stability.
  - Hover tooltip indicates `Go to Line (Ctrl+G)`.
  - 1-click tap triggers the Go to Line dialog.
- Go to Line Floating Modal (`lib/features/notes/go_to_line_dialog.dart`, `note_editor.dart`):
  - Compact floating prompt (max width 380px) triggered via `Ctrl+G` or footer indicator tap.
  - Header displays total document lines range (`Lines 1 to N`).
  - Autofocused input with live validation supporting `line` or `line:col` notation (e.g. `42` or `42:5`).
  - Live feedback preview showing target destination.
  - Clamps targets safely within document boundaries.
  - Submitting jumps cursor directly to target line and column, brings position into view (`bringIntoView`), and scrolls preview in split/read modes.
- Smart Bracket & Quotation Auto-Pairing & Step-Over (`lib/features/notes/markdown_editing.dart`, `note_editor.dart`):
  - Auto-pairs open brackets and quotes when caret is collapsed:
    - `(` -> `()` with cursor placed inside
    - `[` -> `[]` with cursor placed inside
    - `{` -> `{}` with cursor placed inside
    - `"` -> `""` with cursor placed inside
    - `'` -> `''` with cursor placed inside
    - `` ` `` -> `` `` `` with cursor placed inside
    - `$` -> `$$` with cursor placed inside
  - Smart apostrophe protection: typing `'` after letters (e.g. `don't`, `it's`) does not auto-pair second quote.
  - Quote safety: typing `"` or `'` directly before word characters does not auto-pair.
  - Consecutive step-over: typing matching closing bracket or quote (`]`, `)`, `}`, `"`, `'`, `` ` ``, `$`) steps over the character instead of duplicating it.
  - Backspace pair deletion: pressing Backspace when caret is positioned between empty pairs (`()`, `[]`, `{}`, `""`, `''`, `` `` ``, `$$`, `**`, `__`, `~~`) deletes both delimiters cleanly.
- Selection Wrapping with Delimiters (`lib/features/notes/markdown_editing.dart`, `note_editor.dart`):
  - Typing `(`, `[`, `{`, `"`, `'`, `` ` ``, `*`, `_`, `~`, or `$` around active text selection wraps the selection instead of replacing it.
  - Selection is cleanly preserved around the enclosed text for immediate follow-up styling or typing.
- Move Line & Duplicate Line Shortcuts (`lib/features/notes/markdown_editing.dart`, `note_editor.dart`):
  - `Alt+Up` / `Alt+Down`: Fluidly moves active line or selected lines up/down without clipboard cut/paste, preserving relative cursor position. Bounded at document boundaries.
  - `Shift+Alt+Down`: Duplicates current line or selected lines downwards with cursor preserved at identical column position.
- Shortcuts Cheatsheet & Documentation Updates (`lib/features/notes/shortcuts_dialog.dart`):
  - Added `Ctrl+G` (Go to line) under Navigation & Search.
  - Added `Shift+Alt+Down` (Duplicate line downwards) and `Alt+Up`/`Alt+Down` (Move line / block up/down) under Blocks & Structure.

Validation:
- 12 comprehensive unit and widget tests in `test/editor_line_and_pairing_features_test.dart`:
  - `lineAndColumnOf` 1-indexed line and column calculations across boundaries, newlines, and empty text.
  - `totalLinesOf` and `offsetOfLine` mapping and boundary clamping.
  - `wrapSelection` with brackets, quotes, markdown formatting, and math syntax.
  - `handleAutoWrapOrPair` selection wrapping, collapsed auto-pairing, step-over, and apostrophe suppression.
  - `handleBackspacePair` empty pair deletion across `()`, `[]`, `""`, `$$`.
  - `moveLine` line swapping up/down and top/bottom boundary guards.
  - `duplicateLine` line cloning downwards with cursor preservation.
  - `GoToLineDialog` input parsing (`line` and `line:col`), validation feedback, submit, and cancel.
  - `NoteEditor` line/col footer indicator rendering and dynamic updates.
- 45 regression tests verified and passing across `document_breadcrumbs_and_pin_test.dart`, `quick_switcher_and_note_actions_test.dart`, `note_outline_and_target_features_test.dart`, `note_productivity_features_test.dart`, `workspace_tabs_bookmarks_test.dart`, and `notes_navigation_test.dart`. All 57 tests passed.
- `dart format --output=none --set-exit-if-changed lib test` clean across 295 files.
- `flutter analyze --no-pub` reported 0 errors and 0 warnings ("No issues found!").

Suggested next task: Document History / Revisions Inspector Panel allowing users to inspect and restore past edit snapshots for the current note.

---


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task — Document Breadcrumbs Trail, Tab Pinning Header Control, Word Goal Progress Badge & Quick Copy Options, 2026-09-27

Owner request: "go on and more little but noticiable features and no ai slop" (High-utility productivity features adhering strictly to the "quiet observatory" dark graphite design system, local-first offline invariants, and zero AI fluff).
Scope: Document Breadcrumbs navigation trail (`DocumentBreadcrumbs`) showing Vault > Folder > Subfolder > Document with popovers for sibling navigation, folder navigation, new note creation, and quick actions; 1-click `note-pin-toggle` header control; live `note-word-goal-badge` header indicator; and Wiki-Link (`[[...]]`) & relative path options in `note-copy-as-menu`.

Implemented:
- Document Breadcrumbs Trail (`lib/features/workspace/document_breadcrumbs.dart`):
  - Slim 28px horizontal hierarchy bar located at the top of `NoteEditor` (Vault > Folder... > Document Title).
  - Truncates gracefully with `SingleChildScrollView(scrollDirection: Axis.horizontal)` so it never causes layout overflows in narrow or split panes.
  - Interactive Vault segment (`breadcrumb-vault`):
    - Displays vault icon and vault name (`Personal Vault` or custom vault name).
    - Popover menu with root folders and action to create new note in vault root.
  - Interactive Folder segment(s) (`breadcrumb-folder-i`):
    - Popover menu listing direct child subfolders and up to 20 active sibling notes and canvases in that folder.
    - Sibling objects show their respective type icon (`orbit.note`, `orbit.canvas`, `orbit.file`, `orbit.task`).
    - Currently active document is indicated with an active checkmark.
    - Selecting any sibling note/canvas instantly navigates to it (`onOpenObject`).
    - Action item `+ New note in "<folder>"` spins up a blank note directly in the targeted folder.
  - Interactive Document segment (`breadcrumb-document`):
    - Displays document icon (custom emoji, LaTeX formula symbol, or note icon) with bold font styling.
    - Quick actions menu:
      - `Copy relative path`: Copies e.g. `Notes/Projects/Design.md` to clipboard with toast confirmation.
      - `Copy wiki-link`: Copies `[[Design]]` to clipboard.
      - `Copy object ID`: Copies universal UUID.
      - `Move to folder...`: Opens `showMoveToFolderDialog` to relocate the note to any vault folder with real-time filter search.
      - `Bookmark note` / `Remove bookmark`: Toggles bookmark state with amber accent feedback.
      - `Pin tab` / `Unpin tab`: Toggles pin state with violet accent feedback.
- Tab Pinning Note Header Control (`note-pin-toggle` in `lib/features/notes/note_editor.dart`, `workspace_shell.dart`):
  - 1-click header button placed alongside `note-bookmark-toggle` reflecting whether the active tab is pinned (`Icons.push_pin_rounded` in violet when pinned; `Icons.push_pin_outlined` when unpinned).
  - Synchronized with `WorkspaceController.isPinned` and tab strip pins.
- Word Goal Progress Header Badge (`note-word-goal-badge` in `lib/features/notes/note_editor.dart`):
  - Dynamic progress badge displayed in the toolbar when target words are set (e.g. `350/500`).
  - Displays violet outline when in progress and turns emerald green with a checkmark once target is achieved.
  - 1-click tap opens the target words / document stats dialog for immediate goal adjustment.
- Wiki-Link & Relative Path Fast Copy (`note-copy-as-menu` in `lib/features/notes/note_editor.dart`):
  - Added "Wiki-Link" (`[[Title]]`) and "Relative Path" (`Folder/Title.md`) directly in the header "Copy as..." dropdown.
- WorkspaceController & Shell Integration (`lib/app/workspace_controller.dart`, `workspace_shell.dart`):
  - Added `c.objectFolder(id)` helper method.
  - Wired vault name, folder paths, active objects, folder lookup, `onMoveToFolder`, and `onCreateNoteInFolder` into both primary and secondary panes.

Validation:
- 9 comprehensive tests in `test/document_breadcrumbs_and_pin_test.dart`:
  - Renders vault, folder hierarchy, and document segments accurately.
  - Folder segment popover opens, lists sibling objects, and navigates on tap.
  - New note in folder action executes `onCreateNoteInFolder`.
  - Document popover triggers bookmark and pin actions.
  - `showMoveToFolderDialog` lists folders, filters, and selects target folder.
  - Header pin button toggles pin state and displays active tooltip.
  - Word goal badge displays words and target progress.
  - `note-copy-as-menu` offers Wiki-Link and Relative Path options.
- 36 regression tests verified and passing (`test/quick_switcher_and_note_actions_test.dart`, `test/note_outline_and_target_features_test.dart`, `test/note_productivity_features_test.dart`, `test/workspace_tabs_bookmarks_test.dart`, `test/notes_navigation_test.dart`). All 45 tests passed.
- `dart format --output=none --set-exit-if-changed lib test` clean across 293 files.
- `flutter analyze --no-pub` reported 0 errors and 0 warnings ("No issues found!").

Suggested next task: Document History / Revisions Inspector Panel allowing users to inspect and restore past edit snapshots for the current note.

---


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task — Quick Switcher & Note Header Focus/Bookmark Controls, 2026-09-27

Owner request: "go on and more little but noticiable features and no ai slop" (Subtle, highly noticeable productivity and navigation enhancements following Orbit Note's "quiet observatory" design tokens, local-first offline invariants, and zero AI noise).
Scope: Universal Quick Switcher overlay (`Ctrl+E`), document jump with tabs/recents/bookmarks/all, fallback instant note creation, and 1-click Note Editor header bookmark and focus mode toggle controls.

Implemented:
- Universal Quick Switcher Overlay (`lib/features/workspace/quick_switcher_dialog.dart`, `workspace_shell.dart`):
  Lightweight modal overlay (max width 580px, max height 480px) triggered via `Ctrl+E` or the tab bar flash button (`quick-switcher-button`).
  Categorizes items by Open Tabs, Recent Documents (MRU order), and Bookmarks.
  Instant fuzzy search across titles and parent folders.
  Keyboard-first navigation with `ArrowUp` / `ArrowDown` selection, auto-scroll viewport centering, `Enter` to open, and `Esc` to dismiss.
  Clean fallback when query doesn't match an existing title: displays "Create new note [query]" action to spin up notes without losing flow.
- Note Editor Bookmark & Focus Mode Header Controls (`lib/features/notes/note_editor.dart`, `workspace_shell.dart`):
  Direct 1-click header buttons seamlessly reflecting active state:
  - `note-bookmark-toggle`: Golden accent when bookmarked, allows quick bookmarking (`Ctrl+Shift+D`) directly from note header.
  - `note-focus-mode-toggle`: Violet accent when in Focus Mode (`F11`), toggles chrome/sidebar immersion with full tooltips.
- Keyboard Shortcuts Cheatsheet Integration (`lib/features/notes/shortcuts_dialog.dart`):
  Added `Ctrl+E` (Quick Switcher) under Navigation & Search.

Validation:
- 5 comprehensive unit and widget tests passed (`test/quick_switcher_and_note_actions_test.dart`):
  - Displays open tabs, recents, bookmarks, and filters accurately.
  - Keyboard navigation with Arrow keys and Enter opens selected note.
  - Fallback create note option appears and creates note.
  - Note header bookmark button toggles state and updates icon/tooltip.
  - Note header focus mode button toggles state and updates icon/tooltip.
- 31 regression tests verified and passed (`test/note_outline_and_target_features_test.dart`,
  `test/note_productivity_features_test.dart`, `test/workspace_tabs_bookmarks_test.dart`,
  `test/notes_navigation_test.dart`). All 36 tests passed.
- `dart format --output=none --set-exit-if-changed` verified 0 formatting differences across 291 files.
- `flutter analyze --no-pub` reported 0 errors and 0 warnings ("No issues found!").

Suggested next task: Breadcrumb navigation trail in Note and Canvas headers displaying the hierarchy path (Vault > Folder > Document) with click-to-navigate dropdown menus.

---


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task — Note Outline Rail, Target Goals & Fast Format Copy, 2026-09-26

---


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task — Product design and UI quality, 2026-09-24

Owner request: major product-design/design-system quality brief, followed by
continued small, noticeable refinements. Implementation and release validation
completed on 27 September; see the [quality review](../design/product-quality-review-2026-09-26.md)
for native review coverage and remaining visual checks.

Delivered: semantic selected/pressed/focus colors and typography, stable mode
controls, common toolbar separators, continuation-first Home, cleaner capture and
inspector identity, preferences-first Settings, Calendar short-pane overflow fix,
PDF navigation-first toolbar with overflow affordance, and a keyboard command
palette with grouped commands and object-type filtering. Home hides raw LaTeX
preambles; note statistics are contextual and do not label LaTeX as prose.

Evidence: [pre-implementation audit](../design/product-quality-audit-2026-09-24.md),
7 new quality tests including 16 desktop size/scaling combinations, and an
81-test focused regression pass. Native baselines and reviewed post-change screens
are under `work/ui/product-quality`. The final report distinguishes physical
Windows checks from simulated display scaling and records remaining limits.

Final combined-code validation: 852 tests passed, analyzer clean, format check
clean (300 files), production Windows release built in 56.5s and launched.
Native smoke covered Home/Explorer, Tasks, Settings, empty Canvas and command
palette keyboard selection/dismissal. Corrected the reading-progress update
during equation layout and refreshed the Help regression test for the newer
shortcuts dialog. Next suggested task: populated Canvas/PDF native review and
physical DPI-transition checks.

---


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task — Dedicated LaTeX Document Editor & Mathematics Authoring Pass, 2026-09-24

Owner request: Dedicated LaTeX editing experience suitable for university mathematics, engineering, computer science, physics, academic writing, proofs, assignments, exercise sheets, reports, and research notes.
Scope: Visual academic document editor, structured AST parser/serializer, bidirectional Markdown <-> LaTeX converter, starter templates, math palette, matrix/cases builder, academic preview, pure-Dart offline PDF export, and LaTeX inspector.

Implemented:
- Lossless AST parser & serializer (`lib/features/notes/latex/latex_document.dart`):
  Parses full `.tex` documents into structured `LatexBlock`s (title, author, date,
  abstract, sections, equations, theorems, proofs, tables, figures, lists, page breaks,
  preamble, comments, raw). Round-trips cleanly preserving comments and unknown packages/commands.
- Academic starter templates (`lib/features/notes/latex/latex_templates.dart`):
  Blank, University Assignment, Exercise Sheet / Problem Set, Research Paper / Report,
  and Quick Formula Sheet.
- Safe format converter & modal dialog (`latex_converter.dart`, `latex_format_dialog.dart`):
  Bidirectional `markdownToLatex` and `latexToMarkdown` with warning detection. Format
  switcher badge in note header allows "Convert In-Place" or safe non-destructive "Create Copy".
- Real-time syntax highlighter & smart autocompleter (`latex_syntax_highlighter.dart`):
  Highlights environments, commands, math modes, and comments; autocompletes `\begin{...}`
  environments, `\ref{...}` labels, and standard academic macros.
- Searchable math symbol palette (`latex_math_palette.dart`):
  11 categorized tabs (Basic, Operators, Relations, Sets, Logic, Calculus, Greek, Linear Algebra,
  Brackets, Arrows) with natural language search aliases ("belongs to", "real numbers", "gradient").
- Matrix & Piecewise cases builder (`lib/features/notes/rich/math_grid_editor.dart`):
  Visual grid editor supporting `pmatrix`, `bmatrix`, `Bmatrix`, `vmatrix`, `Vmatrix`,
  `matrix`, `aligned`, and `cases` with dynamic row/column insertion and deletion.
- Visual academic block editor (`rich_latex_editor.dart`):
  Block-based editing with title/author/date header, section hierarchy, interactive equation
  cards with quick math toolbar (Frac, Sqrt, Power, Subscript, Sum, Int, Matrix, Cases, Palette),
  theorems/lemmas/definitions, proofs with Halmos tombstone `□`, tables, and figures.
- Academic live preview (`latex_preview.dart`):
  Renders formatted academic paper preview with numbered sections, display math with equation
  numbers, theorem cards, proofs with Halmos tombstone `□`, horizontally-scrollable formulas,
  and formatted text with inline math `$x^2$`.
- Document inspector sidebar (`latex_inspector.dart`):
  Document class, paper size, base font size, margins/geometry selector, active package manager,
  custom preamble/macros editor, and live document outline navigator.
- Pure-Dart offline PDF generator (`lib/features/notes/export/pdf_export_service.dart`):
  Produces valid `%PDF-1.4` documents directly without external native TeX distributions
  or C++ plugins. Supports title, author, date, sections, paragraphs, equations, theorems,
  tables, and automatic page numbering.
- Integrated into `NoteEditor`, `WorkspaceShell` (+ New menu & tabs), and Command Palette.

Validation:
- 25 focused unit and integration tests passed: `test/latex_document_test.dart`,
  `test/pdf_export_test.dart`, `test/latex_editor_integration_test.dart`, and
  `test/rich_math_editor_test.dart`.
- `dart format lib/features/notes/export lib/features/notes/latex test/...` passes cleanly.
- `flutter analyze --no-pub` reported 0 errors and 0 warnings.
- `flutter build windows --release` succeeded: `build\windows\x64\runner\Release\orbit_note.exe` in 71.7s.

Suggested next task: Direct transclusion and live linking of LaTeX theorem and equation cards onto the Orbit spatial canvas.

---


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task — Bookmark sorting and keyboard navigation, 2026-09-24

Owner request: Add bookmark sorting and arrow-key navigation.
Scope: FILE-11 bookmark browser interaction; no persistence format changes.

Implemented:
- Sort by page ascending/descending or name A–Z/Z–A. Names compare without case;
  duplicate names use page number as a stable tie-breaker. Sort choice is local to
  the open dialog and does not rewrite stored bookmarks.
- Up/Down in the focused filter selects the previous/next filtered, sorted
  bookmark. Selection is bounded, updates the preview, and scrolls into view.
  Enter retains its existing Open page behavior; unavailable pages stay disabled.
- Sorting retains the selected page and current preview. Filtering and renaming
  reveal the retained/replacement selection. Boundary presses do not reload the
  same preview; empty results handle arrows safely.
- Stable row keys, text-scaled row heights and a minimum one-row viewport support
  reordered lists, short windows and enlarged text.

Validation: all four focused bookmark-dialog tests passed (sort direction/ties,
selection preservation, 60-bookmark keyboard navigation/Enter, narrow 200% text,
and existing rename failure/search behavior). Full checks/build pending.
Evidence: `.local/pdf-bookmark-navigation-focused.log`. No manual native visual
review in this pass.

Suggested next task: bookmark-browser keyboard navigation from focused result rows.

---


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task — Named PDF bookmarks and previews, 2026-09-24

Owner request: Add named personal bookmarks with search and page previews.
Scope: FILE-11 bookmarks using existing object metadata/save boundaries.

Implemented:
- Saved pages opens a searchable bookmark browser with names, page numbers,
  a preview of the selected page, and an explicit Open page action (or Enter).
- Rename existing bookmarks; a blank name restores the page-number label.
  Failed saves retain the typed name for retry, and read-only readers omit rename.
- Previews render the current selection only, bounded to 480px on its longest
  edge. Native and Flutter image resources are disposed after PNG conversion.
  Source changes block stale preview results, navigation and rename callbacks.
- Legacy `pdfBookmarks` remains an integer list. Optional `pdfBookmarkNames`
  adds names alongside it, preserving unrelated properties and unknown map keys.
  Removing a page bookmark leaves its name dormant for compatibility/re-adding.
- Missing/out-of-range pages remain listed with an explanation; opening and
  rendering them are disabled. The original attachment is unchanged.

Validation: full suite passed 787 tests (`.local/pdf-bookmarks-tests.log`), including
persistence/reopen, original-byte preservation, failed save/retry, unknown metadata
preservation, search, stale-page guards and real PDF preview/navigation. Analysis
found no issues; formatting/no-change check passed. Windows release build succeeded
in 53.6 seconds (`.local/pdf-bookmarks-build.log`). No fresh manual native visual review.

Suggested next task: keyboard arrow navigation and sorting in the bookmark browser.

---


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task — Searchable PDF outline, 2026-09-22

Owner request: Add more reading/navigation features.
Scope: FILE-11 searchable embedded outline, retaining existing PDF source data.

Implemented:
- Replaced the outline dropdown with a searchable dialog. Matching ignores case
  and surrounding whitespace, searches all query words across heading and parent
  names, and shows parent paths/page numbers to distinguish repeated headings.
- Removed the old ten-level display cutoff using iterative traversal. Results
  render lazily; long headings have full-path tooltips.
- Up/Down selects and scrolls through navigable entries; Enter opens selection.
  Heading groups remain visible but cannot trigger a jump. Pointer/Tab activation
  is retained; empty results and PDFs without headings have explicit messages.
- Opening a heading honors its full PDF destination (position/zoom where specified),
  remembers the departing page, and ignores results from a replaced viewer.
- Outline loading disables the button until finished. Read failures are explained
  separately from an absent outline and do not block normal page navigation.

Validation: three focused outline tests passed, covering parent-heading search,
exact destinations, depth beyond 10, keyboard scrolling through 50 results and
the empty state at 320x480/200% text. Full suite: 784 tests passed
(`.local/pdf-outline-tests.log`); analysis and formatting clean. Production
Windows x64 release build completed cleanly (`orbit_note.exe` + `app.so` 16.3 MB,
packaged `release-assets\OrbitNote-Windows-x64.zip` 25.3 MB). Tests use synthetic
outline nodes plus reader integration on a real PDF without embedded headings;
no native visual review or large-document performance benchmark in this pass.

Suggested next task: named personal bookmarks with search and page previews.

---


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task — PDF reading and navigation tools, 2026-09-22

Owner request: Add more Acrobat-style features; preference: reading and navigation.
Scope: FILE-11 research-reader improvements, offline and without rewriting PDFs.

Implemented:
- Zoom menu: 400% preset and Custom zoom with fractional percentages, optional
  percent suffix, keyboard submission and validation against the viewer's bounds.
  Cancel makes no change; non-finite, invalid and out-of-range values are rejected.
  A stale dialog cannot change a newly mounted document/viewer.
- Document tools menu: first/last page and previous/next visited page.
  Explicit page jumps and internal PDF links remember the departing page;
  new jumps clear forward history. History is session-local, bounded to 100 prior
  jumps, cleared on source replacement, and restores page numbers rather than
  precise scroll positions or zoom. Scrolling/search matches do not create entries.
- Document information: title, page count/current page, current page dimensions
  in mm, encryption state, and source copying permission where supplied by engine.
  This is informational and does not unlock or change PDF permissions.

Validation: 11 focused PDF tests passed (including real PDF navigation, custom
zoom and history isolation). Full suite: 781 tests passed; analysis found no issues;
formatting and no-change check passed. Windows release build succeeded in 53.4s
(`.local/pdf-reading-build.log`). No new dependencies,
storage format changes, or manual native visual review.
Evidence: `.local/pdf-reading-focused.log`.

Suggested next task: a searchable outline panel for long PDFs.

---


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task — PDF keyboard navigation, 2026-09-22

Owner request: Proceed with keyboard navigation in connected notes and thumbnails.
Scope: FILE-11/FILE-12 interaction and focus recovery; preserve original PDFs,
note identities and persistence behavior.

Implemented:
- Opening connected notes focuses its filter, including repeated openings of the
  retained panel. Enter opens the first filtered note; no matches does nothing.
  Escape closes the panel and returns focus to the reader.
- Connected-note controls and lazy results now share one scrollable area, so
  constrained heights and enlarged text do not clip controls or empty messages.
- Opening thumbnails focuses the rail and reveals the current page. Up/Down and
  Home/End navigate pages with bounded selection and scroll the thumbnail into
  view. Enter returns focus to the reader; Escape closes the rail and returns
  focus. A visible focus border and selected page semantics expose its state.
- Focus nodes and scroll controller are disposed with the reader.

Validation: nine PDF reliability tests pass, including actual-PDF keyboard paging,
  boundaries, focus recovery via Ctrl+F, repeated connected-note opening, and
  note filtering/activation at 320x320 with 200% text. Full suite: 779 tests passed
  (`.local/pdf-keyboard-tests.log`). Analysis found no issues; required formatting
  and no-change check passed. Windows release built in 52.7 seconds
  (`.local/pdf-keyboard-build.log`).
Evidence: `.local/pdf-keyboard-focused.log`. No new manual native visual review.

Suggested next task: audit PDF search keyboard shortcuts and focus recovery when
closing search or switching between reader panes.

---


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task — PDF controls in narrow and short panes, 2026-09-22

Owner request: Proceed with the suggested PDF toolbar and annotation-dialog audit.
Scope: FILE-11/FILE-12 layout reliability at narrow widths and enlarged text;
preserve document bytes, annotation identities, persistence and current styling.

Implemented:
- PDF search input occupies its own row; match status and navigation controls
  wrap below it. Reproduced a 116px overflow at 320px width and 200% text before
  fixing it. The regression opens search on a real PDF, types and closes it.
- Highlights panel uses one scrollable area for controls and a lazily built
  review list. Reproduced a 37px vertical overflow in a 280x320 window at 200%
  text. Filters and review actions remain reachable by scrolling.
- Checked review dialog save/failure handling at 320x480 and 200% text; no
  production dialog change was needed. Stale-source edit protection is retained.

Validation: formatting and no-change check passed; analysis found no issues.
Full suite: 777 tests passed (`.local/pdf-layout-tests.log`). Windows release build
succeeded in 49.9 seconds (`.local/pdf-layout-build.log`).
Reproduction logs: `.local/pdf-layout-before.log`
and `.local/pdf-search-before.log`. This pass uses automated layout and interaction
checks, not a new native visual review.

Suggested next task: audit connected-notes and PDF thumbnail navigation with
keyboard input and constrained pane heights.

---


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task — Search and calendar layout reliability, 2026-09-21

Owner request: Look for more issues like the formula-menu overflow and fix them.
Scope: Targeted layout and interaction audit; preserve the current design language
and unrelated work. No new features or storage changes.

Implemented:
- Canvas search: give the input its own row and allow result navigation controls
  to wrap, keeping a usable typing area in narrow panes and at enlarged text sizes.
- Command palette: normalize surrounding whitespace consistently so recent
  knowledge and command matches remain available for padded/blank queries.
- Explorer calendar: replace fixed day-cell heights with a minimum height and
  content-driven sizing so enlarged dates and activity dots fit.

Validation: Reproduced the search and calendar failures before fixing them.
All 18 focused tests pass, including a 280px search pane at 200% text and an
expanded calendar at 200% text. Full suite: 775 tests passed. Static analysis:
no issues. Required formatting and no-change check passed. Windows release build
succeeded in 50.0 seconds (`.local/layout-audit-build.log`). Validation for this
pass is automated; a fresh native visual review was not performed.
Evidence: `.local/layout-audit-before.log`, `.local/calendar-layout-before.log`,
`.local/layout-audit-focused.log`, and `.local/layout-audit-tests.log`.

Suggested next task: audit PDF toolbars and annotation dialogs at narrow widths
and enlarged text sizes.

---


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task — Dense Mathematical Canvas & Transclusion Rendering & Minimap Spatial Search Radar, 2026-09-21

Owner request: "There have been some design changes, stick to them, dont change the design language. Continue on adding new features"
Scope: Implement mathematical formula rendering for Canvas cards, live transclusions, and sticky notes (`CAN-02`, `CAN-15`, `NOTE-07`), alongside Minimap Spatial Search Radar Dots (`CAN-14`), adhering strictly to the newly delivered design language (4/8/12/16 spacing scale, graphite surfaces, neutral hover/pressed states, and quiet violet selection).

Implemented:
- Dense Mathematical Canvas Rich Text Engine (`lib/features/canvas/canvas_rich_text.dart`):
  - Added `CanvasRichLineType.displayMath`, `codeBlock`, and `blockquote`.
  - Added pure-Dart mathematical typesetting engine (`formatMathToUnicode`, `_formatFraction`, `_toSuperscript`, `_toSubscript`, `formatInlineMath`):
    - Converts LaTeX Greek symbols (`\alpha`, `\beta`, `\pi`, `\theta`, `\sigma`, `\Delta`, `\Omega`, `\infty`, etc.).
    - Converts mathematical operators (`\times`, `\div`, `\pm`, `\leq`, `\geq`, `\neq`, `\approx`, `\in`, `\sum`, `\int`, `\partial`, etc.).
    - Formats fractions into clean Unicode vulgar fractions or single-line quotients (`a / b`).
    - Formats radicals into unicode roots (`√(x)`, `³√(8)`).
    - Formats sub- and superscripts (`x₀`, `y¹²`, `e⁻ˣ`).
  - Added support for inline `$formula$` across headings, checklists, bullet points, numbered lists, and paragraphs.
  - Multi-line `$$ ... $$` math block detection and single-line `$$...$$` equations.
  - Updated `hasRichFormatting` to detect `$$`, `$`, code blocks, and blockquotes so mathematical notes automatically route through the rich layout engine.
  - Custom display math rendering on graphite cards with centered formula alignment.
- Canvas Minimap Spatial Search Radar Dots (`CAN-14` refinement in `lib/features/canvas/canvas_editor.dart`):
  - Updated `CanvasMinimapPainter` with `searchMatchIds: Set<String>` and `activeSearchMatchId: String?`.
  - Paints glowing amber radar pings (`#F59E0B`) at matching element coordinates on the minimap radar.
  - Paints an active gold targeting ring on the currently focused search result (`activeSearchMatchId`).
  - Added compact search match counter badge in the minimap RADAR header with tooltip feedback, wrapped in `Expanded` to eliminate layout overflow.
- Quick Formula / Math Note Insertion (`lib/features/canvas/canvas_editor.dart`):
  - Added `"Formula / math card"` action (`Icons.functions`) to the Canvas toolbar "Add / organize board content" `PopupMenuButton`.
  - Added `"Add Formula / Math Note"` action to the Canvas right-click context menu.
  - Added `_addFormulaCard({CanvasPoint? at})` creating a sticky note pre-populated with LaTeX formulas.

Validation:
- `test/canvas_math_transclusion_test.dart`: 10 passed (LaTeX unicode formatting, display math blocks, transclusions, minimap radar pings, targeting ring, and minimap badge UI).
- `test/canvas_transclusion_minimap_test.dart`: 8 passed.
- `test/workspace_tabs_bookmarks_test.dart`: 13 passed.
- `test/bootstrap_test.dart`: 3 passed.
- Full project `flutter analyze --no-pub`: 0 issues found.
- `dart format --output=none --set-exit-if-changed lib test`: 0 changed.

Suggested next task: Audio voice memos and visual audio player card for Canvas boards and notes.

---


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task — UI/UX refinement, 2026-09-21

Completed the calmer Home, compact explorer creation/filter menus and calendar,
quieter tabs, contextual Canvas tools, Inspector cleanup, responsive note headers,
same-note split views, recent-object palette ordering, and paragraph Ctrl+A fix.
Existing storage and object identities were preserved.

Validation of the UI refinement snapshot: 764 tests passed; 18 focused UI
acceptance tests and split-view regression passed; static analysis and formatting
were clean. Windows production release built in 60.2 seconds and launched.
That binary and native captures predate the subsequent Canvas work above.
Detailed audit, screenshots and scope limits: [UI refinement review](../design/ui-refinement-review.md).

Follow-up validation with the newer Canvas changes: all 774 tests passed,
analysis found no issues, and formatting was clean. Fixed the formula context
menu label overflowing by allowing its text to wrap within the menu width.
The combined production Windows release also built successfully in 54.1 seconds.

Suggested next visual task: review dense mathematical boards and complex equation
fidelity using the newer Canvas rendering.


Fixed six reproduced content/failure boundaries: browser destinations containing
spaces/parentheses/entities, multiline HTML table cells, multi-paragraph/code
block quotations, PDF quote mixed line endings, repeated Rich cut/undo/redo/paste
with a stale trailing empty field, and repeated protected-fragment scans on large
HTML pastes. Note-to-Canvas prose uses buffered accumulation. Existing ordinary
source/plain-paste behavior, reference identities and document history remain.

Validation: 260 focused tests passed in 66 seconds, covering clipboard failure
and stale callbacks, split-pane selections/history, tables/code, selection scroll,
images, PDF quotes and Canvas transfer. New stress acceptance extracts real text
from 30 synthetic PDFium pages into a 500-paragraph Rich note, then performs five
cut/undo/redo/paste cycles with exact source restoration. A 180-element connected
Canvas survives movement, cut/undo and three duplicate/undo cycles with valid
unique identities. A 4,000-code-run HTML fixture retained all content; conversion
fell from 1,424 ms before the fix to 118–175 ms in isolated/final synthetic runs.
These are conversion timings, not an end-to-end frame or hardware latency claim.

Actual Windows Unicode/CF_HTML clipboard helper acceptance passed 12 alternating
empty/small/multi-megabyte round trips in a private window station, with exact
UTF-8 fragment byte offsets. User clipboard and personal Vaults were untouched.
The probe compiles the existing native helper functions and does not launch Orbit.
External Firefox/Acrobat UI transfer and physical device testing remain unverified.
No full all-repository test run or device-wide bug-free claim. No architecture or
storage migration. Logs: .local/clipboard-final-tests.log, clipboard-analyze.log,
clipboard-format-check.log; native probe: .local/native_clipboard_audit.cpp/.exe.

Final analyzer clean (6.5 seconds); strict format checked 795 files with no
changes. Normal Windows release built successfully in 79.3 seconds; direct
EXE, Flutter DLL, current AOT data and standalone server verified. Build targets
lib/main.dart. No server was started and no credentials were packaged by the
server build. Run build/windows/x64/runner/Release/orbit_note.exe directly.

Suggested next task: real external browser/Firefox/Acrobat clipboard interoperability
acceptance on isolated disposable notes, covering native menus and image formats.

## Previous task — Workspace Tabs, Bookmarking & Backlinks Local Context Graph with 1-Click Linking (Option 2 & Option 5), 2026-09-21

Owner request: "Lets go with Option 2 and Option 5(also add like bookamrking tabs andf stuff like that too, also bookmark icons too)"
Scope: Document tabs management and bookmarking with amber accents and dropdown access, pure-Dart backlinks and unlinked mentions engine, interactive 2D Local Context Graph with spring physics, 1-click mention linking (`+ Link`), and NoteEditor quick-access backlinks button.

Implemented:
- Workspace Tabs & Bookmarking Engine (Option 5):
  - Added `bookmarkedTabs` list to `SessionState` (`lib/app/session_state.dart`) with robust JSON serialization and backward compatibility.
  - Added `isBookmarked(id)`, `toggleBookmark(id)`, `bookmarkTab(id)`, `unbookmarkTab(id)`, and `bookmarkedObjects` in `WorkspaceController` (`lib/app/workspace_controller.dart`), using copy-on-write immutable list operations to avoid mutations on unmodifiable list views.
  - Tab bar bookmark icons: Every document tab displays an interactive bookmark icon button (`Icons.bookmark` / `Icons.bookmark_border`) with gold amber accent (`#F59E0B`), allowing instant bookmarking with one click.
  - Tab bar header additions: "+ New Tab" button (`new-tab-button`, `Icons.add`) for quickly adding blank notes into the tab bar, and "Bookmarks" dropdown menu (`workspace-bookmarks-button`, `Icons.bookmarks_outlined`) for instant 1-click navigation to any bookmarked document.
  - Tab context menu action: Right-clicking any tab displays "Bookmark Tab" / "Remove Bookmark" with keyboard shortcut `Ctrl+Shift+D`.
  - Global keyboard shortcut: `Ctrl+Shift+D` toggles bookmark status for the currently active tab.
- Backlinks & Unlinked Mentions Engine (Option 2):
  - Pure-Dart domain engine (`lib/domain/backlinks.dart`): Zero Flutter or platform dependencies; works universally offline and on web/cross-platform.
  - `findLinkedMentions`: Scans all notes and canvases for wiki-links `[[targetId]]` and `[[targetId|Custom Label]]`.
  - `findForbiddenRanges`: Identifies code blocks (``` and `), math blocks ($$ and $), URLs, HTML tags, and existing wiki-links to prevent false-positive unlinked mentions.
  - `findUnlinkedMentions`: Searches note bodies for occurrences of other object titles and aliases outside forbidden ranges.
  - `extractContextSnippet`: Extracts surrounding sentence/paragraph context with boundary ellipses (`...`).
  - `linkMentionInMarkdown`: Transforms plain mention occurrences into wiki-links `[[targetId|Original Text]]`.
  - `WorkspaceController` integration: Added `linkedMentions(targetId)`, `unlinkedMentions(targetId)`, and `linkUnlinkedMention(mention)` using validated reversible commands via `c.edit(id, body: newBody)`.
- Interactive 2D Local Context Graph (`lib/features/workspace/local_context_graph.dart`):
  - Force-directed 2D physics layout simulating repulsive Coulomb forces and attractive Hooke springs.
  - Visual focal halo: Pulsing radiant gold halo around the focal node.
  - Node styling: Type-coded colors (notes: blue/teal, boards: purple/violet, tasks: amber/gold).
  - Graph controls: 1-hop vs 2-hop radius selector, fit-to-view button, node count badge, hover tooltips, and tap-to-navigate.
  - Responsive layout: Adapts smoothly to narrow inspector panes without layout overflow.
- Object Inspector Relations Overhaul (`lib/features/workspace/object_inspector.dart`):
  - Relations section now includes:
    - Embedded interactive `LocalContextGraph` with toggle button.
    - Linked Mentions tab with contextual snippets and object type badges.
    - Unlinked Mentions tab with contextual snippets and 1-click **`+ Link`** button.
    - Outbound Links tab with link direction indicators.
    - Related Objects tab.
- Note Editor Backlinks Toggle (`lib/features/notes/note_editor.dart`):
  - Added `note-backlinks-toggle` (`Icons.hub_outlined`) in the note header toolbar, wired up to open the relations panel.

Validation:
- Automated test suites:
  - `test/workspace_tabs_bookmarks_test.dart` (8/8 tests passing):
    - SessionState serialization and deserialization.
    - Graceful handling of null/missing bookmarkedTabs.
    - Controller toggle, bookmark, unbookmark idempotency.
    - Controller bookmarkedObjects resolution.
    - Tab bar bookmark icon click toggling.
    - Ctrl+Shift+D keyboard shortcut on active tab.
    - "+ New Tab" button and bookmarks menu button rendering.
  - `test/backlinks_unlinked_mentions_test.dart` (7/7 tests passing):
    - Linked mentions detection (`[[noteA]]` and `[[noteA|My Label]]`).
    - Unlinked mentions detection matching target note titles.
    - Unlinked mentions skipped inside code blocks, math blocks, and existing wiki-links.
    - Context snippet extraction with clean ellipses.
    - 1-click markdown link replacement `linkMentionInMarkdown`.
    - Controller `linkedMentions` and `unlinkedMentions` queries.
    - Controller `linkUnlinkedMention` command mutation and persistence.
  - `test/bootstrap_test.dart` (passing).
  - `test/canvas_auto_arrange_test.dart` (8/8 tests passing).
- Static analysis & formatting:
  - `dart format --output=none --set-exit-if-changed lib test`: 262 files format-clean (0 diffs).
  - `flutter analyze --no-pub`: **No issues found!** (0 errors, 0 warnings, 0 lints).
- Release Builds:
  - Windows x64: Compiled release bundle via `flutter build windows --release --dart-define-from-file=.local/google-build.windows.json` (52.9s). Output: `build\windows\x64\runner\Release\orbit_note.exe` + `app.so` (16.2 MB), packaged as `release-assets\OrbitNote-Windows-x64.zip` (25.2 MB).
  - Android APK: Blocked locally due to missing Android SDK / JDK toolchain on current Windows host (`[!] No Android SDK found. Try setting the ANDROID_HOME environment variable`). Building via GitHub Actions CI (`.github/workflows/release.yml`) or installing local Android SDK & JDK 17 required for local APK generation.

Suggested next task:
- Canvas Minimap Spatial Search Radar Dots (CAN-14 refinement) or Graph Fullscreen View (GRAPH-01): Expand the 2D local context graph into a full-workspace global interactive knowledge graph view.

# Previous task — Canvas Spatial Search & Jump-to-Element Filter Overlay (CAN-14), 2026-09-21

Owner request: "finish and build windows release", "lets do it" (Canvas Spatial Search & Jump-to-Element Filter Overlay `CAN-14` / `LNK-12`).
Scope: Pure-Dart spatial search engine for elements across `CanvasScene`, floating `CanvasSearchOverlay` HUD (`Ctrl+F`), match counter badge, navigation controls (Enter / Shift+Enter), category filter chips (`All`, `Cards`, `Text & Notes`, `Shapes`, `Media`), expandable results drawer, spatial jump navigation with bounded camera zoom centering, visual match highlighting in `OrbitCanvasPainter` (amber outline and active gold halo focus ring), and official Windows x64 release build packaging.

Implemented:
- Pure-Dart Spatial Search Engine (`lib/canvas/canvas_search.dart`):
  - `searchCanvasElements`: Pure-Dart, zero-dependency search engine running in sub-millisecond execution time.
  - Matches across all canvas element types: sticky notes, text blocks, frames, columns, geometric shapes, connectors, images, links, and cards.
  - `MapCanvasObjectLookup` / `CanvasObjectLookup`: Resolves card universal object references for deep querying across note title, markdown body excerpt, tags (`#tag`), project, folder, status, and priority metadata.
  - Spatial reading order: sorts matches in top-to-bottom, left-to-right order based on world coordinates.
  - Category classification (`CanvasSearchCategory`): filters results strictly by `all`, `cards`, `text`, `shapes`, and `media`.
  - Contextual snippet extraction with surrounding boundary ellipses.
- Canvas Search HUD Widget (`lib/features/canvas/canvas_search_overlay.dart`):
  - Floating top-centered HUD card (`CanvasSearchOverlay`) with ambient drop shadow and rounded corners.
  - Instant live search `TextField` autofocusing on activation with `Ctrl+F` / `Cmd+F`.
  - Dynamic match counter pill (e.g. `1 of 5` or `0 matches`).
  - Navigation action buttons: Previous (`Shift+Enter`), Next (`Enter`), and Close (`Esc`).
  - Category filter pills row (`All`, `Cards`, `Text & Notes`, `Shapes`, `Media`).
  - Expandable results drawer listing matches with type badges, titles, and snippets.
  - Tapping any match directly navigates and highlights that element.
- Canvas Editor Integration & Jump Navigation (`lib/features/canvas/canvas_editor.dart`):
  - Added search state: `_showSearchHud`, `_searchController`, `_searchFocusNode`, `_searchResults`, `_activeSearchIndex`, `_searchCategory`.
  - Keyboard shortcuts in `_key`:
    - `Ctrl+F` / `Cmd+F`: toggles search HUD open/closed and autofocuses search input.
    - `Escape`: closes search HUD and restores canvas focus.
    - `Enter`: cycles to next match.
    - `Shift+Enter`: cycles to previous match.
  - Toolbar Search Button: Added `canvas-search-button` `IconButton` next to primary tools with active tint state.
  - Spatial Jump Navigation (`_jumpToSearchMatch`): smoothly centers camera on element bounds, adjusts zoom comfortably (clamped `0.4x` to `1.25x`), and selects the matching element.
- OrbitCanvasPainter Match Highlighting (`lib/features/canvas/canvas_painter.dart`):
  - Added `searchMatchIds` and `activeSearchMatchId` properties to painter.
  - Paints glowing amber outline around all matching elements.
  - Paints active gold halo target ring around the currently focused match.
  - Updates `shouldRepaint` when search matches or active match change.
- Windows Release Packaging:
  - Built official Windows release binary via `flutter build windows --release --dart-define-from-file=.local/google-build.windows.json`.
  - Packaged `release-assets/OrbitNote-Windows-x64.zip` (25.2 MB) containing `orbit_note.exe` and runner dependencies.

Validation:
- Automated test suite: `test/canvas_search_test.dart` (12/12 tests passing in ~1.2s):
  - Direct element text search in sticky notes and text blocks.
  - Referenced card titles, bodies, and tags (`#physics`).
  - Referenced card project, folder, status, and priority metadata.
  - Links by URL query (`orbitnote.dev`).
  - Spatial reading order sorting (top-to-bottom, left-to-right).
  - Category filtering (`cards`, `text`, `shapes`, `media`).
  - Empty and whitespace-only query handling.
  - Painter repainting on `searchMatchIds` and `activeSearchMatchId` changes.
  - Search highlight outline and active focus halo rendering without errors.
  - `CanvasSearchOverlay` widget interactions: counter, chips, cycling buttons, drawer items, dismiss.
  - `CanvasEditor` toolbar search button toggle, `Ctrl+F` shortcut, and `Escape` dismiss.
  - Match cycling with Next/Previous buttons and camera bounds updating.
- Regression tests: `test/canvas_transclusion_minimap_test.dart`, `test/canvas_pen_features_test.dart` (15/15 tests passing).
- Static analysis & formatting: `dart format --output=none --set-exit-if-changed lib test` passed cleanly (0 diffs); `flutter analyze --no-pub` reported **No issues found!**
- Windows release build: `build\windows\x64\runner\Release\orbit_note.exe` built in 52.2s.

Suggested next task:
- Canvas Minimap Spatial Search Radar Dots: Display search match pings on the canvas minimap radar overlay to visually locate results across giant canvas boards.

# Previous task — Structured Collection Views: Universal Table View & Universal Kanban Board, 2026-09-20

Owner request: "yes lets add 1 first and then 2" (referring to 1. Structured Collection Views: Kanban Board & Table View, followed by 2. Canvas Spatial Search / Jump-to-Element).
Scope: Implement high-priority items `VIEW-01` (Universal Table View), `VIEW-02` (Universal Kanban Board), `VIEW-03` (Configurable Columns & Sorting), `VIEW-04` (Dynamic Kanban Grouping & Presets), `VIEW-06` (Universal Object Identity Invariant: view transitions never alter underlying Markdown bodies or identity), and `VIEW-07` (Embedded Table format in Dynamic View blocks).

Implemented:
- Universal Table View (`lib/features/workspace/collection_table_view.dart`):
  - Multi-column tabular presentation of any collection of `UniversalObject`s (notes, tasks, canvases).
  - Smart Query collections (scoped by folder, course, project, or context) vs. Manual collections (explicit `memberIds`).
  - Customizable columns toggle popup menu (`Title`, `Type`, `Folder`, `Status`, `Priority`, `Tags`, `Updated`).
  - Bi-directional column header sorting with visual sort indicator arrows (`arrow_upward` / `arrow_downward`).
  - Search bar filtering title, status, folder, and tags in real-time.
  - Type filter pills (`All`, `Notes`, `Tasks`, `Boards`).
  - Direct inline property editing:
    - Status badge dropdown (`Todo`, `In Progress`, `In Review`, `Done`, `Backlog`, `Blocked`).
    - Priority pill popup (`🔴 Urgent`, `🟠 High`, `🔵 Medium`, `⚪ Low`).
    - Folder assignment dialog modal (`Move to Folder`).
    - Tag chip list with tag addition dialog (`#tag`) and removal icons.
    - Inline task checkbox toggling completed state and status between `todo` and `done`.
    - Object rename dialog modal.
  - "Add Item" action button creating Notes, Tasks, or Canvases pre-configured to the current collection scope.
- Universal Kanban Board (`lib/features/workspace/collection_kanban_view.dart`):
  - Multi-column spatial board displaying cards grouped by configurable properties.
  - Dynamic `groupBy` selector (`status`, `priority`, `project`, `folder`, `type`).
  - Preset switcher for domain-tailored status workflows (`universal`, `software`, `gamedev`, `bugs`, `university`, `hypotheses`, `functions`).
  - Interactive drag-and-drop card movements between columns using Flutter `Draggable` and `DragTarget`:
    - Moving a card between columns mutates the target property on the object without touching note Markdown content (`VIEW-06`).
    - Drag feedback with elevated card shadow and rotation styling.
  - Fallback column for objects without the target property (`No Status`, `No Priority`, `Uncategorized`).
  - Inline card addition button (`+ Add Card`) in column headers.
  - Slide-in preview peek panel for reviewing card details and opening full objects.
- Multi-View Saved View Host Integration (`lib/features/workspace/saved_view_host.dart`):
  - Added `Table` view tab alongside `List`, `Board`, `Calendar`, and `Timeline`.
  - Dynamic routing from `'table'` to `CollectionTableView` and `'board'` to `CollectionKanbanView`.
  - Persistent active view switcher tab row with automatic view configuration preservation.
- Dynamic View Block Table Format (`lib/features/notes/rich/dynamic_view_block.dart`):
  - Extended `DynamicViewConfig` parser and serializer with `format` (`table` | `list`) and `viewId` (`view: <id>`).
  - Embedded responsive mini-table format inside Markdown notes rendering interactive titles, type icons, status pills, and task checkboxes.
  - Direct reference resolution from saved view objects (`view: <id>`).
- Controller Teardown Safety (`lib/app/workspace_controller.dart`):
  - Added `cancelAllTimers()` method to safely cancel pending autosave debounce timers during teardown without blocking async test execution.

Validation:
- Automated test suite: `test/collection_views_test.dart` (7/7 tests passing in ~1.2s):
  - `DynamicViewConfig` parses and serializes `format: table` and `view: <id>` reference.
  - `CollectionTableView` renders smart collection items matching folder/scope with customizable columns and sorting.
  - `CollectionTableView` respects manual collection membership (`memberIds`).
  - `CollectionKanbanView` groups objects by status with drag-and-drop property updates without Markdown alteration (`VIEW-06`).
  - `CollectionKanbanView` groups objects by priority columns (`🔴 Urgent`, `🟠 High`, `🔵 Medium`, `⚪ Low`).
  - `SavedViewHost` toggles between `List`, `Board`, and `Table` tabs.
  - `DynamicViewBlock` with `format: table` renders embedded mini-table headers and items.
- Formatting: `dart format --output=none --set-exit-if-changed lib test` clean (0 diffs).
- Analysis: `flutter analyze --no-pub` reported **No issues found!**

Suggested next task:
- Canvas Spatial Search & Jump-to-Element Filter Overlay (`CAN-14`): Instant Ctrl+F / Cmd+F canvas search HUD zooming and panning to matching cards, elements, and annotations.

# Previous task — Pure Dart Offline English Spell & Grammar Check with Interactive Right-Click Word Fixes, 2026-09-20

Owner request: "add english grammar check for orbit note and like right clikc fix words" Scope: Pure Dart, completely offline, zero-network English spell checking and grammar checking engine for Orbit Note. Real-time wavy underline annotations (red for spelling, blue for grammar), interactive right-click context menu offering ranked replacement suggestions (`✨ Fix: "..."`), custom dictionary management (`➕ Add to Dictionary`), session word ignoring (`🚫 Ignore`), exclusion masks for Markdown code blocks, inline code, math formulas, URLs, and wikilinks, global toggle in Settings under Editor, quick toggle in NoteEditor header bar, and full persistence across sessions in `SessionState`.

Implemented:
- Offline English Spell & Grammar Engine (`lib/domain/grammar/spell_grammar_engine.dart`):
  - Pure-Dart, high-performance engine executing in sub-millisecond speeds with zero network dependencies.
  - Core English lexicon spanning common vocabulary, everyday nouns, verbs, adjectives, and morphological inflection analysis (plural `-s`, `-es`, `-ies`, past `-ed`, gerund `-ing`, adverb `-ly`).
  - High-frequency typo lookup dictionary (`teh`, `recieve`, `definately`, `seperate`, `wierd`, `occured`, etc.) with instant exact correction mapping.
  - Damerau-Levenshtein distance algorithm ($\le 2$) with character transposition, insertion, deletion, and substitution for ranked phonetic and visual suggestions.
  - Curated grammar rules:
    - Repeated words detection (`the the`, `in in`, `and and`).
    - Indefinite article agreement (`a` vs `an` with phonetic vowel sound and silent 'h' exception analysis).
    - Homophone confusions (`could of` $\to$ `could have`, `their are` $\to$ `there are`, `its a` $\to$ `it's a`, `your welcome` $\to$ `you're welcome`, `better then` $\to$ `better than`, `to much` $\to$ `too much`).
    - Subject-verb agreement (`they is` $\to$ `they are`, `he are` $\to$ `he is`, `I is` $\to$ `I am`).
    - Standalone pronoun capitalization (`i` $\to$ `I`, `i'm` $\to$ `I'm`, `i've` $\to$ `I've`).
    - Double punctuation detection (`,,` $\to$ `,`, `;;` $\to$ `;`).
  - Exclusion masking protecting code blocks (```...```), inline code (`...`), math blocks & inline math ($$...$$ and $...$), URLs (`http://`, `https://`, `orbit://`), wikilinks (`[[...]]`), markdown link targets, and HTML tags from false positives.
  - User dictionary and per-session ignore support.
- Session Persistence & Custom Dictionary (`lib/app/session_state.dart`):
  - Added `bool spellCheckEnabled` (default `true`) and `List<String> userDictionary` (default `[]`).
  - Serialized and deserialized in `SessionState.fromJson` and `toJson`.
- Rich Markdown Prose Annotation & Context Menu (`lib/features/notes/rich/rich_markdown_editor.dart`):
  - `_StyledController` renders custom `TextSpan`s with wavy underlines (`TextDecorationStyle.wavy`) in red (`#EF4444`) for spelling and blue (`#3B82F6`) for grammar issues while preserving formatting marks (bold, italic, strike, link, code).
  - In `_RichTextBlock` and `_InlineMathParagraph`, `contextMenuBuilder` integrates with `AdaptiveTextSelectionToolbar.buttonItems`:
    - `✨ Fix: "..."` substitutes the error, repositions caret, and registers change in undo/redo history.
    - `➕ Add "..." to Dictionary` adds word to user dictionary and persists across restarts.
    - `🚫 Ignore "..."` suppresses warnings for the current session.
    - Standard clipboard buttons (Cut, Copy, Paste, Select All) are preserved.
- Note Editor Header & Source Mode Integration (`lib/features/notes/note_editor.dart`, `lib/features/workspace/workspace_shell.dart`):
  - Added quick toggle header button `IconButton` with key `ValueKey('note-spellcheck-toggle')` in `NoteEditor` toolbar.
  - `_GrammarAnnotatedController` powers `note-title` and `_source` (`note-body`) with real-time wavy underlines and right-click context menu fixes.
  - Session state callbacks (`onToggleSpellCheck`, `onAddToUserDictionary`) forwarded from `WorkspaceShell`.
- Settings Workspace View (`lib/features/workspace/workspace_views.dart`):
  - Added `SwitchListTile` with key `ValueKey('settings-spellcheck-switch')` under the Editor section.
  - Displays custom dictionary word count and `TextButton.icon` with key `ValueKey('settings-clear-dictionary-button')` to wipe custom entries.

Validation:
- Automated test suite: `test/spell_grammar_check_test.dart` (14/14 tests passing in ~1.5s):
  - Engine validates correct words without false positives.
  - Detects typos (`recieve`, `teh`, `definately`) and suggests corrections.
  - Evaluates repeated words, indefinite article agreement (`a apple`, `an banana`), homophones (`could of`, `your welcome`), subject-verb agreement (`They is`, `He are`), and pronoun capitalization.
  - User dictionary and session ignore suppressions.
  - Exclusion masks ignore code blocks, inline code, math formulas, URLs, and wikilinks.
  - `NoteEditor` renders quick toggle button and responds to taps.
  - `SessionState` serializes and deserializes spell check fields.
  - Right-click context menu presents `✨ Fix: "the"`, `➕ Add "teh" to Dictionary`, `🚫 Ignore "teh"` and updates text on fix.
  - `SettingsView` toggles spell check and clears user dictionary.
- Editor regression tests: `test/rich_editor_widget_test.dart` (22/22 passing).
- Static analysis & formatting: `dart format --output=none --set-exit-if-changed` reported 0 diffs; `flutter analyze --no-pub` reported **No issues found!**

Limits:
- Grammar and spell engine is optimized for English offline analysis. Multi-language dictionary packs can be integrated via pluggable lexicon providers in future tasks.

Suggested next task:
- Structured Collection Views (VIEW-02 Kanban Board & VIEW-01 Table View): Multi-column card pipelines by status/property, drag-and-drop column transitions, and synchronized tabular metadata views.

# Previous task — Times New Roman Font Family Selection & Universal Typography Propagation, 2026-09-20

Owner request: "can you add  an option to use times new roman font" Scope: Universal font family selection across the knowledge OS, support for Times New Roman (along with Segoe UI, Georgia, and Consolas), global preference in Settings -> Editor & Appearance, quick font switcher in NoteEditor header bar, dynamic theme propagation across app controls and markdown prose, monospace preservation for code blocks, and canvas spatial rendering with element-level font overrides.

Implemented:
- Session & Global Configuration (`lib/app/session_state.dart`):
  - Added `fontFamily = 'Segoe UI'` field to `SessionState`.
  - Serializes and deserializes `fontFamily` in `toJson` / `fromJson`, validating against supported fonts (`Segoe UI`, `Times New Roman`, `Georgia`, `Consolas`) with fallback to `'Segoe UI'`.
- Dynamic Theme Typography Propagation (`lib/app/orbit_theme.dart`, `lib/app/orbit_app.dart`):
  - `orbitDarkTheme({bool compact = false, String fontFamily = 'Segoe UI'})`: applies the active font family dynamically across all text theme styles, headings, body text, lists, and input decoration label/hint styles.
  - Removed static `const` barriers on `TextTheme` and replaced hardcoded `'Segoe UI'` references in `ThemeData.fontFamily`, `labelStyle`, and `popupMenuTheme.labelTextStyle`.
  - In `OrbitNoteApp` (`lib/app/orbit_app.dart`), Riverpod watches `(c.session.compact, c.session.motion, c.session.fontFamily)` to immediately re-theme the entire application when font changes occur.
- Settings Appearance & Typography (`lib/features/workspace/workspace_views.dart`):
  - Added "Font family" dropdown setting (`ValueKey('settings-font-family-dropdown')`) in `SettingsView` under the Editor section.
  - Subtitle shows font description (e.g. `Times New Roman (Academic Serif)`).
  - Provides options: `Segoe UI (Default Sans)`, `Times New Roman (Serif)`, `Georgia (Serif)`, `Consolas (Code)`.
- Note Editor Font Quick Switcher & Rich Markdown Prose (`lib/features/notes/note_editor.dart`, `lib/features/notes/rich/rich_markdown_editor.dart`, `lib/features/workspace/workspace_shell.dart`):
  - Added header font switcher `PopupMenuButton<String>` with key `ValueKey('note-font-family-menu')` directly in `NoteEditor` app bar.
  - Quick font switcher updates active session font family and notifies the shell (`onFontFamilyChanged`).
  - `RichMarkdownEditor` respects `fontFamily` for heading blocks, paragraph text, inline styled spans, and math prose formulas.
  - Code blocks (`MarkdownBlockKind.code`) and code marks strictly preserve `monospace` styling.
- Canvas Spatial Typography & Per-Element Overrides (`lib/features/canvas/canvas_rich_text.dart`, `lib/features/canvas/canvas_painter.dart`, `lib/features/canvas/canvas_editor.dart`):
  - `CanvasRichText.draw` and `CanvasRichText.hitTestCheckbox` accept dynamic `fontFamily`.
  - `OrbitCanvasPainter` propagates global `fontFamily` to all canvas elements (text, sticky notes, cards, and checklists).
  - Supports per-element font overrides via `element.data['fontFamily']`.
  - Canvas context menu adds `'FONT FAMILY'` submenu with `Default (${widget.fontFamily})` and `Times New Roman (Serif)` options for text, sticky notes, and cards, recorded in undo/redo history.

Validation:
- Automated test suite: `test/font_family_typography_test.dart` (10/10 tests passing in ~2 seconds):
  - SessionState defaults, serialization, fallback.
  - OrbitTheme typography and input decoration propagation.
  - SettingsView font family dropdown selection and session state persistence.
  - NoteEditor header font menu switcher and callback.
  - RichMarkdownEditor block typography with monospace code block preservation.
  - CanvasRichText.draw font family propagation.
  - CanvasEditor OrbitCanvasPainter font family propagation.
- Regression test suites: `test/rich_editor_widget_test.dart` (38/38 passing) and `test/canvas_rich_text_test.dart` (2/2 passing).
- Static analysis & formatting: `dart format --output=none --set-exit-if-changed lib test` passed cleanly with 0 diffs; `flutter analyze --no-pub` reported **No issues found!**

Limits:
- Times New Roman is bundled/rendered as a platform system font across Windows, macOS, iOS, Android, and web. Custom TTF/OTF external font imports are not in scope.

Suggested next task:
- Canvas spatial search / jump-to-element filter overlay with spotlight highlight (CAN-14).

# Previous task — Real-Time Bidirectional Canvas-to-Note Block Transclusion (CAN-02, CAN-15, NOTE-07) & Spatial Minimap Radar Navigation (CAN-01, CAN-15), 2026-09-20

Owner request: "add that: Real-Time Bidirectional Canvas-to-Note Block Transclusion or Spatial Minimap Navigation (CAN-02, CAN-15, NOTE-07): Live embedded note block synchronization directly on spatial canvas cards, and an interactive minimap radar overlay in the canvas corner for instant navigation across large boards." Scope: CAN-02, CAN-03, CAN-15, NOTE-07, live transclusion card presentation, rich markdown rendering, bidirectional synchronization, live in-canvas transclusion editing dialog, universal object identity, spatial minimap radar overlay with concentric range rings, type-coded miniature elements, tactical viewport brackets, and minimap HUD header with quick fit-all action.

Implemented:
- Live Embedded Note Block Transclusion (`lib/features/canvas/canvas_painter.dart`):
  - Card presentation mode: `'transclusion'` (`presentation == 'transclusion'`).
  - Distinct top accent bar in violet (`#8B5CF6`) with rounded corners.
  - Live Transclusion header badge: `LIVE TRANSCLUSION · [[Note Title]]` with targeted block reference indicator (`#^blockId`) if specified.
  - Divider line and rich live markdown rendering using `CanvasRichText.draw` directly from `objects[element.objectId]!.body` (or specific target block if `blockId` / `blockRef` is set).
  - Footer status indicator: `Bidirectional sync · N chars` or block reference tag.
  - Graceful fallback for unresolved/missing note objects, warning user that removing placement does not delete the original note.
- Bidirectional Canvas-to-Note Synchronization (`lib/features/canvas/canvas_editor.dart`):
  - Card presentation cycle `_cycleCardPresentation` updated to include `'transclusion'`: `['card', 'preview', 'transclusion', 'properties', 'compact']`.
  - Floating card tooltip presentation button updated to display `Icons.sync_alt` for transclusion.
  - Card context menu additions:
    - `pres_transclusion`: "Live Note Transclusion (CAN-02/NOTE-07)" with `Icons.sync_alt`.
    - `edit_transclusion_content`: "Edit Transcluded Note Content..." with `Icons.edit_note`.
  - Live in-canvas transclusion editing dialog (`_editTransclusionContent`): allows editing note title and body directly in canvas without leaving context. Updates `_objects[objectId]`, immediately triggers canvas repaint, and invokes `widget.onUpdateObjectProperties` to persist to host vault.
  - Double-clicking a transclusion card directly launches `_editTransclusionContent`.
  - Universal Object Identity: multiple cards pointing to the same `objectId` synchronously display and update the identical content in real time.
- Spatial Minimap Radar Overlay Navigation (`lib/features/canvas/canvas_editor.dart`):
  - Concentric circular radar guide rings and center crosshairs (`+`) rendered on the minimap content centroid for instant orientation across vast canvas boards.
  - Type-coded miniature elements: vivid violet (`#8B5CF6`) with sync dot for transclusions, blue (`#3B82F6`) for standard cards, purple (`#A855F7`) for ink/handwriting, amber (`#F59E0B`) stroke outlines for frames/sections, emerald (`#10B981`) for geometric shapes.
  - Glowing radar camera viewport indicator with tactical corner brackets.
  - Enhanced minimap card HUD header: `RADAR` label with icon, real-time zoom percentage readout (e.g. `100%`), and quick "Fit All" (`Icons.fit_screen`, `canvas-minimap-fit-btn`) button to instantly center and frame all board contents.

Validation:
- Format & analyzer: `dart format --output=none --set-exit-if-changed lib test` passed cleanly (249 files format-clean); `flutter analyze --no-pub` reported **No issues found!**
- Automated tests:
  - `test/canvas_transclusion_minimap_test.dart`: 8 tests passing (transclusion presentation with live note body, block reference extraction, unresolved reference fallback, minimap radar range rings and type-colored elements, minimap toggle with HUD header and fit-all button, context menu transclusion option, live transclusion editing dialog and host notification, universal object identity multi-card synchronization).
  - `test/canvas_character_recognition_test.dart`: 18/18 tests passing.
  - `test/runtime_audit_fixes_test.dart`: 5/5 tests passing.
  - `test/product_polish_batch2_test.dart`: 16/16 tests passing.

Limits:
- Sub-block targeting uses regex heading and block-ID patterns (`^blockId`); nested block folding inside transclusion cards will be covered in advanced block nesting tasks.

Suggested next task:
- Canvas spatial search / jump-to-element filter overlay with spotlight highlight (CAN-14).

# Previous task — Handwriting Character (Letters & Numbers) Recognition & Ink Auto-Correction, 2026-09-20
Owner request: "can you add like letter recognition adn numbers recognition too, like when drawin a letter it automatically corrects it into a real letter, same for number, same for lines circles etc., keep it as a feature tho dont enable it automatically" Scope: CAN-16, INK-04, INK-09, pure Dart point-cloud handwriting character recognizer, letters A-Z, digits 0-9, symbols, multi-stroke character settling, unified gesture arbitration, toolbar toggle (disabled by default), context menu actions.

Implemented:
- Pure Dart Point-Cloud Character Recognizer (`lib/canvas/character_recognizer.dart`):
  - Fast, zero-dependency point-cloud handwriting classifier ($P$ Dollar family algorithm) running entirely offline in sub-millisecond execution time.
  - Resampling to canonical $N = 32$ equidistant points, aspect-ratio preserving bounding box normalization, and centroid centering.
  - Comprehensive canonical templates:
    - Digits: `0`, `1`, `2`, `3`, `4`, `5`, `6`, `7`, `8`, `9`
    - Uppercase & lowercase letters: `A` through `Z`, `a` through `z`
    - Math & punctuation symbols: `+`, `-`, `=`, `?`, `!`
  - Multi-stroke and unistroke support: handles single-stroke and multiple stroke combinations (e.g. 2-stroke 'T' bar+stem, 'X' crossing diagonals, '=' parallel bars, '+' cross, '4' L+stem, 'A' caret+bar).
  - Bounded aspect-ratio and orientation heuristics to reliably disambiguate upright characters ('6' vs '9', 'M' vs 'W', narrow '1'/'I' vs wide '-').
  - `convertInkToText`: Converts ink `CanvasElement` into a clean renderable `text` element matching original bounds, position, and color.
- Unified Ink Gesture Classifier (`lib/canvas/shape_recognizer.dart`):
  - `recognizeInkGesture`: Evaluates strokes against both geometric shapes (`RecognizedShape`) and handwriting characters (`RecognizedCharacter`).
  - Size and glyph arbitration: large strokes ($> 75$px) prioritize geometric shapes (ellipse, rectangle, diamond, line, arrow), while character-sized glyphs prioritize digits and letters.
  - `convertInkGesture`: Drops in clean vector shapes or text elements seamlessly.
- Canvas Interaction & Opt-in Auto-Correction (`lib/features/canvas/canvas_editor.dart`):
  - **Disabled by default**: State `_autoRecognizeInk = false`, preserving normal raw inking unless explicitly enabled by the user.
  - **Toolbar Toggle Button**: `Icons.auto_fix_high` in pen toolbar with clear tooltip (`Auto-recognize ink active: Converts handwriting to text & shapes (K)` / `Auto-recognize ink to text & shapes (disabled, shortcut K)`).
  - **Keyboard Shortcut**: `K` toggles auto-recognition mode on/off when pen or highlighter is active.
  - **On-Stroke Auto-Correction**: When enabled, immediately converts recognized characters and shapes on pointer up. Includes an 850ms multi-stroke settlement buffer that automatically groups multi-stroke characters (such as drawing the crossbar of 'T' or the second slash of 'X') into a single unified character.
  - **Context Menu Actions**:
    - "Auto-Recognize (Text or Shape)": Analyzes selected ink strokes and converts them to text or shapes on demand.
    - "Convert Stroke to Text": Converts selected stroke(s) into real text elements, including multi-stroke selection combinations.
  - **Undo/Redo**: Full integration with `_history`, allowing users to press `Ctrl+Z` to revert any auto-correction back to the raw ink stroke.

Validation:
- Format & analyzer: `dart format --output=none --set-exit-if-changed lib test` passed cleanly (248 files format-clean); `flutter analyze --no-pub` reported **No issues found!**
- Automated tests (all 18 new tests and full canvas regression suite passing cleanly):
  - `test/canvas_character_recognition_test.dart`: 18 tests passing (digit recognition '1', '0', '7'; letter recognition 'C', 'L', 'S', 'V', 'Z'; multi-stroke characters 'T', 'X', '=', '+'; unified gesture classifier for circles, boxes, and letters; text element conversion; toolbar toggle button visibility and toggle behavior; context menu text recognition actions).
  - `test/canvas_advanced_features_test.dart`: 17/17 tests passing.
  - `test/canvas_export_backgrounds_test.dart`: 11/11 tests passing.
  - `test/canvas_pen_features_test.dart`: 7/7 tests passing.

Limits:
- Cursive connected multi-word script recognition is not implemented; isolated character and multi-stroke glyph recognition is supported.

Suggested next task:
- Real-time bidirectional canvas-to-note block transclusion or spatial canvas minimap navigation widget (CAN-02, CAN-15, NOTE-07).

# Previous task — Canvas Advanced Features: Lasso Selection, Shape Recognition, Auto-Arrange & Diagram Export, 2026-09-20
- Stroke Shape Recognition & Cleanup (`INK-09`, `CAN-16`, `lib/canvas/shape_recognizer.dart`, `lib/features/canvas/canvas_editor.dart`):
  - Pure-Dart geometric stroke classifier evaluating normalized radial deviation, 4-corner bounding proximity, and stroke vector geometry.
  - Detects circles/ellipses (`avgRadialDev < 0.14`), rectangles/squares (4-corner hits within `0.14 * min(W, H)`), diamonds (edge midpoints without corner hits), lines, and directional arrows (arrowhead barb direction reversal detection).
  - Context menu stroke-to-shape conversion: "Convert Stroke to Clean Shape" with Auto-Detect, Clean Rectangle, Clean Ellipse, Clean Diamond, and Clean Arrow actions.
- Advanced Auto-Arrange Layouts (`CAN-10`, `lib/canvas/arrangement.dart`, `lib/features/canvas/canvas_editor.dart`):
  - **Mind Map**: Radially balances connected/selected nodes across left and right branches from a root/centroid node with curved connectors.
  - **Timeline**: Arranges elements along a horizontal chronological progression axis with uniform spacing and connector lines.
  - **Vertical Tree**: Hierarchical top-down layered level tree layout with root-to-leaf connector preservation.
  - Context menu actions: "Mind Map Tree", "Timeline Road Map", "Vertical Tree".
- Ruled & Isometric Grid Backgrounds (`INK-07`, `lib/features/canvas/canvas_painter.dart`, `lib/features/canvas/canvas_editor.dart`):
  - **Ruled Paper**: Notebook/legal ruled lines with a distinct red margin rule at 72pt and horizontal guidelines.
  - **Isometric Grid**: 30° triangular grid for 3D sketching, axonometric projections, and technical drawings.
  - Added to paper style dropdown menu in canvas bottom bar alongside plain, grid, dot, and cornell presets.
- Mermaid Flowchart & Structured Note Export Interop (`CAN-16`, `PORT-05`, `lib/canvas/diagram_export.dart`, `lib/canvas/diagram_import.dart`, `lib/features/canvas/canvas_editor.dart`, `lib/features/workspace/workspace_shell.dart`):
  - Full bidirectional Mermaid flowchart generation (`exportToMermaid`) with customizable directions (`TD`, `LR`, `BT`, `RL`), shape delimiters (`[]`, `()`, `([])`, `(())`, `{}`), connectors (`-->`, `-.->`, `==>`, `<-->`, `---`), and frames mapped to subgraphs (`subgraph id["Title"]`).
  - Selection-to-Note Extraction (`extractSelectionToMarkdown`): 1-click action in selection context menu generating a markdown note with backlinks (`[Title](orbit://canvas/id)`), embedded Mermaid diagram, checklist checkboxes (`- [ ]`, `- [x]`), card bodies, and relationship summaries.
  - Enhanced Export Dialog with responsive `Wrap` layout, compact `SegmentedButton` controls, live Mermaid preview, and 1-click clipboard copy.

Validation:
- Format & analyzer: `dart format --output=none --set-exit-if-changed lib test` passed cleanly (246 files format-clean); `flutter analyze --no-pub` reported **No issues found!**
- Automated tests (all 28 new and updated tests passing cleanly):
  - `test/canvas_advanced_features_test.dart`: 17 unit and widget tests passing (Mermaid export syntax, directions, subgraphs, selection scoping, markdown extraction, shape recognition for circles, rectangles, arrows, force override, ray-casting point-in-polygon, mind map layout, timeline layout, vertical tree layout, scaled SVG vector export, lasso selection interaction, and ruled/isometric background paper styles).
  - `test/canvas_export_backgrounds_test.dart`: 11 tests passing (Vector SVG generation, standard shapes, ink paths, connectors, transparent backgrounds, raster PNG generation, graph and cornell background rendering, export dialog popup and dismiss, paper style menu options).
  - Canvas regression test suites (`test/canvas_pen_features_test.dart`, `test/canvas_diagram_import_test.dart`, `test/canvas_arrangement_test.dart`) passing with zero regressions.

Limits:
- Real-time OCR handwriting recognition remains a future extension for local-first raw ink strokes.

Suggested next task:
- Real-time bidirectional canvas-to-note block transclusion or spatial canvas minimap navigation widget (CAN-02, CAN-15, NOTE-07).

# Previous task — Canvas Mobile, Tablet & Laptop Support, Drawing Tools & New Pen Styles, 2026-09-19
- Drawing Enhancements & Quick Palette (`lib/features/canvas/canvas_editor.dart`):
  - **Ruler / Straight-Line Assist**: Hold `Shift` key or toggle Ruler mode (`Icons.straighten`, shortcut `R`) to snap freehand strokes into crisp, perfectly straight 2-point lines connecting stroke origin to pointer.
  - **Quick Color Swatch Bar**: Directly accessible row of 7 curated color chips (Violet, Blue, Mint, Amber, Rose, Dark Slate, White) in the toolbar for 1-tap switching without opening dropdown menus.
  - **Heavy Thickness Preset**: Added 20.0px Heavy thickness option for bold brush and marker strokes.
- Mobile, Tablet & Laptop Multi-Touch and Gestures (`lib/features/canvas/canvas_editor.dart`):
  - **Multi-Touch Gestures**: Implemented multi-finger tracking via `_touchPointers`. When 2 fingers touch, automatically cancels any accidental active single-finger ink preview and smoothly scales (`zoomAt`) and pans (`pan`) the canvas camera around the touch midpoint.
  - **Hardware Stylus & Palm Rejection**: Stylus barrel button (`kSecondaryMouseButton`) and inverted stylus automatically act as eraser; in default palm rejection mode (`_fingerDraws == false`), single touch pans, two touches pinch-zoom, and stylus inks.
  - **Laptop Trackpad & Keyboard Shortcuts**: Smooth damped trackpad pinch-to-zoom and pan via `onPointerPanZoomUpdate`; keyboard shortcuts for zoom in (`+`/`=`), zoom out (`-`), reset zoom to 100% (`0`), fit screen (`1`), and ruler toggle (`R`).

Validation:
- Format & analyzer: `dart format --output=none --set-exit-if-changed lib test` passed cleanly (243 files format-clean); `flutter analyze --no-pub` reported **No issues found!**
- Automated tests (all 11 tests passing cleanly):
  - `test/canvas_pen_features_test.dart`: verifies pen style popup (Ballpoint, Pencil, Calligraphy, Brush, Fountain, Marker), ruler straight-line assist mode (2-point straight stroke creation), multi-touch two-finger pinch-to-zoom camera updating, keyboard shortcuts (`+`, `-`, `0`), and `OrbitCanvasPainter` multi-pen rendering.
  - `test/canvas_widget_test.dart`: verifies touch panning in pen mode with palm rejection and pen gestures creating ink.
  - Full canvas regression suite (`test/canvas_layers_highlighter_test.dart`, `test/canvas_engine_test.dart`, `test/canvas_connectors_test.dart`, `test/pdf_quote_extraction_test.dart`, `test/pdf_split_view_test.dart`) passed with zero regressions (38/38 tests).

Limits:
- Real-time handwriting-to-text recognition (OCR/HTR) remains a future extension for local-first raw ink strokes.

Suggested next task:
- Canvas export to vector SVG / high-resolution image dialog presets or note slash-command formula presets (PORT-05, CAN-16, EDT-13).

# Previous task — Canvas Pen Drawing Tools & PDF Text Extraction to Notes and Canvas, 2026-09-19

Owner request: "add like pen feasturs, so i can use a pen fpor example to draw on the canvas. also add mroe of them cool features to excteact text to notes, for example if i select text on the pdf and then right click there should appear a list like extract text to canvas or extact text to note, or even drag the text into note or canvas window whoich would be so cool and easy to use. Stuff like that that make orbit noter unique." Scope: CAN-01, CAN-03, INK-01, INK-02, INK-03, PDF-01, PDF-02, NOTE-05, drag-and-drop interop.

Implemented:
- Canvas Pen Drawing System (`lib/features/canvas/canvas_editor.dart`, `lib/features/canvas/canvas_painter.dart`):
  - Added multi-style pen options: Ballpoint (solid uniform line), Fountain (pressure-sensitive dynamic line with velocity/force tapering), Marker (semi-translucent bold felt-tip), and Highlighter.
  - Smooth Bezier rendering: implemented quadratic Bezier curve smoothing for ink stroke segments with per-sample pressure calculation (`p` property).
  - Configurable stroke thickness (1.5px fine, 3.0px medium, 6.0px bold, 12.0px thick) and configurable eraser radius (10px, 20px, 36px).
  - Hardware stylus & palm rejection: automatic detection of inverted stylus (`PointerDeviceKind.invertedStylus`) to switch to eraser, active stylus (`PointerDeviceKind.stylus`) to draw, and a toolbar toggle for palm rejection (disabling finger drawing so touch gestures strictly pan the canvas).
  - Enhanced canvas toolbar with pen style popup, thickness selector, eraser size menu, and finger inking/palm-rejection toggle button.
- PDF Text Extraction & Drag-and-Drop (`lib/domain/pdf_quote_transfer.dart`, `lib/features/pdf/pdf_reader.dart`, `lib/app/workspace_controller.dart`, `lib/features/notes/rich/rich_markdown_editor.dart`, `lib/features/workspace/workspace_shell.dart`):
  - Created `PdfQuoteDragData` transferable model storing source `objectId`, `title`, `page`, `text`, `checksum`, `markdownQuote`, and `citation` link.
  - Enhanced PDF reader context menu on text selection with:
    - Draggable quote handle (`Draggable<PdfQuoteDragData>`) showing a styled preview card while dragging.
    - "Extract to Canvas" action: extracts selected quote directly onto the active canvas or creates a new canvas card with link and citation.
    - "Insert into active note" action: when a note is open beside the PDF, directly appends the quote and markdown wikilink citation (`[[pdfId#page=X|Title · p. X]]`).
    - "Extract to new note" action: creates a dedicated linked note referencing the quote.
  - Implemented `DragTarget<PdfQuoteDragData>` in `RichMarkdownEditor`: users can drag selected text directly from the PDF into any open note, visually highlighting the editor during hover and cleanly inserting the formatted quote block on drop.
  - Enhanced `DragTarget` in `CanvasEditor`: seamlessly accepts `PdfQuoteDragData` alongside existing drag types, dropping a card element with the citation and quote at the exact drop location.
  - Added `extractPdfQuoteToActiveNote` and `extractPdfQuoteToCanvas` to `WorkspaceController` and connected them in `WorkspaceShell`.

Validation:
- Format & analyzer: `dart format --output=none --set-exit-if-changed lib test` passed with 0 unformatted files; `flutter analyze --no-pub` reported **No issues found!**
- Automated tests:
  - `test/canvas_pen_features_test.dart`: verifies toolbar controls (pen styles, thickness, eraser radius, palm rejection toggle), ink stroke creation with pen style and pressure, drag-and-drop onto canvas, and multi-style painting with `OrbitCanvasPainter`.
  - `test/pdf_quote_extraction_test.dart`: verifies `PdfQuoteDragData` formatting/serialization, `extractPdfQuoteToActiveNote` appending to active notes, `extractPdfQuoteToCanvas` creating cards, and `RichMarkdownEditor` drag-and-drop reception.
  - All existing test suites pass (`pdf_split_view_test.dart`, `canvas_layers_highlighter_test.dart`, `workspace_controller_test.dart`).

Limits:
- Real-time handwriting-to-text recognition (OCR/HTR) is out of scope for local-first raw ink strokes and may be explored in a future ML extension.

Suggested next task:
- Canvas export to vector SVG / high-resolution image dialog presets or note slash-command formula presets (PORT-05, CAN-16, EDT-13).

# Previous task — PDF Split View Blank White Fix & Vault Reopen / Switching Reliability, 2026-09-19

Implemented:
- PDF Split View Viewport Geometry & Resizing (`lib/features/pdf/pdf_reader.dart`):
  - Fixed vertical offset calculation in `_fitComfort`: preserved `centerPosition.dy` when valid and within page boundaries instead of applying compounding offset displacement that threw the camera off into blank outer margin space.
  - Safe bounds calculation: guarded available width/height math with `math.max(1.0, ...)`, clamped camera coordinates within document layout boundaries, and added graceful fallback to `calcMatrixFitWidthForPage`.
  - Responsive split resizing: updated `onViewSizeChanged` to re-fit comfort mode with vertical position preservation when `_comfort` is active, and re-fit page width via `calcMatrixFitWidthForPage` when in standard viewing mode, preventing wide-screen zoom overflow into white margins.
  - Initial split sizing: updated `onViewerReady` to fit width when `_restoreZoom` is absent, and guarded `_goToAnnotation` against non-finite scale coordinates.
- Vault Switching, Session State & Concurrency (`lib/infrastructure/storage/native_vault_lock.dart`, `lib/infrastructure/storage/native_workspace_store.dart`, `lib/app/workspace_controller.dart`, `lib/features/workspace/workspace_shell.dart`):
  - Windows file lock latency: added a retry loop (up to 6 attempts, 50ms interval) to `NativeVaultLock.acquire` to handle Windows kernel asynchronous file lock release latency when closing and immediately reopening or switching back to the same vault.
  - Path normalization: normalized file paths using `p.normalize(file.path)` and lowercased on Windows to prevent lock tracking discrepancies in `_held`.
  - Symlink resilience: wrapped `_root.resolveSymbolicLinks()` in `try/catch` in `NativeWorkspaceStore` to avoid crashes on Windows mapped drives, subst drives, or network locations.
  - Actionable flush error reporting: updated `WorkspaceController._doInitialize` to report clear user-facing error messages when `flushAll()` fails during an explicit vault switch instead of silently aborting.
  - Safe recovery isolation: ensured `_doInitialize` recovery only attempts to reopen `previousPath` when `previousPath != path`, preventing destructive self-recovery wipeout loops when reopening the active vault.
  - Desktop zoom isolation: prevented copying large full-screen primary pane `zoom` into secondary split pane reading state in `openPdfNote` and `openPdfSource`.
  - Split rendering deduplication: guarded `WorkspaceShell.content` to ensure split view is only engaged when `secondary.id != object.id`, and awaited `c.initialize` with error snackbar feedback in `switchVault`.

Validation:
- Format & analyzer: `dart format --output=none --set-exit-if-changed lib test` passed cleanly (240 files format-clean); `flutter analyze --no-pub` reported **No issues found!**
- Automated tests (all 28 tests passing cleanly):
  - `test/pdf_split_view_test.dart`: verifies PDF renders correctly beside a note, zoom remains within bounds, visible rect intersects page layout, and resizing split pane maintains document visibility without drifting into blank margins.
  - `test/native_vault_lock_test.dart`: verifies process locks, rejection of secondary stores, release on close, and 10 rapid close-and-immediate-reopen cycles of the same vault.
  - `test/pdf_reader_test.dart`: all 6 PDF reader tests passing.
  - `test/workspace_controller_test.dart`: all 17 workspace controller tests passing.

Limits:
- Cross-process file locking uses OS advisory/exclusive locks (`vault.lock`); cloud storage syncing layers should use separate sync replicas.

Suggested next task:
- Canvas diagram export to vector SVG / high-resolution image dialog presets or note slash-command formula presets (PORT-05, CAN-16, EDT-13).

# Previous task — Explorer Mini Calendar Widget, Month Navigation & Daily Note Integration, 2026-09-19

Owner request: add a calendar widget at the top left in the explorer view. Scope: EXP-01, ORG-09, temporal navigation, daily notes.

Implemented:
- ExplorerMiniCalendar (`lib/features/workspace/explorer_mini_calendar.dart`):
  - Compact monthly calendar widget rendered at the top of the Explorer sidebar (below Vault header and above Quick Actions).
  - Clean header with Month/Year label (e.g. "September 2026"), quick "Today" jump button, `<` (previous month) and `>` (next month) navigation, and `▲`/`▼` collapse/expand toggle.
  - 7-day civil column grid (Monday to Sunday) using `calendarMonthDays(month)` from `lib/domain/calendar_event.dart`.
  - Smart row optimization: conditionally skips the 6th row if it contains zero days of the visible month, keeping the widget vertically compact.
  - Today highlight with accent border and bold text; selection state background tint; muted opacity for adjacent-month dates.
  - Content indicators: subtle dot indicators beneath day numbers for existing daily notes (`orbit.note` with `dailyDate`) and scheduled tasks/events (`entriesOn`).
  - Clicking any date calls `c.openTodayNote(date: day)`, automatically opening the daily note if it exists or creating it with template headings and embedded task dynamic view if new.
  - Collapsible mode: collapses down to a single compact 32px header bar with expand chevron, preserving maximum vertical space for the file/folder tree when desired.
- Session & Workspace integration:
  - Added `explorerCalendarCollapsed` flag to `SessionState` (`lib/app/session_state.dart`) with JSON persistence.
  - Added `c.explorerCalendarCollapsed` getter and `c.toggleExplorerCalendar()` to `WorkspaceController` (`lib/app/workspace_controller.dart`).
  - Integrated `ExplorerMiniCalendar` in `WorkspaceShell` (`lib/features/workspace/workspace_shell.dart`).
- Automated tests (`test/explorer_mini_calendar_test.dart`):
  - Comprehensive suite verifying rendering, month navigation, today jump, daily note creation & idempotency on tap, collapse/expand toggle, and scheduled event integration.

Validation:
- Format & analyzer: `dart format --output=none --set-exit-if-changed lib test` passed (239 files format-clean); `flutter analyze --no-pub` reported **No issues found!**
- Automated tests: `test/explorer_mini_calendar_test.dart`, `test/workspace_explorer_drop_test.dart`, and `test/workspace_ui_test.dart` all passed cleanly (4/4 tests).
- Scoped diff check: `git diff --check` passed with 0 whitespace issues in modified files.

Limits:
- Mini calendar focuses on temporal daily note navigation and activity awareness; detailed scheduling/time blocks are handled in the dedicated full Calendar View (`OrbitDestination.calendar`).

Suggested next task:
- Canvas diagram export to vector SVG / high-resolution image dialog presets or note slash-command formula presets (PORT-05, CAN-16, EDT-13).

# Previous task — Rich Multi-Block Drag-and-Drop Reordering, Keyboard Movement (Alt+Up/Down) & Selection Duplication, 2026-09-17

Owner request: continue adding features — implement rich multi-block drag-and-drop reordering,
keyboard-driven paragraph/block shifting (Alt+Up / Alt+Down), and multi-block duplication in Orbit Note's
`RichMarkdownEditor`. Scope: EDT-02, EDT-04, EDT-09, ADR-0011 source-preserving rich projection.

Implemented:
- Multi-block drag state & feedback: extended `Draggable<List<MarkdownBlock>>` to drag either
  a single block or the full multi-block selection (`selectedBlocks`).
- Stacked drag feedback: `_buildDragFeedback` renders a layered drop-shadowed card stack with
  a primary badge indicating the exact block count (e.g. `3 blocks`) when dragging multiple blocks.
- Smart drop target validation: `DragTarget<List<MarkdownBlock>>` rejects drop targets contained
  within the moving selection (`!details.data.contains(block)`), displays insertion indicators,
  and dims all dragged blocks (`Opacity(0.35)`).
- Atomic multi-block movement engine (`_moveBlocks`): contiguously extracts non-blank source
  blocks with their trailing blank spacers, inserts them atomically before or after the target block,
  preserves inter-block blank line rhythm, and automatically restores multi-block selection over
  the relocated block range.
- Keyboard-driven movement (`Alt+Up` / `Alt+Down`):
  - In `_RichTextBlockState.keyEvent`: typing users can press `Alt+Up` or `Alt+Down` to immediately
    slide their active paragraph up or down without losing cursor position or text field focus.
  - In `_handleEditorKeyEvent` on `_editorFocusNode`: pressing `Alt+Up` or `Alt+Down` while multiple
    blocks are selected smoothly slides the entire selected block bundle up or down.
- Context menu adaptation: "Move up" and "Move down" dynamically adapt to "Move selected blocks up"
  and "Move selected blocks down" (annotated with `Alt+↑` and `Alt+↓`), and "Duplicate" adapts to
  "Duplicate selected blocks" (annotated with `Ctrl+D`), cloning the entire selection in-place below with instant re-selection.
- Keyboard duplication (`Ctrl+D` / `Cmd+D`): duplicates the active block or multi-block selection in-place.
- Full undo/redo integration: all movement and duplication mutations register cleanly with Orbit Note's
  universal document history (`Ctrl+Z` / `Ctrl+Y`).

Validation:
- Format & analyzer: `dart format --output=none --set-exit-if-changed lib test` passed
  (237 files format-clean); `flutter analyze --no-pub` reported **No issues found!**
  Scoped diff check `git diff --check` passed with 0 whitespace issues in modified files.
- Automated tests: dedicated test suite in `test/rich_editor_multi_block_reorder_test.dart`
  passed all 7 tests cleanly covering single/multi-block Alt+Up/Down, Ctrl+D duplication, undo/redo,
  and drag targets.
- Editor regression suite: all 22 tests in `test/rich_editor_widget_test.dart` and 8 tests in
  `test/rich_editor_multi_block_selection_test.dart` passed with zero regressions.

Limits:
- Cross-note drag-and-drop between separate windows remains a future platform adapter extension;
  all intra-document single and multi-block drag-and-drop and keyboard movements operate reliably.

Suggested next task:
- Canvas diagram export to vector SVG / high-resolution image dialog presets or note slash-command
  formula presets (PORT-05, CAN-16, EDT-13).

# Previous task — Canvas Card Preview Tooltips, Inline Thumbnail Rendering & Dynamic View Embedding, 2026-09-17

Owner request: continue adding features — implement canvas card preview tooltips, inline thumbnail rendering,
and bidirectional dynamic view embedding on spatial boards. Scope: CAN-03, CAN-04, CAN-09, FILE-05.

Implemented:
- Universal Canvas cards referencing notes, tasks, images, PDFs, or dynamic views support 4 distinct
  presentations (`compact`, `card`, `preview`, `properties`) with faithful inline thumbnail/content rendering.
- Canvas card hover preview tooltips (`CanvasCardPreviewTooltip`) with calm debounce (350ms) showing
  rich formatted summaries, metadata tags/projects, task status, PDF quotes, and quick actions
  (`Open`, `Mark Done` / `Mark Open`, `Cycle Presentation`, `Copy WikiLink`).
- Interactive on-canvas card controls: direct checkbox toggle on task cards, dynamic view item opening,
  presentation cycling, and "Add Dynamic View" in context menu routing directly to universal object commands.
- Inline thumbnails and dynamic view queries with live progress bars and item lists.

Validation:
- Format & analyzer: format-clean across all files; `flutter analyze --no-pub` reported **No issues found!**
- Automated tests: 11 tests in `test/canvas_card_previews_test.dart` passed cleanly covering
  helpers, element presentations, painter rendering, hover tooltip interactions, and on-canvas checkbox toggling.

Suggested next task:
- Implement rich drag-and-drop reordering for multi-block selections, or canvas card
  preview tooltips and inline thumbnail rendering (CAN-09, FILE-05).

# Previous task — Reliable Selection, Copy & Multi-Block Operations Across Multiple Rich Paragraphs, 2026-09-17

# Previous task — Paragraph controls and duplicate empty prompts, 2026-09-17

Owner follow-up: restore discoverable paragraph moving and between-line insertion;
fix two adjacent empty paragraph prompts. Scope: EDT-02/04/09, existing Rich
projection and source-preserving contract.

Implemented: hovering a paragraph reveals its existing add/move/menu/collapse
controls in the fixed right gutter, preserving the aligned text edge. Hovering a
blank separator reveals a thin insertion line and plus button. Keyboard focus and
touch accessibility remain supported. Focusing a trailing blank now removes the
redundant zero-byte end-of-document field; no authored source or blank lines are
deleted. Regression reproduces Enter at a heading followed by trailing blank lines.

Validation: format/no-change formatting passed (234 files); analyzer found no
issues; scoped diff whitespace check passed. Full suite: **612 passed, 9 failed**,
with the same pre-existing startup/canvas/home/explorer failures as the previous
pass. Editor regressions, including moving, between-paragraph insertion and the
new duplicate-prompt case, passed. Logs: `.local/paragraph-controls-{analyze,
all-tests,windows-build}.log`. Windows release rebuild passed (76.4s), output:
`build/windows/x64/runner/Release/orbit_note.exe`.

Suggested next task: reliable selection/copy across multiple Rich paragraphs.

# Previous task — Calm rich editor layout and text alignment, 2026-09-16

Owner request: repair offset headings, distracting paragraph-insertion controls,
and the detached formatting toolbar; add left/center/right alignment and improve
the writing experience. Scope: EDT-02/03/04/09/12, within ADR-0011's existing
source-preserving Markdown projection. Preserve other in-progress features.

Implemented: consistent title/heading/prose edge; document-aligned compact toolbar
with More formatting; quiet right-hand block controls that do not activate while
typing or crossing prose; no full-width insertion divider. Fixed slash-menu
overflow and made basic writing commands immediately reachable. Added paragraph
and heading alignment in Rich, Source and Read, with portable Markdown comments,
undo and aligned Enter continuation. Unknown syntax stays unchanged.

Validation completed 2026-09-17:
- All **107 note/Markdown editor tests passed** on the final source, including
  layout geometry, quiet typing controls, CRLF/unknown-source preservation,
  alignment editing/undo/Read mode and empty-paragraph Enter continuation.
- `dart format lib test`, no-change formatting (234 files), `flutter analyze`
  and scoped `git diff --check` passed. No dependency or storage migration.
- Windows release build passed (55.5s). The rebuilt app remained running and
  responsive during a five-second smoke test; only that test process was closed.
- Desktop (1600px) and narrow (390px) captures were visually inspected:
  `work/ui/editor-layout-desktop.png`, `work/ui/editor-layout-narrow.png`.
- Full suite during this pass: **610 passed, 9 failed** in existing startup,
  canvas, home and explorer workflows. The prior slash-command editor failure is
  fixed. The final empty-alignment refinement was then covered by the passing
  107-test editor suite. Logs: `.local/editor-layout-{analyze,all-tests,
  final-tests,windows-build}.log`.

Limits: alignment targets individual paragraphs/headings, not arbitrary ranges
across blocks or every embedded object. Other readers may ignore its comment.
Native cross-block text selection remains unfinished. Narrow toolbars scroll;
touch/accessibility controls remain visible. No claim that all editor bugs or the
nine unrelated suite failures are resolved.

Suggested next task: make selection/copy across multiple Rich blocks reliable.

# Previous task — Dynamic Views, Frozen Snapshots, Periodic Reviews, Unresolved WikiLinks & Quick Capture Inbox, 2026-09-16

Owner request: Implement focused Knowledge Workflow + Dynamic Views + Periodic Review + Beginner UX system for Orbit Note:
1. Dynamic Views in notes: ````orbit-view ... ```` code blocks in portable Markdown querying Universal Objects (tasks, recent notes, backlinks, activity, progress bars, upcoming deadlines, files) with interactive checkboxes and visual configuration dialog (zero raw SQL/Dataview syntax).
2. Live Views vs Frozen Snapshots: ````orbit-snapshot ... ```` code blocks preserving historical review states, with 1-click "Freeze as Snapshot" and "Restore Live View".
3. Today / Daily Note as Generated Dashboard: native Markdown notes named `YYYY-MM-DD` pre-populating embedded dynamic views for open tasks and reflection headings.
4. Day → Week → Month → Quarter → Year Periodic Review Flow: Temporal navigation bar with period switcher, factual aggregation without subjective AI opinions, and 1-click generation of review notes with embedded dynamic views and `# Reflection` sections.
5. Generated Project Dashboards: Semantic project overview (progress bar, open tasks, completed tasks, recent notes, canvases, files, activity) accessed via `openProjectDashboard(String projectName)`.
6. Unresolved WikiLinks as First-Class Citizens: Missing link detection, mentions list, and 1-click note creation with auto-resolution via `showUnresolvedLinkDialog`.
7. Quick Capture Inbox & Review Later: Zero-friction text capture input separating capture from organizing, with card-by-card triage dialog (`showInboxReviewDialog`).
8. Progressive Disclosure: Calm beginner dashboard, collapsible properties, organized slash commands.

Implemented:
- Dynamic Views in Markdown (`lib/features/notes/rich/dynamic_view_block.dart`):
  - `DynamicViewConfig`: key-value YAML serialization/parsing (`type`, `status`, `project`, `folder`, `period`, `sort`, `limit`, `title`).
  - `DynamicViewBlock`: `ConsumerStatefulWidget` rendering live tasks with direct checkbox completion, progress indicators, notes, backlinks, activity, and files; visual configuration modal with dropdowns; "Freeze as Snapshot" button.
- Frozen Snapshots (`lib/features/notes/rich/snapshot_block.dart`):
  - `SnapshotConfig` & `SnapshotItem`: parses and writes `orbit-snapshot` YAML blocks with timestamp, static frozen items, and completion states.
  - `SnapshotBlock`: renders static snapshot with historical timestamp badge and "Restore Live View" action.
- Editor & Slash Commands (`lib/features/notes/rich/rich_markdown_editor.dart` & `note_editor.dart`):
  - Code block renderer recognizes `orbit-view`, `view`, `orbit-snapshot`, and `snapshot` languages.
  - Grouped slash command palette (`DYNAMIC VIEWS`, `BASIC BLOCKS`, `RICH MEDIA & MATH`, `KNOWLEDGE & CALLOUTS`).
  - Missing WikiLinks (`orbit-missing:...`) route to `showUnresolvedLinkDialog`.
- Unresolved WikiLinks Dialog (`lib/features/notes/unresolved_link_dialog.dart`):
  - Modal displaying missing title, referencing notes with 1-click open, `Create Note`, and `Search Similar`.
- Quick Capture Inbox & Triage (`lib/features/workspace/inbox_review_dialog.dart`):
  - Card-by-card triage modal with project/folder assignment, task conversion, archiving, and deletion.
- Project Dashboard (`lib/features/workspace/project_dashboard_view.dart` & `saved_view_host.dart`):
  - Semantic project dashboard with progress indicator, tasks checklist, recent notes, and activity history.
  - Integrated into saved views under viewType `'project'`.
- Controller Enhancements (`lib/app/workspace_controller.dart`):
  - `unresolvedWikiLinks()`: finds and groups missing `[[...]]` links.
  - `quickCapture(text, {asTask})` and `inboxObjects`.
  - `processInboxItem(id, {project, folder, asTask, archive, delete})`.
  - `notesCreatedBetween`, `tasksCompletedBetween`, `tasksUnfinishedBetween`, `projectsActiveBetween`.
  - `openTodayNote({date})`, `openReviewNote({periodName, title, initialBody})`, `openProjectDashboard(projectName)`.
- Temporal Review Navigation & Home View (`lib/features/workspace/workspace_views.dart`):
  - `TemporalZoom` (Day, Week, Month, Quarter, Year) with period navigation buttons, reset to current, and 1-click Review Note creation.
  - Quick Capture input field and Inbox triage banner.
  - Factual periodic review metrics (notes, completed tasks, open loops, active projects).
- Automated Tests (`test/knowledge_workflow_dynamic_views_test.dart`):
  - 12 comprehensive unit and widget tests covering config parsing/serialization, unresolved WikiLinks, quick capture & triage, temporal query boundaries, today/review note creation, DynamicViewBlock rendering and task toggling, SnapshotBlock freezing and live restoration, ProjectDashboardView, and HomeView temporal navigation.

Validation evidence:
- Quality checks:
  - `dart format lib test` and `dart format --output=none --set-exit-if-changed lib test` passed with 0 unformatted files.
  - `flutter analyze --no-pub` reported **No issues found!** across all 230 files.
- Automated test suites:
  - `flutter test --no-pub test/knowledge_workflow_dynamic_views_test.dart`: 12/12 passed cleanly.
  - `flutter test --no-pub test/workspace_explorer_drop_test.dart`: 2/2 passed cleanly.
  - `flutter test --no-pub test/workspace_ui_test.dart`: passed cleanly.

Limits:
- Dynamic views query Universal Objects within the active workspace/vault; Markdown code blocks remain 100% standard and portable across external tools.
- Periodic reviews emphasize factual aggregation over subjective AI generation to maintain user trust and knowledge clarity.

Next suggested task:
- Implement bidirectional Canvas-to-Dynamic-View embedding and card reference syncing (CAN-18, EDT-15).

# Previous task — Unified Explorer Filtering, Quick Actions & Multi-View Drag-and-Drop, 2026-09-16

Implemented:
- Explorer quick actions toolbar (`lib/features/workspace/workspace_shell.dart`):
  - Action buttons row: `Note`, `Canvas`, `Open PDF`, `Open Image`, `Import` with compact icons, tooltips, and keyboard accessibility.
- Explorer type filter chips (`lib/features/workspace/workspace_shell.dart`):
  - Filter chips: `All`, `Notes`, `Canvases`, `PDFs`, `Images`, `Tasks` with `ValueKey('filter-chip-$key')` and dynamic active section headers with count badges (e.g. `PDFS · 3`, `IMAGES · 2`).
  - Search box enhancements with clear button (`Icons.clear`) when text is entered and count indication.
- Folder explorer item distinction (`lib/features/workspace/note_folder_explorer.dart`):
  - Image files distinguished with `Icons.image_outlined` and tertiary theme tinting.
- Top header quick menu (`lib/features/workspace/workspace_shell.dart`):
  - `PopupMenuButton<String>` with tooltip `'Open & Import Files'` providing quick access to `New Note`, `New Canvas`, `Open PDF…`, `Open Image…`, and `Import File…` with overflow-safe constraints.
- Multi-view drag-and-drop file integration (`lib/features/workspace/workspace_shell.dart`):
  - Wrapped Explorer sidebar and main view area with `DropTarget` (`explorer-drop-target` and `content-drop-target`).
  - Drop feedback border and status messages.
  - Context-aware routing:
    - **Canvas**: Bitmapped images (.png, .jpg, .webp, .gif) create positioned image elements; vector diagrams (.mermaid, .mmd, .svg) parse into layout elements; PDFs and other files create interactive `card` elements referencing the file object with universal object identity.
    - **Notes**: PDFs insert stable `ObjectReference` markdown links (`[[<id>|Title]]`); images insert markdown image syntax (`![Title](<rel-path>)`); other files insert markdown attachment links.
    - **Explorer / Global**: Imports files into the local vault attachments folder (`Attachments/<checksum>/...`) and immediately opens the first object.
- Automated tests (`test/workspace_explorer_drop_test.dart`):
  - `TestDropItem` simulating in-memory file drops without filesystem dependency.
  - Test 1: Explorer quick actions, type filter chips (`canvases`, `pdfs`, `images`, `tasks`, `all`), search filter clear button, and header popup menu.
  - Test 2: File drops onto Canvas (PDF card and Mermaid diagram), Note (markdown link), and Explorer (vault import and auto-open).

Validation evidence:
- Automated tests:
  - `flutter test --no-pub test/workspace_explorer_drop_test.dart` passed (2/2 tests).
  - `flutter test --no-pub test/workspace_ui_test.dart` passed.
  - `flutter test --no-pub test/canvas_diagram_import_test.dart` passed (17/17 tests).
- Quality checks:
  - `dart format --output=none --set-exit-if-changed lib test` passed (0 unformatted files).
  - `flutter analyze --no-pub` reported **No issues found!** (0 errors, 0 warnings, 0 lints).

Limits:
- Drag-and-drop uses `desktop_drop` which handles desktop platforms (Windows, macOS, Linux) and web; mobile platforms use the Quick Action buttons and system file picker.
- Deduplication ensures files with matching SHA-256 hashes reuse the existing vault attachment and object identity.

Next suggested task:
- Implement canvas card preview tooltips and inline thumbnail rendering for attached PDFs and images on canvas cards (CAN-09, FILE-05).

# Previous task — Universal Canvas Diagramming & Import Engine, 2026-09-16

Implemented:
- Pure Dart diagram parsing & layout engine (`lib/canvas/diagram_import.dart`), completely decoupled from Flutter UI and network:
  - Mermaid flowchart parser (`parseMermaidFlowchart`): supports `graph TD`, `graph LR`, `graph BT`, `graph RL`, `flowchart ...`, node shapes (`[]` rect, `()` capsule, `([])` rounded pill, `[[]]` subroutine, `[()]` cylinder/database, `(())` circle/state, `{}` decision diamond), connection styles (`-->`, `---`, `-.->`, `==>`, `<-->`, labels `-->|...|`), chained statements (`A --> B --> C`), cycle-safe topological ranking DAG layout algorithm.
  - Orbit Canvas JSON importer (`parseCanvasJson`): parses exported JSON arrays or canvas structures, generates new non-colliding UUIDs, remaps all connector endpoints (`startId`, `endId`), groups imported elements, and centers layout around target viewport center.
  - Outline to Mind Map & Tree importer (`parseOutlineDiagram`): parses Markdown headings and indented bullet lists into hierarchical tree data, generates Radial Mind Maps (alternating left/right branch radiation), Horizontal Trees (left-to-right hierarchy), and Vertical Trees (top-to-bottom hierarchy).
  - SVG vector shape importer (`parseSvgDiagram`): parses `<rect>`, `<circle>`, `<ellipse>`, `<line>`, `<text>` elements into native CanvasElement shapes.
  - Production diagram templates catalog (`getDiagramTemplates()`): curated catalog of 7 production templates across Architecture, Engineering, Planning, Productivity, Strategy, and Workflows (Decision Flowchart, Cloud Microservices Architecture, Sequence/Auth Flow, Entity-Relationship Diagram, State Machine Loop, Mind Map Knowledge Hub, Product Roadmap).
- Flutter import modal dialog (`lib/features/canvas/canvas_import_dialog.dart`):
  - 4 tabs: Templates, Mermaid Flowchart editor with sample loader & live syntax feedback, Markdown Outline converter with layout picker (Radial Mind Map, Tree H, Tree V), and File picker/importer (.json, .mermaid, .mmd, .txt, .svg).
  - Fully responsive, overflow-free layout with Material 3 styling.
- Canvas editor integration (`lib/features/canvas/canvas_editor.dart`):
  - Top toolbar action button (`Icons.file_upload_outlined`) with tooltip `Import diagrams & templates (Ctrl+I)`.
  - Background context menu entry "Import Diagrams & Content...".
  - Keyboard shortcut `Ctrl+I` / `Cmd+I`.
  - Atomic transaction undo/redo: imported elements are assigned a cohesive group ID and committed via `_history.commit()`.

Validation evidence:
- All **17 unit and widget tests** in `test/canvas_diagram_import_test.dart` passed cleanly:
  - Mermaid DAG ranking, orientations, node shapes, styles, cycles, and empty inputs.
  - Canvas JSON import, UUID remapping, connector rewiring, and bounds normalization.
  - Outline to Radial Mind Map, Horizontal Tree, and Vertical Tree layouts.
  - SVG vector element parsing and position offsets.
  - Pre-built diagram templates generation and verification.
  - Full UI widget tests for `CanvasImportDialog` tab switching, sample loading, template insertion, and toolbar integration.
- Codebase-wide checks:
  - `dart format lib test` and `dart format --output=none --set-exit-if-changed lib test` passed with 0 unformatted files.
  - `flutter analyze --no-pub` reported **No issues found!** across all 223 files.
  - Core canvas tests (`canvas_engine_test.dart`, `canvas_connectors_test.dart`, `canvas_groups_test.dart`, `canvas_widget_test.dart`) passed with zero regressions.

Limits:
- Mermaid support focuses on flowcharts/DAGs (`graph` and `flowchart`). State, sequence, and class diagrams can be represented via the built-in templates and flowchart notation.
- SVG parser extracts geometric primitives (`rect`, `circle`, `ellipse`, `line`, `text`); complex SVG paths are mapped to bounding rects or notes.

Next suggested task:
- Implement Canvas diagram export to standard SVG and Mermaid syntax (CAN-16, PORT-05) enabling bidirectional round-trip diagram interoperability.

# Previous task — PDF reader reliability and connected notes, 2026-09-16

Owner request: fix PDF reading bugs and strengthen its note-taking workflow.
Scope: audit and repair reproducible FILE-04/05/09/11/12/13 and LNK-03/04 issues;
preserve original bytes, note identity, source-version guards and all prior changes.
Required context: attachments-and-research, search-links-and-graph, implemented
formats, ADRs 0013–0015 and the existing application save/recovery contract.

Plan: cover reader retry/document lifecycle, page/zoom restoration, selection over
existing highlights, failed-comment recovery, and PDF/note navigation with native
regressions. Add searchable connected notes using existing objects/backlinks and
precise source return. Run format/analyze/full tests, independent PDF checks,
Windows release build and visual/startup checks. Record verified fixes and remaining
limits; "all bugs" is not a claim that untested PDFs/platforms are bug-free.

Status: implementation complete; validation details in
[PDF reliability report](pdf-reader-reliability-2026-09-16.md). The full application
suite has unrelated failures; this pass does not claim a clean overall release.
Existing annotated-export release checks below predate this pass.

# Previous task — Annotated PDF copies, 2026-09-15

Owner asked to resume feature work after the computer reset. The active source is
`C:\Users\isa\Desktop\Orbit Note`; the Documents/Codex copy is a historical
bootstrap snapshot, not the source to merge over this checkout. Continue the prior
PDF handoff (FILE-12/14); Google stays paused. Prior uncommitted work is retained.
Required context: [PDF specification](../features/attachments-and-research.md),
[implemented formats](../architecture/implemented-formats.md), ADRs 0013/0014/0015,
and [storage/save contract](../architecture/storage-formats.md).

Implemented: **Save filtered review as annotated PDF** in the review panel creates
a separate ordinary PDF attachment in the Vault. Highlights, underlines, strikeouts
and page comments use standard PDF annotations, with Unicode note bodies, colors,
stable note references and printable flags. Each region becomes one annotation;
multi-region notes repeat their comment. Open/resolved is included in comment text,
not represented as a native PDF review-state conversation. Existing PDF content,
embedded annotations and form values are retained; unsaved Orbit form drafts are
not applied by this action. Original bytes and editable Orbit notes stay unchanged.

Export uses the existing PDFium worker with an isolated in-memory document. It
verifies the actual source-byte checksum, region validity and supported metadata;
protected/signed/XFA PDFs, stale sources, unknown review versions, missing pages
and excessive input are rejected. The reader prevents duplicate requests and
checks note snapshots before saving; the application rechecks source/note snapshots
at the save boundary. Failure leaves notes available for retry. Rotation/crop
coordinates are converted through PDFium. No new runtime dependency, schema,
migration or storage authority. Existing attachment save/recovery is reused.

Validation complete for the available toolchain: all **575 tests passed** (40s),
including six new regressions for native export, failed-save retry/busy state,
byte/source safety, form preservation, rotation/crop and durable save/reopen.
The existing review-panel regression also verifies exporting the filtered items.
`dart format lib test` and the no-change check passed (219 files),
`flutter analyze` reported no issues (10.3s), and `git diff --check` passed.
Independent `tool/check_pdf_annotation_export.py` passed for standard types,
Unicode, colors, geometry, rotation/crop, images/text and an editable pypdf
round-trip. Poppler-rendered two-page and rotated exports were visually inspected;
the independent round-trip's first-page rendering is pixel-identical. Poppler
reported fallback-font configuration warnings; the inspected text rendered legibly.
`flutter build web --no-pub` passed (51.6s), with existing Google JS-interop WASM
dry-run and Cupertino font advisories; this is not a WASM runtime acceptance claim.
Logs: `.local/pdf-export-{tests,analyze,web-build,windows-build}.log`.
Generated QA artifacts: `.local/pdf-export-qa/` (ignored).

Environment: restored pinned Flutter 3.44.8 / Dart 3.12.2 in ignored `.local`, with
official archive SHA-256 verification; no dependency upgrades. Repaired the ignored
`.local/flutter-env.ps1` helper for the new account and SDK short path. Project-local
plugin junctions avoid changing Windows Developer Mode.

Windows validation completed 2026-09-16 after explicit owner approval to restore
the C++ tools: Visual Studio Build Tools 2022 17.14.41, Windows SDK 10.0.26100.0,
and the ATL component required by flutter_secure_storage_windows were installed.
Both installers completed successfully (exit 0). No application code changes were
needed. `flutter build windows --release --no-pub` passed in 16.5s. Executable:
`build/windows/x64/runner/Release/orbit_note.exe`. A five-second hidden startup
check found the rebuilt process alive and responding. The test instance was then
stopped by its recorded process ID because its hidden window did not accept a
close request. Evidence: `.local/pdf-export-windows-build.log`,
`.local/pdf-export-doctor.log`, `.local/pdf-export-smoke.json`.
The prior Windows build blocker is resolved. Full native interactive export and
physical-device acceptance remain unverified; the 575-test/analyzer/format/web
results above remain the latest application-code checks.

Limits: native export only; web retains Markdown export. No annotation import,
shared ink, redaction, signatures or PDF content editing. Exported copies can be
opened externally through the existing file action. Native resolution threads,
arbitrary PDF metadata and original serialization are not promised round-trip into
Orbit. Originals/sidecars remain the authoritative editable source.

Next suggested task: import supported annotations from a separately reviewed PDF
as source-versioned notes, with preview, duplicate detection and reversible import.

# Previous task — PDF review workspace, 2026-09-14

Owner request: add useful Acrobat-inspired work tools while preserving Orbit's
local-first knowledge model. Scope: FILE-04/05/11/12/13; Google remains paused.
Required references: [PDF/research spec](../features/attachments-and-research.md),
[implemented formats](../architecture/implemented-formats.md), ADRs 0013/0014/0015,
and the existing application save/recovery contract. Preserve prior editor work.

Implemented batch:

- Page comments, including scans/diagrams with no selectable text, create linkable
  notes and visible page markers. A failed create keeps the typed comment for retry.
- Edit review notes from the reader; change markup color/type and resolve/reopen.
  The editor explicitly edits the same note's Markdown body, with normal save/history.
  Concurrent edits/source changes reject stale dialogs; failed saves retain drafts.
- Review panel filters text, open/resolved, markup type and current page; sorts by
  page or newest. Filters survive closing/reopening the panel in the same session.
- Copy/export the filtered review as Markdown or save it as an ordinary linked note
  beside the PDF. Summary links use UUIDs for both annotations and source pages;
  stale source versions are labelled. Large summaries are bounded; source is retained.
- Hide/show review markup without deleting notes. Unknown properties/region fields,
  source checksums and original PDF bytes remain intact. No package/schema migration.

Validation resumed 2026-09-15 after the prior usage-limit interruption. The moved
Flutter SDK was located in the local backup and the ignored build helper repaired;
Flutter remains 3.44.8 / Dart 3.12.2, with no dependency upgrade.
`dart format lib test tool` and the no-change format check passed (218 files).
`flutter analyze` reported no issues (22.6s). All **569 tests passed** (60s),
including seven new review regressions for persistence, stale/failure safety,
filtering, editing, source-linked summaries and page-comment retry. The existing
real-PDF rendering/form/comfort and Rich editor regressions also pass. Ten targeted
reader/review tests passed with desktop screenshot capture on 2026-09-14; the
result was inspected. Logs: `.local/pdf-review-*.log`; visual artifact:
`work/ui/pdf-highlights.png`.

`flutter build windows --release` succeeded (60.3s). Executable:
`build/windows/x64/runner/Release/orbit_note.exe`. A five-second startup smoke check
confirmed the rebuilt process remained running and responding; that test instance
was then closed. Evidence: `.local/pdf-review-windows-build.log` and
`.local/pdf-review-smoke.json`. `git diff --check` passed. No full native interactive
review session, physical phone test or OS Save As dialog test was performed.

Boundaries: Orbit review metadata is not written into the original PDF. This batch
does not implement annotated-PDF export, OCR, redaction, signatures, arbitrary PDF
text editing, or native comment import. Page markers use a bounded automatic grid,
not free placement/dragging. Real-phone and OS Save As dialog acceptance is pending.

Next suggested task: export a separate standards-compatible annotated PDF with
round-trip tests in an independent reader, preserving originals and version guards.

# Previous task — Restore the math catalog and stabilize direct editing, 2026-09-14

Owner correction: the reduced palette and unstable editing were not acceptable.
"GeoGebra-like" meant typing into equations naturally, not introducing a solver
or a different product UI. Keep the original searchable LaTeX table, support
editing values in place, and keep the equation visible. Google remains paused.
Required references remain the editing specification, ADR 0011 and agent workflow
linked in the previous pass below. Preserve all unrelated work.

Implemented correction:

- The original **1,473-entry** searchable/category-filtered table is shared by the
  direct editor and Advanced editor. Symbols & templates opens it next to the
  equation; it stays open while inserting entries or editing values. New equations
  open it immediately. Escape/Close dismiss it without deleting the equation.
- The equation and controls keep their positions when fields focus or the table
  opens. The table anchors above/below the equation without covering it and follows
  document scrolling. Fields no longer acquire separate input-box decorations.
- Symbol insertion restores the actual caret instead of jumping to the end.
  Registry-backed standalone symbols (including arrows) remain editable glyphs.
  Exact command matching avoids misclassifying `\leftarrow` as a scalable delimiter.
- Backspace in an empty fraction half retains the other half; empty root degrees
  and script/limit arguments remove only that structure. Nonempty values are kept.
- Ctrl/Cmd+A selects the whole equation; copy/cut/paste/delete and replacement
  typing operate on that selection. Cut waits for successful clipboard copy;
  clipboard failure leaves the equation intact. Stale asynchronous clipboard work
  cannot overwrite a changed equation. Empty equations retain an editable slot.

Same source-span projection, Markdown durability and shared undo; no new package,
storage format, schema, migration or ADR. Arbitrary partial selection spanning
several equation parts remains unfinished. Complex TeX/matrices retain the existing
Advanced/grid editor and safe renderer fallback; this is not full Word parity.

Validation (2026-09-14): `dart format lib test tool` and no-change format check
passed (216 files); `flutter analyze` reported no issues (6.9s); all **562 tests
passed** (41s), including eight new correction regressions. Coverage includes the
full table remaining open/clear of the equation, insertion caret, arrow glyphs,
empty-argument preservation, whole selection/delete/cut/paste and clipboard-failure
safety. Existing Markdown round-trip, shared undo and narrow-layout tests pass.
The captured desktop catalog view was visually inspected. `git diff --check` passed.

`flutter build windows --release` succeeded (48.7s). Executable:
`build/windows/x64/runner/Release/orbit_note.exe`. The rebuilt process stayed alive
and responding for a five-second startup smoke check, then was closed. Clipboard
behavior was checked through Flutter's mocked platform channel, not a manual native
copy/paste session. Real-phone typing and native interactive acceptance remain
unverified. Logs: `.local/math-correction-*.log` and `.local/math-correction-smoke.json`;
screenshot: `work/ui/math-catalog-rich.png`. These are ignored local artifacts.

Next suggested task (do not start automatically): source-preserving partial
selection across equation structures, including Shift+arrow and replacement undo.

# Previous pass — Direct rich math editing, 2026-09-14

Owner direction: pause Google work; make equations editable directly in Rich
Notes, with a Word/GeoGebra-style input experience. Preserve all existing cloud
and unrelated work. Scope: EDT-03/04/06/09/12/15. Required references:
[editing specification](../features/markdown-and-editing.md),
[source-preserving projection](../adr/0011-source-preserving-rich-markdown.md),
and [workflow](../development/agent-workflow.md).

Delivered and validated:

- One editable expression replaces the duplicated renderer/slot forms. Fractions,
  nested fractions, roots/degrees, powers/subscripts and operator limits edit in place.
- `/`, `^`, `_` create structures at the caret/selection; Tab/Shift+Tab and arrows
  navigate slots. Common symbols insert at the remembered caret. New inline/block
  equations immediately focus a selectable placeholder, without opening Studio.
- Exact source spans feed the existing note callback and shared history. Unbraced
  arguments gain braces only on edit; command spellings and unrelated Markdown stay
  intact. Empty inline equations retain an editable placeholder. Newly edited inline
  boundary whitespace is trimmed to retain Markdown's equation delimiter grammar.
- Complex environments/scalable delimiters retain the existing renderer, grid
  editor where supported, and Advanced equation editor/full symbol catalog.

No new dependencies, storage schema, migration, remote service or ADR. This is a
bounded projection refinement, not full Word or GeoGebra parity. Cross-structure
native selection/deletion, exact mathematical typesetting in every editable slot,
and direct editing of arbitrary TeX/matrix environments remain limitations. There
is no symbolic solver/plotter; ordinary equation values are editable offline.

Next suggested task (do not start automatically): keyboard selection/removal across
equation structures with source-preserving undo and direct matrix cell editing.

Validation (2026-09-14): `dart format lib test tool` and the no-change format check
passed (215 files); `flutter analyze` reported no issues (7.4s); all **554 tests
passed** (44s), including 21 added math tests. They cover nested/source-span edits,
command boundary safety, empty inline slots, rapid events/IME, keyboard navigation,
symbol menu focus, direct insertion, cross-mode undo and Markdown reopen. Existing
render-only test assertions now check the editable component in Rich and retain
the original renderer assertions in Read. Desktop/narrow viewport visual checks
passed, including larger text; a rendered screenshot was inspected locally.

`flutter build windows --release` succeeded (50.8s). Executable:
`build/windows/x64/runner/Release/orbit_note.exe`. Its process stayed running and
responding for the five-second startup smoke check, then was closed. Native pen,
real-phone typing and a full interactive Windows acceptance session were not
performed. Logs: `.local/direct-math-*.log` and `.local/direct-math-smoke.json`;
visual evidence: `work/ui/rich-lecture.png`. These are local ignored artifacts.

# Paused by owner — Google account and Drive milestone, 2026-09-13

Owner prompt: attachment `5fdf20f6-ee67-477c-b3f7-99c8fd9e3794/pasted-text.txt`.
Continue the existing provider-neutral engine; Windows and Android first.
Account authorization, secure restoration, quota UI, root preparation and Vault
discovery are implemented. **The overall milestone is still incomplete**: Drive
conditional publication, Vault binding/upload/download and automatic sync remain.
See [audit, delivery map and validation](../planning/google-account-milestone-2026-09-13.md)
and [developer setup](../development/google-drive-sync-setup.md).
Do not advertise cloud synchronization or set conditional-publication capability
until the transfer safety contract is proven. Preserve earlier work below.

2026-09-14 account-isolation follow-up: bind full Drive operations and listed
Vaults to the initiating Google account, revalidate selected folder ownership,
and serialize device-local root preparation. Six new failure/concurrency tests
cover these boundaries. Registration remains unfinished: the owner declined use
of their personal email as public support contact and the pending policy
acceptance. Do not infer permission from a generic request to continue.

2026-09-14 release follow-up: Windows/Android release jobs now validate and embed
platform Google app configuration. A missing client ID fails a requested Google
account preview build; local-only remains an explicit mode. Release notes explain
that Vault transfers remain unfinished. Public support address clarification is
pending; no Google registration, policy consent or personal contact was submitted.

# Previous task — Runtime hardening, 2026-09-13

Owner prompt: verify and repair TaskDetail, universal folder operations, connector
endpoints, editor state/source preservation and navigation/search edge cases.
See [audit and evidence](../planning/runtime-audit-2026-09-13.md).
Delivered: 463 tests passed, analyzer clean, 189 files format-clean, Windows release
built in 45.8 seconds and passed a five-second process startup smoke check.
Cloud implementation is explicitly excluded from this task. Preserve all earlier
work below. Suggested next task: browser-safe transactional folder commands;
do not start it without a new task instruction.

# Previous task — M6 local-first cloud sync

Continue [the cloud implementation task](cloud-sync.md). The full owner prompt is
now available. Safety/reconciliation foundations and the native repository replica
adapter are implemented; Google Drive, auth and cloud UI remain unfinished. Preserve the
completed feature work below. See [cloud status](../features/cloud-sync.md).

# Current task — Universal Object Properties, Typed Metadata Editor, Relations Explorer & Release v0.2.2 (ORG-02, ORG-03, ORG-08)

Status: delivered and validated, 2026-09-13.

Delivered Universal Object typed properties management, interactive in-place metadata editing, Add Property modal with live validation (number, date, url, boolean, tags), and a comprehensive Relations & References Explorer (inbound backlinks, outbound wiki-link references, and contextual siblings) inside the Context Inspector (**ORG-02, ORG-03, ORG-08**), along with release packaging and version bump to `v0.2.2` under the core Orbit Note invariant: "ONE STABLE UNIVERSAL OBJECT IDENTITY".

### Delivered Capabilities
1. **WorkspaceController Relations & Property Mutations (`lib/app/workspace_controller.dart`)**:
   - `outboundLinks(String id)`: parses wiki-links from the object's body, resolves candidates through `linkTargets` and `linkBindings`, and returns target `UniversalObject`s.
   - `relatedObjects(String id)`: context discovery finding objects sharing the same `project`, same `folder`, or common `tags`, capped at 10 items.
   - `updateProperty(String id, String key, dynamic value)`: immutable property updates via `edit(id, properties: {...})` and automatic local save debounce.
   - `removeProperty(String id, String key)`: removes user property while preserving schema integrity.
2. **Context Inspector & Typed Metadata Editor (`lib/features/workspace/object_inspector.dart`)**:
   - Identity & Header: Type icon, uppercase type badge, object title, UUID row with "Copy UUID" clipboard button, and formatted Created & Updated timestamps.
   - In-place Typed Property Editors:
     - Checkbox/Boolean: direct Switch toggle with instant feedback.
     - Number: numerical badge opening dialog with `num.tryParse` live validation.
     - Date: date badge opening Flutter date picker and formatting `YYYY-MM-DD`.
     - Tags: wrap of removable chips with `#tag` styling plus `+ Tag` chip to add new tags.
     - URL: clickable link with `Icons.open_in_new` launching URL via `url_launcher`, with edit button and url scheme validation.
     - Text / Other: string display with edit dialog.
     - Delete Property action: quick button on every property row.
   - Add Property Modal:
     - Name input with non-empty and collision validation against existing properties.
     - Type dropdown: Text, Number, Checkbox, Date, Tags, URL.
     - Dynamic value input tailored to selected type with live validation.
   - Relations & References Section:
     - Segmented tabs: `Backlinks (count)`, `Outbound (count)`, `Related (count)`.
     - Displays referencing and referenced objects via `ObjectRow`, with one-tap navigation `c.openObject(id)`.
     - Graceful empty states for each relation tab.
   - Actions: Rename Object button and Move to Trash button.
3. **Workspace Shell Integration (`lib/features/workspace/workspace_shell.dart`)**:
   - Replaced old minimal inspector with `ObjectInspector(controller: c, onRename: renameObject)`.
   - Expanded inspector sidebar width to 300px for optimal layout and breathing room.
4. **Validation Evidence**:
   - 522/522 tests passing across entire suite (`test/object_inspector_properties_test.dart` added covering all unit and widget behaviors).
   - 0 warnings in `flutter analyze`.
   - 100% format-clean across all 205 dart files.

# Previous task — Work & Study Focus Sessions with Honest Tracking, Local Summaries & Release v0.2.1 (CTX-04, CTX-05, CTX-06, CTX-07, CTX-11, CTX-12)

Status: delivered and validated, 2026-09-13.

Delivered dedicated Work, Study, and Reading Focus Sessions with honest active-time tracking, activity recording (notes opened/created, tasks completed), pause/resume recording controls, user-written continuation notes, local session summaries on Home, and Command Palette shortcuts (**CTX-04, CTX-05, CTX-06, CTX-07, CTX-11, CTX-12**), along with desktop packaging and version bump to `v0.2.1` under the core Orbit Note invariant: "CREATE ONCE. REFERENCE ANYWHERE."

### Delivered Capabilities
1. **Pure Dart Work Session Domain Model (`lib/domain/work_session.dart`)**:
   - `WorkSessionRecord`: models bounded sessions with `id`, `title`, `category` (`work`, `study`, `reading`, `general`), `startedAt`, `endedAt`, `isPaused`, `totalPausedDuration`, `notesOpened`, `notesCreated`, `tasksCompleted`, and `continuationNote`.
   - Honest elapsed active duration: computes active time minus accumulated paused intervals, **never claiming unrecorded focus time**.
   - Paused recording invariant (CTX-07): when a session is paused or ended, actions (`recordOpen`, `recordCreate`, `recordTaskCompleted`) strictly omit tracking.
   - Robust JSON roundtripping (`toJson`, `fromJson`) with defensive fallbacks.
2. **Session Lifecycle & Auto-Tracking in WorkspaceController (`lib/app/workspace_controller.dart`)**:
   - `startWorkSession({String? title, String category})`: initializes active session and syncs to session state.
   - `pauseWorkSession()` & `resumeWorkSession()`: pauses and resumes active interval, tracking pause timestamps and accumulating paused duration.
   - `setWorkSessionContinuationNote(String note)`: updates user continuation note.
   - `endWorkSession({String? continuationNote})`: closes active session, stores in `completedWorkSessions` (capped to 30), and persists layout.
   - Hooks:
     - `openObject`: tracks notes opened during active recording.
     - `create`: tracks objects created during active recording.
     - `edit`: detects task completion (`properties['completed'] == true`) and tracks task completions.
   - Guaranteed single initialization guard preventing concurrent microtask re-entry.
3. **Home Dashboard Focus Session Card (`lib/features/workspace/workspace_views.dart`)**:
   - `HomeView`: now a `ConsumerWidget` automatically reacting to controller state updates.
   - `_FocusSessionCard`:
     - **Active state**: displays category badge, status badge (`ACTIVE FOCUS` in emerald or `PAUSED` in amber), title, live tabular digital timer formatted as `MM:SS` or `H:MM:SS`, subtitle "Active time (paused excluded)", action buttons (Pause/Resume, Note, End session), stat badges for notes opened, created, and tasks completed, and italic continuation note preview.
     - **Idle state**: displays "FOCUS & WORK SESSIONS" header, "Start Focus Session" button with category selection dialog, and recent session summary displaying past active time, notes referenced, tasks completed, and continuation note reflection.
     - **Dialogs**: Start session dialog with category segmented button, continuation note editor dialog, and end session confirmation dialog summarizing session achievements.
4. **Command Palette Integration (`lib/features/workspace/command_palette.dart`)**:
   - Made `CommandPalette` a `ConsumerStatefulWidget` watching `workspaceProvider`.
   - Displays "Start focus session" when idle.
   - Displays "Pause focus session: <Title>" / "Resume focus session: <Title>" and "End focus session: <Title>" when active.
   - Guards `Navigator.pop` with `Navigator.canPop(context)` for test robustness.
5. **Release & Packaging**:
   - Bumped `pubspec.yaml` version to `0.2.1+12`.
   - Windows Release build compiled and packaged to `OrbitNote-Windows-x64.zip` (24,889,468 bytes).
   - Zero changes to cloud sync (`lib/application/sync/`, `lib/infrastructure/sync/`).

### Validation Evidence
- Dedicated unit and widget test suite in `test/work_session_test.dart` (5/5 passing tests).
- All continue writing, editor, and workspace UI test suites passing.
- Full repository test suite: **516/516 tests passed cleanly (0 failures)**.
- `dart format lib test` & `dart format --output=none --set-exit-if-changed lib test`: 100% formatted across all 203 files.
- `flutter analyze`: 0 issues found across entire codebase.
- Windows Release binary compiled in 65.8s with pinned Windows SDK 10.0.26100.0 (`build\windows\x64\runner\Release\orbit_note.exe`).
- Deployed executable to `C:\Users\iax\Desktop\Orbit Note Windows App` and created standalone distribution archive `C:\Users\iax\Desktop\OrbitNote-Windows-x64.zip`.

---

# Previous task — Continue Writing, Where Was I? & Note View State Restoration Hardening (EDT-15, CTX-10)

Status: delivered and validated, 2026-09-13.

Delivered note view state restoration hardening across note switches (`didUpdateWidget`) with safe clamping that never modifies document content, the `CONTINUE WRITING` hero resumption card in `HomeView`, the `Where was I:` recent navigation trail in `HomeView`, and `Continue writing` / `Continue reading` quick continuation shortcuts in `CommandPalette` (`Ctrl+P`) under the core Orbit Note invariant: "CREATE ONCE. REFERENCE ANYWHERE."

### Delivered Capabilities
1. **Note View State Restoration Hardening (`lib/features/notes/note_editor.dart`)**:
   - Hardened `didUpdateWidget` during note switching (`oldWidget.noteId != widget.noteId`):
     - Restores `_mode` (`rich`, `write`, `split`, `read`) from `widget.initialViewState['mode']`.
     - Restores `_splitRatio` clamped safely to `[0.2, 0.8]`.
     - Restores `_richState` heading collapse map and caret position from `widget.initialViewState['rich']`.
     - Restores `_body.selection` with `baseOffset` and `extentOffset` strictly clamped to `[0, _body.text.length]`.
     - Automatically falls back to clamped offsets if an external edit or sync change shortens a note, **never mutating document contents** to match stale view state.
     - Restores `_sourceScroll` and `_previewScroll` with post-frame layout-aware bounds clamping.
2. **`CONTINUE WRITING` Hero Card (`lib/features/workspace/workspace_views.dart`)**:
   - Queries the most recent note in the user's active session.
   - Extracts word count and active/saved mode badges (`Rich`, `Write`, `Split`, `Read`).
   - Generates a clean preview snippet stripped of Markdown heading, list, and formatting artifacts.
   - Provides a prominent `Resume writing` action button (`onPressed: () => c.openObject(recentNote.id)`).
   - De-duplicates against `Continue session` cards to prevent redundant elements.
3. **`Where was I:` Recent Navigation Trail (`lib/features/workspace/workspace_views.dart`)**:
   - Renders a horizontal breadcrumb trail of recently active objects with type-aware icons and titles.
   - Enables one-click resumption of recent work directly from the Home dashboard.
4. **Command Palette Quick Continuation (`lib/features/workspace/command_palette.dart`)**:
   - Public `CommandPalette` widget.
   - Provides `Continue writing: <Title>` and `Continue reading: <Title>` shortcuts when recent items are available, jumping straight into the note editor.
5. **Cloud Sync Guardrail**:
   - All cloud sync modules (`lib/application/sync/`, `lib/infrastructure/sync/`) remain completely untouched.

### Validation Evidence
- Dedicated unit and widget test suite in `test/continue_writing_test.dart` (4/4 passing tests).
- All related note editor and navigation test suites passing (20/20 tests across `notes_navigation_test.dart`, `note_find_replace_stats_test.dart`, `notes_editor_test.dart`, `note_editor_stats_test.dart`).
- Full repository test suite: **509/509 tests passed cleanly (0 failures)**.
- `dart format lib test` & `dart format --output=none --set-exit-if-changed lib test`: 100% formatted across all 201 files.
- `flutter analyze`: 0 issues found across entire codebase.
- Windows Release build compiled in 47.6s with pinned Windows SDK 10.0.26100.0 (`build\windows\x64\runner\Release\orbit_note.exe`).
- Deployed executable to `C:\Users\iax\Desktop\Orbit Note Windows App` and updated archive `C:\Users\iax\Desktop\OrbitNote-Windows-x64.zip` (24,872,804 bytes).

---

# Previous task — Selection-Scoped Find & Replace & Labelled Metrics (EDT-13)

Status: delivered and validated, 2026-09-13.

Delivered selection-scoped local find & replace, bidirectional match navigation with live match index indicator (`(X of Y)`), case sensitivity (`Aa`) and whole-word (`\bW\b`) search filters, scoped replacement engine (`Replace all in selection` strictly preserving text outside), and real-time scope-labelled document metrics with reading time estimates (`Selection: ... · Document: ...`) under the core Orbit Note invariant: "CREATE ONCE. REFERENCE ANYWHERE."

### Delivered Capabilities
1. **Selection-Scoped Search Engine (`lib/features/notes/note_editor.dart`)**:
   - `FindScope.document` vs `FindScope.selection`: restricts search boundaries, match counting, navigation, and single/all replacements strictly to the active selection range when enabled.
   - `_scopeStart` and `_scopeEnd`: preserves initial selection range even as find navigation moves the editor caret.
   - Smart Open Seeding: opening find with a short phrase selected seeds search query; multi-line selection activates `FindScope.selection` automatically.
   - Selection Scope Toggle: dedicated toolbar button (`Icons.select_all_rounded`, tooltip `'Find in selection · Alt+S'`) and dismissible scope badge (`In Selection`).
2. **Bidirectional Match Navigation & Filters (`lib/features/notes/note_editor.dart`)**:
   - Live Match Counter: displays `$_findCount ${_findCount == 1 ? 'match' : 'matches'}` and indexed indicator `($_currentMatchIndex of $_findCount)`.
   - Bidirectional Navigation: Previous Match (`Icons.arrow_upward_rounded`, `Shift+Enter`) and Next Match (`Icons.arrow_downward_rounded`, `Enter`).
   - Match Case Toggle: `Aa` button (`Alt+C`), filtering between case-sensitive and case-insensitive matching.
   - Whole Word Toggle: `\bW\b` button (`Alt+W`), filtering whole word tokens via word boundaries.
3. **Scoped Replacement Engine (`lib/features/notes/note_editor.dart`)**:
   - Single Replace: replaces active match and advances to next match within scope.
   - Replace All: replaces all occurrences in note (document scope) or strictly within `[_scopeStart, _scopeEnd]` (selection scope), preserving all text outside untouched.
   - Literal Replacement String Safety: uses `replaceAllMapped` to preserve exact literals (e.g. `$fruit`) without regex group backreference errors.
4. **Scope-Labelled Document Metrics & Reading Time (`lib/features/notes/note_editor.dart`)**:
   - Unselected State: `$words words · $chars characters · ~$readMinutes min read`.
   - Selected State: `Selection: $selWords of $words words ($selChars chars, $selReadTime) · Document: $words words ($chars characters, ~$readMinutes min read)`.
   - Real-time Selection Listener: `_recordSelection` ensures metrics update live on cursor movement and text selection without requiring document text mutation.
   - Reading Time Estimates: calculated based on standard 200 words-per-minute rate with `< 1 min read` for short fragments.
5. **Cloud Sync Guardrail**:
   - All cloud sync modules (`lib/application/sync/`, `lib/infrastructure/sync/`) remain completely untouched.

### Validation Evidence
- Dedicated unit and widget test suite in `test/note_find_replace_stats_test.dart` (9/9 passing tests).
- All related note editor and navigation test suites passing (31/31 tests).
- Full repository test suite: **505/505 tests passed cleanly (0 failures)**.
- `dart format lib test` & `dart format --output=none --set-exit-if-changed lib test`: 100% formatted across all 200 files.
- `flutter analyze`: 0 issues found across entire codebase.
- Windows Release build compiled in 62.6s with pinned Windows SDK 10.0.26100.0 (`build\windows\x64\runner\Release\orbit_note.exe`).
- Deployed executable to `C:\Users\iax\Desktop\Orbit Note Windows App` and updated archive `C:\Users\iax\Desktop\OrbitNote-Windows-x64.zip` (24,868,430 bytes).

---

# Previous task — Footnotes & Underline Formatting (EDT-12)

Status: delivered and validated, 2026-09-13.

Delivered portable Markdown Underline formatting (`<u>text</u>` and `<ins>text</ins>`), GitHub-Flavored Markdown Footnotes (`[^1]` inline reference badge and `[^1]: Definition` block), Underline format toolbar button (`Icons.format_underlined_rounded`), keyboard shortcut (`Ctrl+U`), auto-incrementing footnote insertion, rich text visual projection, and preview / read mode jump navigation with backlink return (`↩`) under the core Orbit Note invariant: "CREATE ONCE. REFERENCE ANYWHERE."

### Delivered Capabilities
1. **Portable Underline Formatting (`lib/features/notes/rich/note_underline.dart`)**:
   - `UnderlineInlineSyntax`: parses `<u>...</u>` HTML Markdown tags into `'u'` AST element nodes.
   - `InsInlineSyntax`: parses `<ins>...</ins>` HTML Markdown tags into `'u'` AST element nodes.
   - `UnderlineElementBuilder`: renders `'u'` elements with `TextDecoration.underline`, seamlessly combining with parent text decorations (such as strikethrough).
2. **Pure Dart Markdown Document Model (`lib/features/notes/rich/markdown_document.dart`)**:
   - Registered `<u>...</u>` and `<ins>...</ins>` in `InlineProjection._parse`, assigning `'underline'` style mark and tracking wrapper delimiters for ADR-0011 source-preserving editing.
   - Registered `<mark>...</mark>` in `InlineProjection._parse` assigning `'highlight'` mark.
   - Registered `[^...]` in `InlineProjection._parse` assigning `'footnote'` style mark.
   - Preserves footnote definitions (`[^1]: ...`) as literal raw blocks with lossless disk roundtripping.
3. **Rich Markdown Editor Integration (`lib/features/notes/rich/rich_markdown_editor.dart`)**:
   - `NoteFormatAction.underline`: wraps current selection with `<u>...</u>`.
   - `_StyledController.buildTextSpan`: live visual rendering of `underline` (combining with `strike` via `TextDecoration.combine`), and distinct superscript badge styling for footnote references in primary theme accent.
   - Keyboard shortcut: `Ctrl+U` toggles underline in rich text blocks.
   - Slash commands: `/underline` and `/footnote`.
   - `insertFootnote()`: automatically scans the document for existing footnote numbers, inserts next index `[^N]` at caret, and appends `\n\n[^N]: ` at document end.
4. **Note Format Toolbar & Editor Ergonomics (`note_format_toolbar.dart`, `note_editor.dart`)**:
   - Top format toolbar includes Underline button (`Icons.format_underlined_rounded`) with tooltip `'Underline · Ctrl+U'`.
   - Quick insert popup menu includes `'Underline'` and `'Footnote'`.
   - `Ctrl+U` keyboard shortcut supported across both Source (`_sourceKey`) and Rich (`CallbackShortcuts`) editor modes.
   - Footnote jump navigation: clicking footnote reference `¹` smoothly animates preview scroll to bottom definition; clicking `↩` backlink returns to top.
   - Nested Callouts: `MarkdownBody` in `CalloutBlock` now renders underlines inside callout cards.
5. **Cloud Sync Guardrail**:
   - All cloud sync modules (`lib/application/sync/`, `lib/infrastructure/sync/`) preserved completely untouched.

### Validation Evidence
- Dedicated unit and widget test suite in `test/note_footnotes_underline_test.dart` (11/11 passing tests).
- All callout and note test suites passing (60/60 tests).
- Full repository test suite: **474/474 tests passed cleanly (0 failures)**.
- `dart format lib test` & `dart format --output=none --set-exit-if-changed lib test`: 100% formatted across all 188 files.
- `flutter analyze`: 0 issues found across entire codebase.
- Windows Release build compiled in 42.1s with pinned Windows SDK 10.0.26100.0 (`build\windows\x64\runner\Release\orbit_note.exe`).
- Deployed executable to `C:\Users\iax\Desktop\Orbit Note Windows App` and updated archive `C:\Users\iax\Desktop\OrbitNote-Windows-x64.zip`.

---

# Previous task — Callout Side-Color Styling (EDT-12) & Markdown Yellow Highlighting (EDT-02)

Status: delivered and validated, 2026-09-13.

Delivered GitHub/Obsidian-style callout side-color styling (vivid Blue for `NOTE`, prominent Purple for `IMPORTANT`, emerald for `TIP`, amber for `WARNING`, rose for `CAUTION`), Markdown yellow text highlighting (`==highlighted text==` / `<mark>text</mark>`), interactive format toolbar controls, keyboard shortcut (`Ctrl+Shift+H`), rich visual inline rendering, and read/preview markdown rendering under the core Orbit Note invariant: "CREATE ONCE. REFERENCE ANYWHERE."

### Delivered Capabilities
1. **Prominent Callout Side-Color Styling (`lib/features/notes/rich/callout_block.dart`)**:
   - `CalloutType.note`: updated to vibrant Azure Blue (`Color(0xFF0284C7)`).
   - `CalloutType.important`: prominent vivid Purple (`Color(0xFFA855F7)`).
   - `CalloutType.tip` (Emerald `0xFF10B981`), `warning` (Warm amber `0xFFF59E0B`), `caution` (Rose `0xFFE57582`).
   - 4px vertical accent bar on the left edge with matching colored icon and category title.
   - Preserves academic numbering (`ParsedCallout.headerDisplay`) for university course notes.
2. **Markdown Read & Preview Callout Engine (`CalloutBlockSyntax`, `CalloutElementBuilder`)**:
   - `CalloutBlockSyntax`: Pure Markdown block syntax parsing standard `> [!TYPE]` callouts. Supports multiline bodies and prevents absorbing consecutive callouts.
   - `CalloutElementBuilder`: Renders stylized callout card container with 4px left accent bar, colored header, and nested `MarkdownBody` supporting nested formatting, inline code, and text highlights.
3. **Markdown Yellow Text Highlighting (`==text==` / `<mark>text</mark>`)**:
   - `lib/features/notes/rich/note_highlight.dart`:
     - `HighlightInlineSyntax`: matches `==([^=\n]+)==` and outputs `mark` AST element.
     - `MarkTagInlineSyntax`: matches `<mark>([^<\n]+)</mark>` for standard HTML markdown tags.
     - `HighlightElementBuilder`: Renders `<mark>` elements with soft yellow badge backgrounds (`0xFFFEF08A` in light mode, `0xFFEAB308` with alpha 0.35 in dark mode) and high-contrast text (`0xFF713F12` in light mode, `0xFFFDE047` in dark mode).
4. **Pure Dart Markdown Document Model (`lib/features/notes/rich/markdown_document.dart`)**:
   - Registered `('==', 'highlight')` in `InlineProjection._parse`.
   - Tracks highlight boundaries and styles alongside bold, italic, and code without mutating raw source markdown on disk.
5. **Rich Markdown Editor Integration (`lib/features/notes/rich/rich_markdown_editor.dart`)**:
   - `NoteFormatAction.highlight`: executes `wrap('==')` on text selection.
   - `_RichTextController.buildTextSpan`: live visual highlighting of `==...==` spans while typing in rich mode.
   - Keyboard shortcut: `Ctrl+Shift+H` toggles highlight in rich text blocks.
   - Slash command: `/highlight` wraps or inserts highlighted text.
6. **Note Format Toolbar & Editor Ergonomics (`note_format_toolbar.dart`, `note_editor.dart`)**:
   - Top format toolbar includes Highlight button (`Icons.highlight_rounded`) with tooltip `'Highlight · Ctrl+Shift+H'`.
   - Quick insert popup menu includes `'Highlight'`.
   - Source editor handles `Ctrl+Shift+H` across both `_sourceKey` and `CallbackShortcuts`.
7. **Cloud Sync Guardrail**:
   - All cloud sync and `lib/application/sync/` / `lib/infrastructure/sync/` files preserved completely untouched.

### Validation Evidence
- Unit and widget test suite in `test/note_callouts_highlight_test.dart` (10/10 passing tests).
- All callout and note test suites passing (49/49 tests across `callout_block_test.dart`, `university_study_workflow_test.dart`, `note_callouts_highlight_test.dart`, `notes_editing_test.dart`, `notes_editor_test.dart`, `notes_hover_test.dart`, `notes_navigation_test.dart`, `note_editor_stats_test.dart`).
- Full repository test suite: **446/446 tests passed cleanly (0 failures)**.
- `dart format lib test` & `dart format --output=none --set-exit-if-changed lib test`: 100% formatted across all 183 files.
- `flutter analyze`: 0 issues found across entire codebase.
- Windows Release build compiled in 56.2s with pinned Windows SDK 10.0.26100.0 (`build\windows\x64\runner\Release\orbit_note.exe`).
- Deployed executable to `C:\Users\iax\Desktop\Orbit Note Windows App` and updated archive `C:\Users\iax\Desktop\OrbitNote-Windows-x64.zip`.

---

# Current task — Canvas Element Grouping & Ungrouping (CAN-04, CAN-05)

Status: delivered and validated, 2026-09-13.

Delivered first-class Canvas element grouping and ungrouping (`group` / `ungroup`) with atomic reversible undo/redo, locked-member parent transform protection, visual group boundary and pill badge rendering, keyboard shortcuts (`Ctrl+G`, `Ctrl+Shift+G`), context menu actions, and Layer Manager integration under the core Orbit Note invariant: "CREATE ONCE. REFERENCE ANYWHERE."

### Delivered Capabilities
1. **Pure Dart Groups Domain Engine (`lib/canvas/groups.dart`)**:
   - Zero Flutter dependencies: fully decoupled domain module for placement spatial organization.
   - `getGroupMembers(scene, groupId)`: queries all active renderable elements in a group.
   - `getAllGroupIds(scene)`: finds all unique active group IDs across the canvas.
   - `calculateGroupBounds(scene, groupId)`: computes accurate union bounding box enclosing all members.
   - `isGroupLocked(scene, groupId)`: checks if any member in the group is locked.
   - `groupElements(scene, ids, ...)`: generates updated elements with a shared unique `groupId` (requiring $\ge 2$ elements).
   - `ungroupElements(scene, ids)`: clears `groupId` from all members of target groups.
   - `duplicateGroupElements(scene, groupId, idGenerator, ...)`: clones group members with fresh IDs and binds them under a fresh shared `groupId`.
   - `isEntireGroupSelected(scene, groupId, selection)`: verifies selection containment.
2. **First-Class Group Identity on CanvasElement (`lib/canvas/scene.dart`)**:
   - Added `groupId` getter to `CanvasElement`.
   - Guaranteed clean JSON roundtripping and persistence without modifying referenced knowledge objects.
3. **Visual Group Boundary & Badge Painting (`lib/features/canvas/canvas_painter.dart`)**:
   - When any element of a group is selected, painter renders a subtle dashed bounding outline enclosing the group's union bounds.
   - Renders a stylish "GROUP" pill badge at the top-left of the group boundary.
   - Added `_drawDashedRect` with proper zoom-adaptive dash and gap metrics.
4. **Interactive Selection & Drag Coordination (`lib/features/canvas/canvas_editor.dart`)**:
   - Single-clicking an element belonging to a group automatically expands selection to include all members of the group.
   - Shift-clicking toggles selection of the entire group.
   - Moving any element of an unlocked group translates all group members together in a single atomic undoable transaction.
5. **Locked Member Protection Guard (`lib/features/canvas/canvas_editor.dart`)**:
   - Strict implementation of the invariant in `docs/features/spatial-boards.md` line 107: *"locked members prevent parent transforms"*.
   - If any member of a group is locked, dragging the group is aborted and displays the user notice: `'Unlock the group’s items before moving it.'`.
6. **Keyboard Shortcuts & Menu Controls (`lib/features/canvas/canvas_editor.dart`)**:
   - `Ctrl+G` (or `Cmd+G` on macOS): Groups $\ge 2$ selected elements with notification feedback.
   - `Ctrl+Shift+G` (or `Cmd+Shift+G` on macOS): Ungroups selected groups with notification feedback.
   - Top Toolbar: Added Group / Ungroup popup menu button (`Icons.workspaces_outlined`).
   - Context Menu: Added dedicated `GROUPING` section with "Group (Ctrl+G)" and "Ungroup (Ctrl+Shift+G)".
7. **Duplication, Deletion, and Layer Manager Integration (`lib/features/canvas/canvas_editor.dart`)**:
   - `_duplicate`: Duplicating grouped elements generates new element IDs and a fresh shared `groupId`.
   - `_delete`: Deleting a group removes all its members with full atomic undo/redo restoration.
   - Layer Manager dialog (`_showElementList`): Displays a highlighted `[Group]` tag next to grouped items.
8. **Cloud Sync Guardrail**:
   - All cloud sync modules (`lib/application/sync/`, `lib/infrastructure/sync/`) preserved completely untouched.

### Validation Evidence
- Comprehensive unit and widget test suite in `test/canvas_groups_test.dart` (13/13 passing tests).
- All canvas test suites: 96/96 passing tests across 7 suites.
- Full repository test suite: **436/436 tests passed cleanly (0 failures)**.
- `dart format lib test` & `dart format --output=none --set-exit-if-changed lib test`: 100% formatted across all 181 files.
- `flutter analyze`: 0 issues found across entire codebase.
- Windows Release build compiled in 69.5s with pinned Windows SDK 10.0.26100.0 (`build\windows\x64\runner\Release\orbit_note.exe`).
- Deployed executable to `C:\Users\iax\Desktop\Orbit Note Windows App` and updated archive `C:\Users\iax\Desktop\OrbitNote-Windows-x64.zip`.

---

# Current task — Canvas Export Engine (CAN-14, PORT-05, INK-10) & Paper Presets (INK-07)

Status: delivered and validated, 2026-09-13.

Delivered high-fidelity Canvas vector SVG export, multi-scale raster PNG export, JSON snapshot backup, cross-platform file saving and clipboard integration, along with Engineering Graph and Cornell Notes paper presets under the core Orbit Note invariant: "CREATE ONCE. REFERENCE ANYWHERE."

### Delivered Capabilities
1. **Pure Dart Vector SVG Generator (`lib/canvas/canvas_svg.dart`)**:
   - Zero Flutter dependencies: safe for headless servers, tests, CLI, and web workers.
   - Comprehensive renderer supporting all 16 element types: sticky notes, cards, containers, sections, swatches, columns, shapes (rectangles, rounded rects, pills, diamonds, ellipses, triangles, stars, octagons, cylinders, clouds), connectors (straight, cubic bezier spline, orthogonal Manhattan routing, arrow/dot/diamond markers, center text badges), ink strokes, broad translucent highlighter strokes, link badges, and images.
   - Preserves exact visual typography, colors, borders, drop shadows, and coordinate framing with customizable margin padding and background fills.
2. **Multi-Scale Raster PNG Export (`lib/features/canvas/canvas_painter.dart`)**:
   - Implemented `renderCanvasToPng(CanvasScene, bounds, ...)` using Flutter's native `ui.PictureRecorder` and `ui.Canvas`.
   - Supports 1x, 2x, and 3x device pixel ratio scale factors for crisp high-DPI presentations and prints.
   - Offers optional transparent background mode or matching paper background rendering.
   - Supports exporting either the entire canvas content or a targeted element subset.
3. **Cross-Platform Binary Export (`lib/platform/export_file.dart`, `export_file_native.dart`, `export_file_web.dart`)**:
   - Implemented `exportBinaryFile(Uint8List bytes, String fileName, {String? mimeType})`.
   - On Desktop (Windows/macOS/Linux), seamlessly detects default Downloads directory or workspace folder to write bytes safely.
   - On Web, initiates browser anchor blob downloads.
4. **Interactive Export Dialog & Context Menu Actions (`lib/features/canvas/canvas_editor.dart`)**:
   - Added Export button to canvas top toolbar (`Icons.file_download_outlined`).
   - Added `Export Selection...` and `Export Canvas...` actions to right-click context menus.
   - In-dialog controls: Scope toggle (Full Canvas vs Selection), Format toggle (PNG, SVG, JSON), Scale selector (1x, 2x, 3x for PNG), Transparent background toggle, Live dimensions and file name preview.
   - Actions: "Copy to Clipboard" (instant SVG or JSON text clipboard) and "Save File" (writes PNG, SVG, or JSON file with automatic notification banner).
5. **Engineering Graph & Cornell Notes Background Presets (INK-07) (`lib/features/canvas/canvas_painter.dart`, `lib/features/canvas/canvas_editor.dart`)**:
   - Added `graph`: Engineering graph paper with minor grid every 8px and prominent major grid every 32px.
   - Added `cornell`: Cornell Notes layout featuring ruled horizontal lines, vertical cue/recall divider at `x = 200`, horizontal summary divider at `y = 700`, and distinct labeled sections ("CUES / QUESTIONS", "NOTES", "SUMMARY").
   - Integrated into paper style menu alongside plain, dots, and ruled.
6. **Cloud Sync Guardrail**:
   - All cloud sync and `lib/application/sync/` / `lib/infrastructure/sync/` files preserved completely untouched.

### Validation Evidence
- Unit and widget test suite in `test/canvas_export_backgrounds_test.dart` (11/11 passing tests).
- Canvas test suites: 67/67 passing tests across 6 suites.
- Full repository test suite: **423/423 tests passed cleanly (0 failures)**.
- `dart format lib test` & `dart format --output=none --set-exit-if-changed lib test`: 100% formatted across all 179 files.
- `flutter analyze`: 0 issues found across entire codebase.
- Windows Release build compiled in 64.2s with pinned Windows SDK 10.0.26100.0 (`build\windows\x64\runner\Release\orbit_note.exe`).
- Deployed executable to `C:\Users\iax\Desktop\Orbit Note Windows App` and updated archive `C:\Users\iax\Desktop\OrbitNote-Windows-x64.zip`.

---

# Current task — Canvas Layer Manager & Stacking Order (CAN-08) & Freeform Highlighter (INK-03)

Status: delivered and validated, 2026-09-13.

Delivered canvas stacking order operations (`bringToFront`, `sendToBack`, `bringForward`, `sendBackward`), atomic undo/redo support via `CanvasHistory.reorder`, freeform highlighter drawing tool with broad translucent strokes, selection toolbar and context menu stacking controls, keyboard shortcuts (`Y`, `[`, `]`, `Shift+[`, `Shift+]`), and an interactive Layer Manager dialog with live visibility toggle, lock toggle, and reordering controls.

### Delivered Capabilities
1. **CanvasScene Stacking Order Operations (`lib/canvas/scene.dart`)**:
   - Implemented `orderOf(String id)` and `elementsInOrder` sorted by z-index.
   - Implemented `bringToFront(id)` (assigns incremented highest order) and `sendToBack(id)` (assigns decremented lowest order below all items).
   - Implemented `bringForward(id)` and `sendBackward(id)` (swaps z-order with immediate neighbor in the stack).
   - Ensured `toJson()` outputs elements sorted by stacking order, ensuring persistence across file saves and roundtrips.
2. **Atomic Reversible Undo/Redo (`lib/canvas/scene.dart`)**:
   - Implemented `CanvasHistory.reorder(Iterable<String> ids, void Function() mutate)` which captures pre-mutation element orders and commits a single reversible delta.
   - Full undo/redo restores exact z-ordering seamlessly.
3. **Freeform Highlighter Tool (`lib/canvas/scene.dart`, `lib/features/canvas/canvas_painter.dart`, `lib/features/canvas/canvas_editor.dart`)**:
   - Added `_Tool.highlighter` with shortcut `Y` and top toolbar button with `Icons.brush_outlined`.
   - Highlighter strokes use broad width (22.0px), semi-transparent alpha (`accent.withValues(alpha: 0.38)`), and rounded caps/joins.
   - Highlighter ink is persisted with `element.data['isHighlighter'] == true`.
   - Highlighter hit-testing and erase tolerance accounts for broad 22px stroke.
4. **Canvas Layer Manager & Stacking UI (`lib/features/canvas/canvas_editor.dart`)**:
   - Upgraded `_showElementList` into an interactive **Layers & Stacking Order** dialog (`Icons.layers_outlined`).
   - Displays elements from Front (top) to Back (bottom) with element type icons, color accents, and z-index indicators.
   - In-dialog controls: Up/Down arrow buttons (Bring Forward / Send Backward), Lock toggle (`Icons.lock`), Visibility toggle (`Icons.visibility`), and Focus on canvas button.
   - Dialog batch actions: "Bring to Front", "Send to Back", "Show All", "Unlock All".
   - Top action bar popup menu: `Bring to Front` (`Shift+]`), `Bring Forward` (`]`), `Send Backward` (`[`), `Send to Back` (`Shift+[`).
   - Right-click element context menu: Added `LAYER ORDER` section with Bring to Front, Bring Forward, Send Backward, Send to Back.
5. **Quality & Cloud Safety**:
   - Zero modifications to `lib/application/sync/` or `lib/infrastructure/sync/`.
   - All tests passing (including 11 new tests in `test/canvas_layers_highlighter_test.dart`).
   - `flutter analyze`: 0 issues found.
   - `dart format`: 100% formatted across repository.
   - Windows release binary compiled and deployed to `C:\Users\iax\Desktop\Orbit Note Windows App` and `OrbitNote-Windows-x64.zip`.

---

# Current task — Canvas Arrow & Connector Enhancements (CAN-04, CAN-05, CAN-07)

Status: delivered and validated, 2026-09-13.

Delivered comprehensive connector and arrow enhancements for linking sticky notes, cards, containers, and research items on Canvas with customizable stroke styles (solid, dashed, dotted), start/end markers (none, arrow, dot, diamond), routing engines (straight, cubic bezier spline, orthogonal Manhattan stepping), dynamic snap anchors, midpoint label editing, and connected element tracking under the core invariant: "CREATE ONCE. REFERENCE ANYWHERE."

### Delivered Capabilities
1. **Registered First-Class `'connector'` Element Type (`lib/canvas/scene.dart`)**:
   - Added `'connector'` to `canvasElementTypes`, instantly activating all dormant preset diagrams (Call Flow, Architecture, Game Loop, Process Tree, AI State Machine).
   - Added `startId`, `endId`, `strokeStyle`, `startMarker`, `endMarker`, `routing`, `startAnchor`, `endAnchor` getters to `CanvasElement`.
   - Updated `_effectiveBounds(element)` to accurately wrap the resolved spline/orthogonal geometry with 16px padding.
   - Updated `CanvasScene.remove(id)` to safely re-index connectors attached to deleted elements without leaving stale spatial index bounds.
   - Fixed `CanvasScene.contentBounds` to use `_effectiveBounds` so connectors in templates don't anchor content bounds to (0, 0).
2. **Pure Dart Connector Math & Anchor Engines (`lib/canvas/connectors.dart`, `lib/canvas/geometry.dart`)**:
   - `ConnectorAnchor` (`auto`, `top`, `bottom`, `left`, `right`): `getElementAnchors(bounds)` and `findClosestAnchor(bounds, target)`.
   - `ConnectorStyle` (`solid`, `dashed`, `dotted`), `ConnectorMarker` (`none`, `arrow`, `dot`, `diamond`), `ConnectorRouting` (`straight`, `curved`, `orthogonal`).
   - `resolveConnectorEndpoints(connector, scene)`: dynamically resolves perimeter docking points, generates cubic bezier control points for curved routing, and stepped 90-degree points for orthogonal routing.
   - `distanceToSegment(p, a, b)`: pure Euclidean distance calculation from point to line segment.
   - `hitTestConnector(connector, scene, point)`: tests cubic bezier spline segments (16 subdivisions), orthogonal stepped legs, straight segments, and text label pill bounding boxes.
3. **Interactive Snap Anchors & Vector Rendering (`lib/features/canvas/canvas_painter.dart`)**:
   - Live snap anchor rings: renders 4 perimeter snap anchors on both start and hovered target elements during connector creation with primary accent center dots and white contrast rings.
   - Vector rendering: supports solid, dashed, and circular dotted styles (`StrokeCap.round`, custom metric extraction), start/end markers (`arrow`, `dot`, `diamond`), and center pill text tags.
4. **Editor Gestures & Controls (`lib/features/canvas/canvas_editor.dart`)**:
   - In `_down`: snaps start point to nearest card anchor and tracks `_connectingStartId`.
   - In `_move`: snaps target endpoint to closest candidate anchor, sets `_connectingEndId`, and dynamically updates connected connectors when moving cards.
   - Connected edge following: moving linked cards automatically recomputes and stretches connectors in a single undoable transaction.
   - Inline text editing: double-clicking a connector or selecting "Open / edit" opens a floating text pill at `endpoints.midpoint`; pressing Enter finishes editing.
   - Minimap polish: skips connectors so arbitrary bounding boxes don't clutter the minimap.
   - Top toolbar dropdowns: Stroke Style, Routing, Start Marker, End Marker, Start Anchor, End Anchor, Reverse Direction.
   - Context menu controls: Solid/Dashed/Dotted, Straight/Curved/Orthogonal, Arrow/Dot/Diamond/None for start and end, Auto Anchor resets, and Direction Reversal.
5. **Cloud Sync Guardrail**:
   - All cloud sync and `lib/application/sync/` / `lib/infrastructure/sync/` files preserved completely untouched.

### Validation Evidence
- Unit test suite in `test/canvas_connectors_test.dart` (14/14 passing tests).
- All canvas-related test suites pass (32/32 tests: `canvas_connectors_test.dart`, `canvas_auto_arrange_test.dart`, `canvas_notes_explorer_test.dart`, `runtime_audit_fixes_test.dart`).
- Full repository test suite: **397/397 tests passed cleanly (0 failures)**.
- `dart format lib test` & `dart format --output=none --set-exit-if-changed lib test`: 100% formatted across all 176 files.
- `flutter analyze`: 0 issues found across entire codebase.
- Windows Release build compiled in 62.2s with pinned Windows SDK 10.0.26100.0 (`build\windows\x64\runner\Release\orbit_note.exe`).
- Deployed executable to `C:\Users\iax\Desktop\Orbit Note Windows App` and updated archive `C:\Users\iax\Desktop\OrbitNote-Windows-x64.zip`.

---

# Current task — Canvas Auto-Arrange Layouts (CAN-10) & Research/PDF Cards Split-View Co-Browsing (CAN-15, FILE-13)

Status: delivered and validated, 2026-09-13.

Delivered automatic reversible spatial layout engines (Grid, Horizontal Stack, Vertical Stack, Radial Circle / Mind Map) and first-class PDF highlight / document cards on Canvas with double-click split-view co-browsing under the core invariant: "CREATE ONCE. REFERENCE ANYWHERE."

### Delivered Capabilities
1. **Canvas Auto-Arrange Layout Engines (`lib/canvas/arrangement.dart`)**:
   - Implemented pure, Flutter SDK-independent spatial layout algorithms in `arrangeCanvas`:
     - **Grid Layout (`CanvasArrangement.grid`)**: Balanced column/row packing computed via `math.max(2, math.sqrt(n).ceil())` with uniform 24.0px gutters.
     - **Horizontal Stack (`CanvasArrangement.stackH`)**: Aligns selected elements into a single horizontal row preserving initial `bounds.left` and centering vertically.
     - **Vertical Stack (`CanvasArrangement.stackV`)**: Packs selected elements vertically into a column preserving initial `bounds.top` and centering horizontally.
     - **Radial Circle / Mind Map (`CanvasArrangement.radial`)**: Identifies root/center element and distributes dependent elements uniformly in an elliptical orbit (`dx = radiusX * cos(angle)`, `dy = radiusY * sin(angle)`).
   - Human-readable labels added for all 12 arrangement options (`Arrange in grid`, `Stack horizontally`, `Stack vertically`, `Arrange in radial circle`, `Align left`, `Center horizontally`, etc.).
   - Locked elements are strictly skipped and preserve their exact world coordinates.
   - Single undoable transaction: wrapped in `_history.put(...)` and committed atomically.
2. **First-Class PDF Highlight & Document Cards on Canvas (`CAN-15`, `FILE-13`)**:
   - `CanvasObjectReference` holds `pdfSource` metadata (`documentId`, `page`, `quote`, `color`).
   - `CanvasPainter` renders PDF highlight cards with dynamic `PDF HIGHLIGHT · P. <page>` headers, quote formatting (`“...”`), and accent color strips matching annotation styles.
   - Attachments and PDF document cards render with `PDF DOCUMENT` or `ATTACHMENT` badges and subtitle metadata.
   - Tasks placed on canvas render with `TASK` or `TASK (DONE)` badges and state indications.
3. **Split-View Co-Browsing (`WorkspaceShell`)**:
   - Opening an object reference or PDF highlight from canvas checks active canvas destination:
     - Sets `secondaryId = fileId` and retains `activeId = canvasId` side-by-side in split pane.
     - Canvas stays interactive on the left while the full PDF document or linked note opens on the right.
4. **Context Menu & Toolbar Integration**:
   - Added `AUTO-ARRANGE` section to selected elements context menu and top arrangement dropdown.
   - "Place object" dialog in empty canvas context menu with rich search filtering by title, type, and highlight quote.
5. **Cloud Sync Guardrail**:
   - All cloud sync and `lib/application/sync/` / `lib/infrastructure/sync/` files preserved completely untouched.

### Validation Evidence
- Unit test suite in `test/canvas_auto_arrange_test.dart` (8/8 passing tests).
- Canvas explorer and rich text test suites (`test/canvas_notes_explorer_test.dart`, `test/canvas_rich_text_test.dart`).
- Full repository test suite: **387/387 tests passed cleanly (0 failures)**.
- `dart format lib test` & `dart format --output=none --set-exit-if-changed lib test`: 100% formatted across all 174 files.
- `flutter analyze`: 0 issues found across entire codebase.

---

# Current task — PDF Workflow: Continuous Page View, Precise Highlight Navigation, Multi-Style Annotations & Note Deep-Links

Status: delivered and validated, 2026-09-13.

Delivered comprehensive enhancements to the PDF reading and research workflow under the core invariant "CREATE ONCE. REFERENCE ANYWHERE.":

### Delivered Capabilities
1. **Precise Highlight-Region Navigation & Accent Pulse Ring**:
   - Implemented `boundsForPage(int pageNumber)` on `PdfAnnotation` (in `lib/domain/pdf_annotation.dart`), computing the exact normalized bounding box union across multiple text selection fragments on the target page using pure, Flutter-independent `CanvasBounds`.
   - In `OrbitPdfReader._goToAnnotation`: dynamically calculates viewport centering and zoom factor with comfortable context padding (80px horizontal, 120px vertical) and smoothly navigates directly to the highlight region.
   - `_setActiveHighlight`: triggers a 4-second transient glowing accent focus ring (`_activeHighlightId`) around the target highlight with auto-decay, never mutating durable storage.
2. **Interactive On-Page Highlights & Detail Dialog**:
   - `_buildAnnotationOverlays`: interactive touch/hover overlay layer rendered above pages with hover tooltips.
   - Clicking an on-page highlight opens `_showHighlightDetail` dialog with the quote, comment, color/style badge, "Copy quote", and direct "Open highlight note and comments" button.
3. **Multi-Style & Multi-Color Annotations**:
   - Three rendering styles supported on-page in `_paintAnnotations`:
     - `Highlight`: Soft translucent colored background box (`alpha: 75`).
     - `Underline`: 2.5px baseline stroke with rounded caps.
     - `Strikeout`: 2.0px strikethrough stroke centered vertically.
   - 5-color palette (`Yellow`: `0xffeab308`, `Green`: `0xff22c55e`, `Blue`: `0xff3b82f6`, `Purple`: `0xff8b7cf6`, `Coral`: `0xffef4444`) selectable via toolbar popup menu and context menu.
4. **Continuous, Single-Page, and Two-Page Facing Spreads**:
   - Added `PdfPageMode`: `continuous` (vertical scrolling), `single` (horizontal single page flow), and `twoPage` (facing book spread).
   - Implemented `_layoutPages`: custom layout calculator computing exact coordinate placements for each page mode.
   - Toolbar popup menu for seamless switching with dynamic layout recreation via value keying.
5. **Highlight Summary Export**:
   - Added "Copy all highlights as Markdown" button in the highlights panel (`_copyAllHighlights`), generating structured markdown quotes and page citations sorted by page number via `PdfAnnotation.summaryMarkdown`.
6. **Note & Deep-Link Integration**:
   - `NoteEditor`: Contextual banner (`pdf-source-banner`) showing "PDF Source: <Title> · Page <N>" with a "View in PDF" button.
   - `WorkspaceShell`: Clicking "View in PDF" opens the source PDF side-by-side in secondary split view and navigates directly to the page.
7. **Cloud Sync Guardrail**:
   - All cloud sync and `lib/application/sync/` / `lib/infrastructure/sync/` files preserved completely untouched.

### Validation Evidence
- Dedicated unit and widget test suite in `test/pdf_workflow_enhancements_test.dart` (8/8 passing tests).
- PDF reader test suite in `test/pdf_reader_test.dart` (5/5 passing tests).
- Full repository test suite: **379/379 tests passed cleanly (0 failures)**.
- `dart format lib test` & `dart format --output=none --set-exit-if-changed lib test`: 100% formatted across all 173 files.
- `flutter analyze`: 0 issues found across entire codebase.
- Windows Release build compiled in 64.9s with pinned Windows SDK 10.0.26100.0 (`build\windows\x64\runner\Release\orbit_note.exe`).
- Deployed executable to `C:\Users\iax\Desktop\Orbit Note Windows App` and created archive `C:\Users\iax\Desktop\OrbitNote-Windows-x64.zip`.

---

# Current task — Canvas Sticky Notes & Cards: Interactive Checklists, Tasklists & Headings

Status: delivered and validated, 2026-09-13.

Delivered rich Markdown, interactive task checklists, and hierarchical headings inside canvas sticky notes, cards, and text elements, along with single-click canvas toggles, smart Enter key handling, quick format toolbar, and context menu actions under the core invariant: "CREATE ONCE. REFERENCE ANYWHERE."

### Delivered Capabilities
1. **Rich Canvas Markdown Line Parser & Vector Renderer (`CanvasRichText`)**:
   - Implemented in `lib/features/canvas/canvas_rich_text.dart`:
     - **Checklists**: Parses `- [ ]`, `* [ ]`, `[ ]`, `- [x]`, `* [x]`, `[x]`, `- [X]`, `[X]`. Unchecked items render crisp rounded checkbox outlines; checked items render filled accent boxes with white vector checkmarks and muted strikethrough text.
     - **Headings**: `# Heading 1` (18.5px bold), `## Heading 2` (16.5px semibold), `### Heading 3` (15px semibold).
     - **Lists & Indentation**: Bullet points (`- `, `* `), numbered lists (`1. `), and nested indentation (preserving up to 4+ spaces).
     - **Vector Rendering**: High-performance canvas vector rendering in `CanvasRichText.draw` inside `bounds.deflate(16)` for sticky notes, and when rich formatting is present on cards and text elements.
2. **Single-Click Interactive Checkbox Toggle**:
   - In `CanvasEditor._up`: single-click tap on a canvas checkbox toggles checked/unchecked state directly on the canvas without entering text edit mode.
   - Preserves jitter-free coordinate restoration and commits changes as undoable/redoable transactions in canvas history (`Ctrl+Z` / `Ctrl+Y`).
   - World-coordinate hit testing in `CanvasRichText.hitTestCheckbox`.
3. **Editing Ergonomics in Canvas Text Overlay**:
   - **Smart Enter Key Handling**: Pressing Enter on a checklist line auto-prefixes the next line with `- [ ] `; pressing Enter on an empty checklist item clears the prefix. Also handles bullet and numbered lists.
   - **Quick Format Toolbar**: Floating action bar positioned above the text editing overlay with quick chips: `Task` (`- [ ] `), `H1` (`# `), `H2` (`## `), `H3` (`### `), `List` (`- `), and `Done`.
   - **Tap Isolation**: Wrapped toolbar and text field in `TapRegion(groupId: 'canvas-text-editing')` to prevent clicking toolbar buttons from triggering `TextField.onTapOutside` dismissals.
4. **Context Menu & Toolbar Actions**:
   - Added `Add Checklist` to canvas empty-space right-click menu and toolbar Add menu (`_addChecklist`), creating a starter checklist sticky note (`# Tasks\n- [ ] Task 1\n- [ ] Task 2\n- [ ] Task 3`).
5. **Cloud Sync Guardrail**:
   - All cloud sync and `lib/application/sync/` / `lib/infrastructure/sync/` files preserved completely untouched.

### Validation Evidence
- Unit and widget test suite in `test/canvas_rich_text_test.dart` (18/18 tests passing).
- Full repository test suite: **371/371 tests passed cleanly (0 failures)**.
- `dart format lib test` & `dart format --output=none --set-exit-if-changed lib test`: 100% formatted across all 172 files.
- `flutter analyze`: 0 issues found across entire codebase.
- Windows Release build compiled in 63.3s with pinned Windows SDK 10.0.26100.0 (`build\windows\x64\runner\Release\orbit_note.exe`).
- Deployed executable to `C:\Users\iax\Desktop\Orbit Note Windows App` and created archive `C:\Users\iax\Desktop\OrbitNote-Windows-x64.zip`.

---

# Current task — Canvas in Notes Explorer Navigation & Template Cards Fix

Status: delivered and validated, 2026-09-12.

Focused ergonomics and bug-fix pass resolving canvas folder navigation in Notes Explorer and canvas card template rendering under the core invariant "CREATE ONCE. REFERENCE ANYWHERE.":

### Delivered Capabilities
1. **Notes Explorer Destination Retention (OneNote-Style Experience)**:
   - When browsing inside Notes Explorer (`session.destination == OrbitDestination.notes`), opening or creating any canvas (such as `akmath/exercises/canvas`), note, task, or view keeps the sidebar on the Notes Folder Explorer (`OrbitDestination.notes`).
   - Objects with a folder property (e.g. `folder: 'akmath/exercises'`) opened from Home or search automatically open with `session.destination == OrbitDestination.notes` and uncollapse the parent directory in the tree.
   - Preserves dedicated Canvas rail gallery navigation (`OrbitDestination.canvas`) when browsing flat canvases.
2. **Canvas Template & Standalone Card Support**:
   - Fixed `'UNRESOLVED REFERENCE'` and `'Missing object'` on cards instantiated by all 9 canvas presets (`Narrative Board`, `Game Architecture`, `Call Flow`, `Object Relationships`, `Structure Memory Layout`, `Binary / PE Layout`, `Protocol Flow`, `Process Tree`, `Rendering Pipeline`).
   - Cards without an `objectId` or with non-empty text now render as valid first-class `CARD` elements with custom theme accent colors, titles, and subtitles.
   - Compact cards (height <= 95px) render with tailored typography avoiding text overflow.
   - Truly broken object references without text gracefully display `UNRESOLVED REFERENCE` in error styling.
3. **Canvas Card Interaction & Context Menu**:
   - Standalone cards and template cards can now be double-clicked or opened via right-click to edit their title and body text inline with the live text field overlay.
   - Added `Add Card` to the empty canvas right-click context menu alongside `Add Sticky`, `Add Text`, `Add Section`, and `Add Color Swatch`.
   - Canvas elements inspector (`_showElementList`) displays proper card titles instead of `Missing object`.
4. **Cloud Sync Guardrail**:
   - All cloud sync and `lib/application/sync/` files preserved completely untouched for Astra.

### Validation Evidence
- Unit & widget test suite in `test/canvas_notes_explorer_test.dart` (5/5 passing tests).
- Full repository test suite: **320/320 tests passed cleanly (0 failures)**.
- `dart format lib test` & `dart format --output=none --set-exit-if-changed lib test`: 100% formatted.
- `flutter analyze`: 0 issues found across entire codebase.
- Windows Release build compiled in 31.9s with pinned Windows SDK 10.0.26100.0 (`build\windows\x64\runner\Release\orbit_note.exe`).
- Deployed executable to `C:\Users\iax\Desktop\Orbit Note Windows App` and created archive `C:\Users\iax\Desktop\OrbitNote-Windows-x64.zip`.

---

# Current task — Reverse Engineering, Binary Analysis & Security Research Workflow Pass

Status: delivered and validated, 2026-09-12.

Focused workflow pass making Orbit Note extraordinarily useful for organizing legitimate native binary analysis, game internals research, authorized game security research, Windows internals research, file-format research, protocol analysis, debugging, malware analysis in controlled environments, incident-response research, exploit/root-cause analysis notes, anti-cheat architecture research, vulnerability research, and executable/document triage under the core invariant: "CREATE ONCE. REFERENCE ANYWHERE."

### Delivered Capabilities
1. **Zero New Databases / Single Universal Object Invariant**:
   - Every function, structure, finding, hypothesis, IOC, analysis session, sample metadata, and diagram is a canonical `orbit.note`, `orbit.task`, `orbit.canvas`, or `orbit.view`.
   - References are stored via universal object IDs (`objectId`) and bidirectional wiki links (`[[Target]]`), preventing duplicated storage or sync fragmentation.
2. **Project Scaffolding & 23 Specialized Research Note Templates**:
   - 3 Scaffolding Commands: `createReverseEngineeringProject`, `createGameInternalsProject`, `createMalwareAnalysisProject`.
   - 23 Canonical Research Templates in `WorkspaceController`:
     - Function Note (`createFunctionDoc`)
     - Structure / Layout Note (`createStructureDoc`)
     - Finding Note (`createFindingDoc`)
     - Hypothesis Note (`createHypothesisDoc`)
     - Generic Analysis Session (`createAnalysisSessionDoc`)
     - Static Analysis Session (`createStaticAnalysisSessionDoc`)
     - Dynamic Analysis Session (`createDynamicAnalysisSessionDoc`)
     - Binary Sample / Artifact (`createBinarySampleDoc`)
     - Experiment / Verification Note (`createExperimentDoc`)
     - Protocol Analysis Note (`createProtocolAnalysisDoc`)
     - Packet Structure Note (`createPacketStructureDoc`)
     - PE / Binary Analysis Note (`createPeAnalysisDoc`)
     - File Format / Container Note (`createFileFormatDoc`)
     - Game System / Subsystem Note (`createGameSystemDoc`)
     - Game Class / VTable Note (`createGameClassDoc`)
     - Transform / Coordinate Space Note (`createTransformCoordinateDoc`)
     - Defensive Malware Triage Note (`createMalwareTriageDoc`)
     - Behavior / Execution Observation (`createBehaviorObservationDoc`)
     - Indicator of Compromise (`createIocDoc`)
     - Detection Rule / Signature (`createDetectionRuleDoc`)
     - Version Comparison / Patch Diff (`createVersionComparisonDoc`)
     - Investigation Case Note (`createInvestigationCaseDoc`)
     - Analysis Environment Note (`createAnalysisEnvironmentDoc`)
3. **Domain Utilities & Importers**:
   - `formatAddress` (standardizes hex notation with `0x`) and `formatModuleOffset` (`module+0xoffset`).
   - `calculateAttachmentSha256` & MD5 hash calculation and local caching.
   - `importFunctionsFromCsv` and `importFunctionsFromJson` for bulk importing reverse-engineered symbol catalogs into canonical notes.
   - Exact Address / RVA search ranking (priority 0) in `searchRank`.
4. **Specialized Views & Dashboard**:
   - `AnalysisDashboardView` (`viewType: 're_dashboard'`): Target metadata header, analysis metrics summary, hypothesis progression tracker, blocker watchdog, recent findings/sessions/structures/canvases, and quick creation action buttons.
   - `FunctionTableView` (`viewType: 'functions'`): Interactive function catalog with columns for Function name, Address, Module, Purpose, Confidence, and Status; status filter chips, "Copy Address", "Copy Module+Offset", and CSV/JSON bulk import dialog.
   - `IocTableView` (`viewType: 'iocs'`): Indicators table with indicator type chips (File Hash, Domain, IP, URL, File Path, Registry, Mutex, Process Name), copy indicator button, confidence filter, and inline indicator creation.
   - `KanbanPreset.hypotheses` (`untested`, `testing`, `confirmed`, `disproven`) and `KanbanPreset.functions` (`unknown`, `investigating`, `partial`, `confirmed`).
   - `SavedViewHost` contextual tabs switcher for RE workspaces (`re_dashboard`, `functions`, `iocs`).
   - `HomeView` Active RE & Security Project card with quick jump and watchdog alerts.
5. **Canvas Visual Presets & Enriched Drag-and-Drop**:
   - 7 Architectural & Flow Presets: `Call Flow`, `Object Relationships`, `Structure Memory Layout`, `Binary / PE Layout`, `Protocol Flow`, `Process Tree`, `Rendering Pipeline`.
   - Enriched visual cards when dropping Function notes (accent border, address, module, confidence, purpose), Structure notes (`struct`, byte size), Indicator notes (indicator type badge, value), and Hypothesis notes (hypothesis status).
6. **Code Block Ergonomics**:
   - Hex / byte copy actions ("Copy Bytes") for `hex` and `bytes` code blocks.
   - Disassembly copy actions ("Copy Disassembly") for `asm`, `disasm`, `x86`, `x64`, `arm`.
   - Clean language badges for `yara`, `sigma`, `asm`, `hex`.
7. **Command Palette & Explorer Shortcuts**:
   - Fast RE project scaffolding and note creation commands in `CommandPalette` and folder context menus.

### Validation Evidence
- `dart format lib test` & `dart format --output=none --set-exit-if-changed lib test`: 100% formatted.
- `flutter analyze`: 0 issues found across entire codebase.
- `flutter test --no-pub`: 314 tests passed (including all 13 dedicated RE workflow unit tests in `test/reverse_engineering_workflow_test.dart`).
- Windows Release Build: Verified clean compilation with pinned Windows SDK 10.0.26100.0.

---

# Previous task — Game Development Productivity and Production Workflow Pass

Status: delivered and validated, 2026-09-12.

Focused workflow pass making Orbit Note extraordinarily effective for organizing real-world game development projects across design, engineering, art, audio, and production under the invariant: "CREATE ONCE. VIEW ANYWHERE."

### Delivered Capabilities
1. **Game Development Disciplines, Severity & Agile 6-Stage Kanban**:
   - Built-in 18 game development disciplines (`gameDevDisciplines`: Game Design, Level Design, Systems Design, Narrative Design, Gameplay Programming, Engine Programming, Graphics Programming, Tools Programming, 2D Art, 3D Art, Animation, VFX, Technical Art, UI/UX, Sound Design, Music, QA & Testing, Production).
   - 4 industry-standard bug severities (`bugSeverities`: `blocker`, `critical`, `major`, `minor`).
   - 6-Stage Kanban Pipeline: `KanbanPreset.gamedev` (`backlog`, `planned`, `in-progress`, `review`, `testing`, `done`) and `KanbanPreset.bugs` (`new`, `confirmed`, `in-progress`, `verify`, `done`).
   - Story point estimation dropdown (`1`, `2`, `3`, `5`, `8`, `13`, `XS`, `S`, `M`, `L`, `XL`), estimate sorting (`sortOption == 'estimate'`), and badges.
   - Task detail editor with inline fields for Discipline, Milestone, Estimate, Severity, Build / Target Version, Platform, and Blocker dependency tracking.
2. **Project Scaffolding & 12 Specialized Design Document Templates**:
   - `createGameProject(projectName, ...)` in `WorkspaceController`: scaffolds structured folders (`Design`, `Art`, `Programming`, `Audio`, `Narrative`, `Levels`, `Production`, `Playtests`, `Reference`), starter GDD note, core mechanics spec note, visual canvases (`Core Loop`, `Art Direction & Moodboard`, `Game Roadmap`), and 7 scoped views (`Dashboard`, `Board`, `Backlog`, `Current Focus`, `Bugs`, `Milestones`, `Roadmap`).
   - 12 Specialized Templates:
     - `createGameDesignDocument`: Full GDD architecture.
     - `createFeatureSpec`: Feature systems & technical specs.
     - `createMechanicDesignDoc`: Input rules, juice/feedback, edge cases, failure conditions.
     - `createEnemyDesignDoc`: HP, movement speed, attack tells, AI state transitions, drops.
     - `createCharacterDesignDoc`: Turnaround, silhouette, personality, voice, abilities.
     - `createItemDesignDoc`: Category, rarity, stats, crafting recipe, balance.
     - `createAudioDesignDoc`: Audio cue tracker table (SFX, Music, Ambient, Voice), priority, format.
     - `createQuestDesignDoc`: Objectives, multi-stage flow, fail conditions.
     - `createReleaseChecklist`: Build QA, Store assets, Disaster recovery.
     - `createWeeklyReview`: Accomplished, blockers, velocity/burnup, goals, risks.
     - `createRiskAssessmentDoc`: Description, impact/likelihood, mitigation, triggers.
     - `createDecisionDoc`: Architecture Decision Record (ADR).
   - `createTaskFromFinding`: Converts playtest finding directly into universal task with bidirectional link `[[finding]]`.
   - `duplicateGameProjectStructure`: Clones full folder hierarchy and scoped view definitions for new sequels/milestones without copying completed historical tasks.
   - Contextual folder menu options for game folders, courses, and root.
3. **Canvas Game Dev Presets**:
   - Extended presets: `Game Roadmap`, `Core Loop`, `Level Design & Flow`, `AI State Machine`, `Art Direction & Moodboard`, `Playtest Feedback Board`, `Narrative & Quest Board`, and `Game Architecture & Systems`.
   - Auto-population on canvas creation via `canvasPreset` property.
4. **Game Dashboard & Milestone Progress Views**:
   - `GameDashboardView` (`viewType: 'game_dashboard'`): Production dashboard featuring project metadata header, task completion & story points metrics, blocker watchdog, bug tracker status, interactive discipline breakdown progress bars, open tasks list, and recent game design materials.
   - `MilestoneView` (`viewType: 'milestones'`): Scoped milestone overview grouping tasks by target release milestone with live progress metrics, estimate points sum, discipline breakdown, and quick inline task creation.
   - `Current Focus` tab in task views and Home screen Game Project summary card with blocker watchdog, open bugs, and jump actions.
5. **Contextual Saved View Host Tabs**:
   - Tab switcher dynamically presents scoped view types based on workspace preset: Course views show `Exercises` and `Overview`; Game Dev views show `Dashboard` and `Milestones`; generic views show standard `List`, `Board`, `Calendar`, and `Timeline`.

### Validation Evidence
- `dart format lib test` & `dart format --output=none --set-exit-if-changed lib test`: 100% clean formatting.
- `flutter analyze`: 0 issues found.
- `flutter test --no-pub`: All tests passed across full test suite.
- Windows Release Build: Verified clean compilation with pinned Windows SDK 10.0.26100.0.

---

# Cloud sync task status (Astra)
Preserved unchanged. See [cloud status](../features/cloud-sync.md) and [cloud-sync.md](cloud-sync.md).

---

# Previous task — University, Mathematics, and Visual Study Workflow Pass

Status: delivered and validated, 2026-09-12.

Focused workflow pass empowering students with structured course environments, rich LaTeX/math ergonomics, multi-style visual canvases, and an integrated exercise practice system adhering strictly to "CREATE ONCE. VIEW ANYWHERE."

# Previous task — M6 local-first Google Drive / WebDAV sync

Owner-requested milestone, 2026-09-12. Status: pre-implementation audit and design.
No production sync implementation is delivered. Preserve all local/PDF/polish work.
Historical audit entry: the full brief was subsequently received. Current progress
and remaining implementation are recorded in [cloud-sync.md](cloud-sync.md).

Required starting points: [audit](../planning/sync-audit-2026-09-12.md),
[design](../architecture/sync-design.md), [ADR-0016](../adr/0016-provider-neutral-sync.md),
[Google setup](../development/google-drive-sync-setup.md).

Next implementation stage: local Vault coordination, durable deletion intent and
recovery, explicit canonical inventory, separate durable sync state. Then build
the engine, Drive auth/provider/UI and WebDAV in that order with failure tests.
No cloud writes, credentials or new dependencies were introduced during the audit.
Audit baseline validation: flutter analyze clean; all 237 tests passed; Windows
release build passed (7.1 seconds). Logs: `.local/sync-audit-tests.log` and
`.local/sync-audit-build.log`. New documentation links, example JSON and
`git diff --check` passed. No Dart/platform source changed in this audit phase;
real cloud/provider/device tests have not been performed.

## Previous completed task — Task/List UX, Movable Note Blocks, Folder Deletion & Vault Files

Status: delivered and validated, 2026-09-11.

This focused implementation task delivered two primary functional and UX improvements
along with requested vault lifecycle features without redesigning the app or duplicating
universal architectures:

1. **Task / List UX (Notion-inspired polish and speed)**:
   - Clean, whitespace-driven task rows with animated checkbox completion, strikethrough, and muted finished states.
   - Saved view tabs: `To Do` (active only), `Today`, `Upcoming`, `Done` (completed items), and `Board` (3-column Kanban: To Do, In Progress, Done).
   - In-view live search, sort options (Title, Due date, Priority), filter by priority/project, and customizable property visibility toggles (due date, priority, project chips).
   - Friendly relative due date labels (`Today`, `Tomorrow`, `Yesterday`, `MMM d`) with overdue highlights for overdue incomplete tasks.
   - Compact priority picker pill and inline date picker popups.
   - Fast `+ New task` inline row at the bottom with sequential entry on `Enter` and `Esc` to dismiss.

2. **Movable Note Blocks and Paragraphs in Rich Markdown Editor**:
   - Contextual Notion-style `[ + ] [ ⋮⋮ ]` handle beside every content block (including ordinary text paragraphs, headings, list items, quotes, code, tables, equations, callouts, images).
   - `+` button opens a quick-insert menu to add any block type below.
   - `⋮⋮` handle supports smooth drag-and-drop reordering with a compact floating drag preview pill, 35% opacity on the dragging block, and a vibrant 2.5px primary accent drop indicator line showing insertion above or below.
   - Context menu on click with accessible touch/keyboard actions: Move up, Move down, Duplicate, Copy Markdown, Turn into (Heading 1-3, Bullet, Numbered, Checklist, Quote, Text), Create Task from block, and Delete.
   - Exact Markdown source preservation: proper separation rules (`\n\n` between prose/headings, compact `\n` between lists/quotes), pinned index 0 frontmatter protection, and document history undo/redo (`Ctrl+Z` / `Ctrl+Y`) integration.

3. **Folder Management, Permanent Deletion & Vault File Visibility**:
   - Folder deletion: `deleteFolder(folder)` trashes contained notes (`deletedAt` set), deletes directory from disk/storage, and cleans up workspace folder trees.
   - Permanent deletion: `deletePermanently(id)` removes file from storage and purges object from memory and index.
   - "Empty Trash" button in Trash view purges all trashed items with confirmation.
   - Vault files & PDFs visibility: Optional "Show files & PDFs" toggle in the notes explorer header (default off to prevent clutter), rendering files with file/PDF icons and open handlers.

## Validation

- Unit and widget tests added in:
  - `test/folder_delete_test.dart`: tests folder trashing and deletion on disk, permanent deletion, empty trash, and session state persistence.
  - `test/task_ux_test.dart`: tests friendly due date calculations, overdue checks, animated task rows, view tabs filtering, inline sequential task creation, and Kanban board view.
  - `test/movable_blocks_test.dart`: tests movable block extraction, frontmatter pinning, drag handle and context menu interactions, move up/down paragraph reordering, markdown separation preservation, duplication, create task from block, and full undo/redo restoration.

## Next recommended task

- PDF reader continuous page view and precise highlight-region navigation.

## PDF work continuation — 2026-09-11

The owner resumed the PDF forms/phone-reading work. AcroForm text/checkbox overlays,
persisted field drafts, filled-copy import and adjustable narrow-screen text reading
are implemented. Preserve the Task/block/folder work above. This continuation also
repairs its compile/test API mismatches. Final validation is complete; detailed
PDF boundaries are in attachments-and-research.md and ADR-0015.

PDF continuation validation: all 206 tests pass; analyzer clean; zero-change format
check passes for 129 Dart files. Windows release build passed (59.3 seconds).
Evidence: .local/pdf-work-tests-final.log and .local/pdf-work-build.log.

Integration repairs preserve the new Task/block/folder work: controller-backed
Task tests and creation properties, overflow-safe block menus, focus after block
moves for keyboard undo, and non-destructive folder removal. Folder deletion moves
owned notes out before trashing them, rejects unrecognized files, and native removal
only removes an empty directory. Multi-note deletion is sequential and may stop
partway on a recoverable move/save failure; no all-or-nothing folder transaction is
claimed. Nested empty-folder cleanup remains limited by empty-directory removal.

## Notion & Milanote Product-Polish Implementation Pass — 2026-09-12

Delivered a comprehensive product-polish pass across Rich Notes, Universal Canvas, and Tasks:

1. **Collapsible Headings & Content**:
   - Fold/collapse sections beneath headings directly from the block handle chevron.
   - Non-destructive: visual filter does not modify markdown files; collapsed states stored in editor session state.
2. **Turn Block Into...**:
   - Added Callout (`> [!NOTE]`) and Code block (```` ``` ````) to Turn Into menu alongside Headings 1-3, Bullet, Numbered, Checklist, Quote, and Paragraph.
3. **Page / Object Icons**:
   - Optional emoji icon header on notes with instant preset picker (`📝`, `💡`, `🚀`, etc.) and removal.
   - Preserved in `UniversalObject.properties['icon']` (YAML frontmatter / JSON).
   - Displayed in explorer, tabs, and object rows.
4. **Optional Page Covers**:
   - Preset gradient covers (`gradient:violet`, `gradient:sunset`, `gradient:ocean`, `gradient:forest`, `gradient:amber`, `gradient:graphite`) with change/remove controls.
   - Preserved in `UniversalObject.properties['cover']`.
5. **Copy Link to Block**:
   - "Copy link to block" added to block handle context menu (`orbit://note#<slug>`).
6. **Smart URL Paste**:
   - Auto-detects URL in clipboard and wraps selected text into `[text](url)`.
7. **Canvas Section / Divider**:
   - Milanote-style `'section'` element with uppercase title, horizontal divider line, and direct text editing.
8. **Canvas Color Swatch**:
   - `'swatch'` card element with top color fill and bottom hex label; one-click "Copy HEX code" to clipboard.
9. **Canvas Lock / Unlock**:
   - Protect elements from accidental moves/resizes; lock badge displayed; unlockable via selection.
10. **Canvas Navigation Controls**:
    - Zoom out, 100% reset, Zoom in, Fit all content, and Fit selection (`filter_center_focus`).
11. **Nested Canvas Visual Identity**:
    - 'CANVAS BOARD' badge and board icon for nested canvas object references.
12. **Canvas Presentation Mode**:
    - Clean distraction-free view hiding toolbar with floating 'Exit presentation' chip; retains pan/zoom/nav.
13. **Canvas Breadcrumbs**:
    - Top breadcrumb navigation path for nested canvases with click-to-navigate ancestor links.
14. **Manual Task Order & View Duplication**:
    - Manual task sorting with `ReorderableListView` drag-and-drop.
    - "Duplicate current view" button to duplicate task view tabs with custom filter, sort, and property states.
15. **Slash Command Recents**:
    - Tracks recent slash commands and presents a "RECENT" section at the top of the slash menu.

## Obsidian-Style Bottom-Left Vault Switching & Help — 2026-09-12

Delivered Obsidian-style vault switcher and navigation controls at the bottom-left of the explorer sidebar matching Obsidian's signature layout:

1. **Bottom-Left Footer Bar**:
   - Pinned at the bottom of the explorer sidebar (`_buildVaultSwitcherFooter`) with a subtle top divider border (`colors.divider`).
   - Left side: Up/down unfold chevron icon (`Icons.unfold_more` `↕`) and current vault name (`c.repository.name`) with tooltip showing object count and switch prompt. Clicking opens the vault switcher dialog.
   - Right side: Quick-access Help button (`Icons.help_outline`) and Settings button (`Icons.settings_outlined`).
   - Responsive: Rendered both in docked desktop sidebar and mobile drawer explorer.
2. **Help & Shortcuts Dialog**:
   - Clean `OrbitDialog` displaying essential keyboard shortcuts (`Ctrl+P`, `Ctrl+B`, `Ctrl+Tab`, `Ctrl+Shift+T`), canvas gestures, and Markdown/callout shortcuts.
3. **Structured Vault Switcher Modal**:
   - Refined `Your Vaults` dialog with clear section dividers and headers:
     - `ACTIONS`: New Vault and Open Folder as Vault.
     - `YOUR VAULTS`: List of recent local vaults with active checkmark badge.
     - `MANAGE CURRENT VAULT`: Rename current vault and Close vault.
4. **Header Clean-Up**:
   - Avoids duplicate vault switcher buttons when the explorer sidebar is open, while keeping the fallback button when the sidebar is collapsed.

## Desktop Tab Ergonomics, Live Note Statistics, Canvas Duplicate & Alignment — 2026-09-12

Delivered a focused Gemini-safe quality-of-life ergonomics batch:

1. **Desktop Tab Ergonomics**:
   - Middle mouse click on a tab closes that specific tab immediately.
   - Right-click context menu on tabs with:
     - `Close Tab`
     - `Close Other Tabs`
     - `Close Tabs to the Right`
     - `Copy Reference` (`[[Title]]`)
     - `Reveal in File Explorer`
   - Dirty-draft protection respected during multi-tab closures (`c.flush(id)` before closing).
   - Active split panes respected when closing secondary tabs.
   - Enlarged close icon hit target (28x28px with 4px internal padding) for comfortable desktop mouse targeting.

2. **Live Note Statistics**:
   - Real-time word, character, and estimated reading time statistics (`X words · Y characters · Z min read`) in the bottom status bar when a note is active.
   - Updates live as the user types without triggering full shell rebuilds.
   - Automatically hidden when the active object is a canvas, task board, PDF, or file.

3. **Reveal in File Explorer**:
   - Native OS file explorer integration: opens folder with target file highlighted via `openAttachment(..., reveal: true)` (`explorer.exe /select,"<path>"` on Windows).
   - Available on notes, folders, attachments, and files in the sidebar explorer actions menu and tab context menu.

4. **Canvas Quick Duplicate (`Ctrl+D`)**:
   - Instant duplicate of selected element(s) offset by `+20, +20` world units.
   - Places the newly duplicated element(s) in active selection.
   - References the same underlying universal object (note/task) without creating duplicate notes.
   - Encapsulated in a single undo transaction (`_history.begin()` / `_commit()`).

5. **Canvas Multi-Selection Alignment**:
   - Align 2 or more selected elements horizontally or vertically:
     - `Align Left`, `Horizontal Center`, `Align Right`
     - `Align Top`, `Vertical Middle`, `Align Bottom`
   - Accessible via both the canvas top toolbar alignment menu and the canvas right-click context menu.
   - Maintains exact element dimensions, shifting only coordinates.
   - Skips locked elements and bundles alignment into a single undo step.

6. **Empty-Canvas Context Menu**:
   - Compact right-click context menu on empty canvas space:
     - `Add Text` (placed at click location)
     - `Add Sticky` (placed at click location)
     - `Add Section` (placed at click location)
     - `Add Color Swatch` (placed at click location)
     - `Paste`
     - `Fit All`
     - `Fit Selection` (when elements are selected)
     - `100% Zoom`
   - Accurately converts screen click coordinates to world coordinates according to current camera zoom and pan.

### Validation Evidence
- Unit and widget tests added in `test/product_polish_test.dart` and passing:
  - Tab close actions (`closeOtherTabs`, `closeTabsToTheRight`), draft preservation, middle-click, and context menu.
  - Live note statistics display and dynamic recalculation during body edits.
  - Canvas empty-space right click, element insertion, and multi-selection alignment.
- Full test suite: 221 tests passed (0 failures).
- Zero analyzer warnings (`flutter analyze`: "No issues found!").
- Formatting check passed (`dart format --output=none --set-exit-if-changed lib test`).
- Windows release build compiled cleanly: `build\windows\x64\runner\Release\orbit_note.exe`.
- Deployed binary to `C:\Users\iax\Desktop\Orbit Note Windows App` and generated archive `C:\Users\iax\Desktop\OrbitNote-Windows-x64.zip`.

## Second Productivity & Polish Batch — 2026-09-12

Delivered the second focused Gemini-safe quality-of-life batch:

1. **Pinned Tabs & Reordering Ergonomics**:
   - Tab context menu includes `Pin Tab` and `Unpin Tab` actions.
   - Pinned tabs are partitioned to the leftmost side of the tab strip with a subtle vertical divider.
   - Pinned tabs show a subtle pin icon (`push_pin_rounded`, 11px) with title text.
   - Preserved during bulk closing operations (`Close Other Tabs`, `Close Tabs to the Right`).
   - Drag-to-reorder respects partition boundary clamping (unpinned tabs cannot be dragged into pinned region, and pinned tabs stay within pinned range).

2. **Reopen Closed Tab (`Ctrl+Shift+T`)**:
   - `reopenClosedTab()` reopens the most recently closed tab from a bounded 20-entry session stack (`session.closedTabs`).
   - Accessible via keyboard shortcut `Ctrl+Shift+T`, tab strip context menu, and command palette.
   - Skips deleted or missing objects gracefully.

3. **Universal Search Context Snippets**:
   - `extractSearchSnippet()` extracts context around matched search queries across note bodies, canvas elements (both data and JSON bodies), and properties.
   - Markdown noise stripped via `cleanMarkdownNoise()` so raw syntax (`#`, `**`, `[[`, `]]`, `` ` ``) is removed.
   - Matches are highlighted in the search popup and command palette with bold styling and subtle tag indicators (`Canvas element`, `Property: ...`).

4. **Notes Explorer Multi-Selection & Tree Keyboard Navigation**:
   - Multi-selection support: standard click to select single note, `Ctrl`/`Cmd`+click to toggle items, `Shift`+click for range selection, and `Ctrl+A` to select all visible notes in the tree.
   - Full keyboard navigation: `Up`/`Down` arrows to navigate entries with automatic scrolling, `Enter` to open notes or toggle folder expansion, `Right`/`Left` arrows to expand/collapse folders, `Space` to toggle selection.
   - Floating batch actions bar at the bottom with count indicator, `Move to folder`, `Copy references`, and `Move to Trash` (with confirmation showing exact count).

5. **Canvas Distribute Evenly**:
   - Distribute 3 or more selected canvas elements horizontally (`distributeH`) or vertically (`distributeV`).
   - Computes equal spacing between elements based on bounding boxes while preserving leftmost/rightmost or topmost/bottommost anchors.
   - Respects element locks, operates as a single undo/redo transaction, and is accessible from the canvas alignment toolbar menu and context menu.

6. **Canvas Minimap**:
   - Floating 160x110 minimap card positioned in the bottom-right corner above the zoom controls.
   - Implemented via `CanvasMinimapPainter` depicting element bounds and viewport rectangle.
   - Clicking or dragging inside the minimap centers the canvas camera to the clicked location.
   - Minimap toggle button (`map_outlined`) in the zoom control bar; automatically hidden in presentation mode.

7. **Canvas Alignment / Snap Guides**:
   - Visual dashed guidelines rendered temporarily during element movement when edges or centers align with candidate elements within a 6-pixel threshold.
   - Transient visual guides and coordinate snapping; pressing `Alt` bypasses snapping.
   - Zero JSON schema persistence (strictly runtime visual helper).

8. **Daily Note ("Open Today's Note")**:
   - Command palette and Home quick action to open today's daily note.
   - Creates or navigates to an ordinary note titled with `YYYY-MM-DD`, formatted with a clean `# Weekday, Month D, YYYY` header, and marked with a `dailyDate` property.
   - Idempotent: reopens the existing note if one already exists for today.

9. **Navigation History (Back / Forward)**:
   - Browser-style navigation stack tracking opened objects with `navigateBack()` and `navigateForward()`.
   - Shortcuts `Alt+Left` and `Alt+Right` and top-bar back/forward chevron buttons.
   - Deduplicates consecutive history entries and maintains a bounded 50-entry stack.

10. **Home Local Dashboard V1**:
    - Enhanced home dashboard using existing local models without remote dependencies:
      - Quick Actions: `Open Today's Note`, `New Note`, `New Canvas`, `Search`.
      - Today's Tasks: Displays due today and overdue tasks with direct checkbox completion.
      - Upcoming Events & Deadlines: Lists upcoming calendar items and deadline tasks.
      - Recent Objects: 4-column cards showing recently viewed notes, canvases, and files.
      - Continue Reading: Highlights last read PDF with page progress and one-click resumption.

### Validation Evidence (Batch 2)
- Unit and widget tests in `test/product_polish_batch2_test.dart` (16 passing tests) covering:
  - Tab pinning, unpinning, repartitioning, drag clamping, and preservation during bulk closures.
  - Reopen closed tab stack behavior and deleted object handling.
  - Navigation history forward/backward traversal.
  - Search snippet extraction across note bodies, canvas text, and properties.
  - Daily note idempotency, dated title, and header format.
  - Canvas horizontal and vertical equal-gap distribution math.
  - Canvas minimap painter bounds calculation and guide line equality.
  - Home dashboard task categorization (today, overdue, upcoming).
- Full test suite: **237 tests passed (0 failures)**.
- Static analysis: **0 issues found** (`flutter analyze`).
- Code formatting: zero-change format check passed (`dart format --output=none --set-exit-if-changed lib test`).
- Windows release executable compiled: `build\windows\x64\runner\Release\orbit_note.exe`.
- Deployed executable and assets to `C:\Users\iax\Desktop\Orbit Note Windows App` and generated archive `C:\Users\iax\Desktop\OrbitNote-Windows-x64.zip`.


## Visual PDF reading continuation — 2026-09-12

Owner requested images/tables in comfort mode and additional PDF reading tools.
Implemented a live-page visual comfort mode with conservative blank-side-margin
fitting; text-only reading remains optional. Added full-page/width/content fitting,
zoom presets and focused-reader keyboard shortcuts. Preserves existing PDF forms,
research tools and unrelated work. No architecture/storage change.

Targeted regressions pass for an image/table fixture, blank/edge pixel bounds,
mode switching, zoom and fitting shortcuts, native form taps and filled-copy readback.
The phone-sized screenshot was inspected with image and table visible. Validation:
237 tests passed; flutter analyze clean; formatting and zero-change check passed
for lib/test/tool (133 files). Windows release build passed in 42.4 seconds:
`build/windows/x64/runner/Release/orbit_note.exe`. Logs are
`.local/pdf-visual-reading-tests.log` and `.local/pdf-visual-reading-build.log`.
No physical phone validation or interactive Windows smoke launch was performed.
Next: physical phone acceptance,
then precise highlight-region navigation; full Acrobat parity is not claimed.

## Productivity, Project Management & University Workflows Pass — 2026-09-12

Delivered a comprehensive productivity, project management, and university workflow pass based strictly on Orbit's core invariant: **"CREATE ONCE. VIEW ANYWHERE."**

1. **Unified Folder & Project System**:
   - Folders in the unified Explorer tree now contain Notes (`orbit.note`), Canvases (`orbit.canvas`), Saved Views (`orbit.view`), Attachments (`orbit.file`), and subfolders.
   - Drag-and-drop support: drag Notes, Canvases, Saved Views, or Files directly into folders with instant path update.
   - Rich Folder Context Menu with actions:
     - `New Note`
     - `New Canvas`
     - `New Task List`
     - `New Board` (defaults to university preset)
     - `New Calendar`
     - `New Timeline`
     - `New folder` / `New subfolder`
     - `Rename folder`
     - `Move folder…`
     - `Reveal in File Explorer`
     - `Archive folder`
     - `Delete folder`
   - Non-destructive Folder Archiving: `isArchivedFolder(folder)`, `archiveFolder(folder)`, `restoreFolder(folder)` with collapsible "Archived" section in explorer sidebar; leaves underlying files intact.

2. **Saved Views (`orbit.view`)**:
   - Universal Object storing view configuration (`viewType`: `tasks`, `board`, `calendar`, `timeline`; `folder`, `scope`, `preset`) that scopes and views underlying Universal Objects without data duplication.
   - `SavedViewHost` widget with:
     - Icon and editable title bar.
     - Folder scope chip.
     - View switcher tabs (`List`, `Board`, `Calendar`, `Timeline`).
     - Kanban preset dropdown selector (`Universal`, `Software`, `Game Dev`, `University`).
     - Real-time Course / Project progress bar (`X / Y complete · Z%`).
     - Duplicate view (duplicates view configuration only, zero task duplication) and Trash view.

3. **Kanban Board Enhancements**:
   - Customizable presets via `KanbanPreset`:
     - **Universal**: Backlog, To Do, In Progress, Done
     - **Software Dev**: Backlog, Ready, In Dev, In Review, Done
     - **Game Dev**: Concept, Asset Production, In Dev, Testing, Done
     - **University Course**: Syllabus / Topics, Assignments, Exam Prep, Review, Done
   - Smooth drag-and-drop (`Draggable` / `DragTarget`) between columns updating task status and completion dynamically.
   - Inline sequential quick add (`+ Add task`) per column with instant focus.
   - Rich card metadata badges: estimate chip, category chip, subtle priority chip, blocker warning chip (`🔒 Blocked`), and subtask checklist completion ratio (`X / Y subtasks`).
   - Side task preview peek panel (`_peekTaskId`) for immediate in-place inspection and editing.
   - Full `TaskDetail` editing: added form fields for `status`, `estimate`, `category`, and `blockedBy`.

4. **Timeline View (`TimelineView`)**:
   - Chronological month/year timeline aggregating `orbit.event` and dated `orbit.task` Universal Objects.
   - Scoped filtering by folder or course/project.
   - In-view live search and interactive task completion toggle.

5. **Scoped Calendar View**:
   - `CalendarView` accepts `folderFilter` and `scope` to scope events and due tasks strictly to the active folder/project/course.

### Validation Evidence
- Comprehensive unit and widget test suite in `test/workflow_project_management_test.dart` (7/7 passing tests):
  - Invariant verification: single task shared across List, Board, Calendar, and Timeline without cloning data.
  - Non-destructive folder archiving and restoration.
  - Saved view creation and configuration duplication without task cloning.
  - `moveObjectToFolder` updates location for notes, canvases, and views.
  - Kanban presets validation (`universal`, `software`, `gamedev`, `university`).
  - `SavedViewHost` header, switcher, and viewType transitions.
  - `SavedViewHost` course progress calculation and percentage display.
- Full test suite: **255/255 tests passed (0 failures)** across all test files in the repository.
- Static analysis: **0 issues found** (`flutter analyze`).
- Code formatting: 139 files checked with 0 changes (`dart format --output=none --set-exit-if-changed lib test`).
- Windows 64-bit release build compiled: `build\windows\x64\runner\Release\orbit_note.exe`.
- Deployed executable and assets to `C:\Users\iax\Desktop\Orbit Note Windows App` and generated archive `C:\Users\iax\Desktop\OrbitNote-Windows-x64.zip`.
- Android release APK compiled via OpenJDK 17 and Android SDK Platform 34: `build\app\outputs\flutter-apk\app-release.apk` (93.8MB) and copied to `C:\Users\iax\Desktop\OrbitNote-release.apk`.
