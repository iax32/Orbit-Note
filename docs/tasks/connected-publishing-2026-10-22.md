# Connected publishing snapshots — 2026-10-22

Owner request: one more big update, then shut down the computer. Scope: resolved
Canvas/live-object previews in PDF/HTML/Word, PORT-05/06/09. Headless synthetic
checks only; preserve all prior uncommitted work and owning knowledge.

## Delivered behavior

- Snapshot objects, paths and query clock at publishing open. Resolve live-object
  blocks outside literal code, with same-workspace/identity/schema guards. Static
  task/project/course metadata, context names and saved collection memberships
  retain source identity/revision. Note/LaTeX cards stay metadata-only; full rich
  content remains the existing linked-section workflow. Plain descriptions strip
  private frontmatter/comments; arbitrary object properties are not dumped.
- Safe local image objects join the existing resource loader. Encoded filenames
  survive. Unsupported paths retain labelled references rather than reading
  arbitrary files. No account or external resource is accessed implicitly.
- Reuse CanvasScene/ResolvedCanvasDiagram and the native Orbit painter: full-board
  and exact diagram capture; UML/ink/backgrounds/cards/images; searchable placement
  inventory and UML attributes/operations alongside each image. Missing selected
  items warn; no precision failure broadens capture to unrelated board content.
- Bounded local Canvas image decoding, static first frames and preserved fallback
  cards for unavailable, nested or non-image media. Reuse cached generated images
  across styles. Close decoded images/codecs/buffers and painter display lists.
- Fix the visually reproduced short-edge UML multiplicity overlap in shared label
  geometry; Canvas, image exports, SVG and hit testing share the corrected bounds.
- No owning format/schema, mutation, migration, server or package addition.

## Validation

13 new regressions; final focused **65 passed**. Format/strict check across **724
files**, analysis clean. Native PDFium text/image checks, PDF/HTML/OOXML resources,
wrong-workspace/deleted/ambiguous IDs, query/path boundaries, literal code, unknown
scene/precision failures, stale style regeneration, caps, image pixels, safe
filenames and separate UML labels covered. Poppler/native PNG visual review:
blueprint/UML with searchable inventory and task/collection report, one page each.

Full suite: **2,871 passed, 2 existing skips**, 4 min 36 sec. No new skips.
785 source/test/asset/build inputs frozen, unchanged after tests and both builds.
Configured Windows app and standalone host built successfully (69.2 sec); standard
JS web build passed (64.4 sec). Existing Google SDK Wasm dry-run/Cupertino-font
warnings remain; no Wasm acceptance claimed. Seven runtime/host files and 33
font hashes verified, with fresh AOT/host outputs. No signing/version changes.
Logs: .local/connected-publishing-*.log. Input/runtime evidence:
.local/connected-publishing-{source-snapshot,build-verification}.json.

Run build/windows/x64/runner/Release/orbit_note.exe with its sibling runtime files.
No app/server launch, GitHub upload, account action or Android rebuild.
Synthetic PDF/PNG evidence: tmp/pdfs/connected-*. No personal data or desktop
control; no app/host launch or GitHub publication.

## Limits and next task

Static presentation snapshots, not live controls or recursive board rendering.
Overview max 1600 px; 5,000 placements; first 24 local board images, 100 object
blocks, 200 searchable entries/collection members. Explicit truncation/failure
warnings; original sources remain intact. Objects/paths/query time are captured
at opening; attachment bytes load through the guarded repository boundary and
are reused. Reopen to refresh. No Android rebuild requested.

Next suggested task: tiled multi-page Canvas printing; stop before implementing.

## Shutdown request

User explicitly requested normal shutdown after this update. Run it only after
final validation/builds and saving evidence. Do not use /f or a nonzero shutdown
/t value (Windows can imply forced app closure for a timed shutdown). A hidden
short-delay helper may invoke shutdown /s /t 0 after the final response. Unsaved
applications may block graceful shutdown; never force them closed automatically.
