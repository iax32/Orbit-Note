# Custom Read search coverage — 2026-10-03

Owner requests more useful app improvements without desktop automation. Scope:
callout title/body highlighting and verified Read navigation, aligned text
coverage, selectable/wrapping callout titles. Markdown editing contract and prior
Read-search evidence consulted. No packages, migrations or stored-source changes.

## Changes

- Read callout titles are selectable and wrap in the available header width,
  retaining their icon, generated label, theme color and typography. This fixes
  long titles overflowing the header and makes copying title text possible.
- A transient authored-text marker identifies title characters inside the display
  label. Search excludes generated type labels while retaining identical words
  that the author actually wrote in the title. Unknown type source stays intact.
  Verify the actual displayed substring before accepting its match coordinates.
- Group rendered callout body paragraphs under their owning source segment.
  Multiple plain paragraphs can now highlight and navigate in source order beside
  title/prose matches. Normalize whitespace for ownership checks, retaining the
  existing source-preserving search behavior and clipping/geometry rules.
- Centered/right-aligned prose/headings use their existing selectable renderer;
  new regression tests confirm formatted matches map without altering alignment
  comments or stored Markdown.
- Keep conservative fallback for source/rendered markup differences, missing text
  or ambiguous mapping. Existing counts, Unicode boundaries, Find focus and
  grouped verification caches remain in use.

## Validation

- New `test/custom_read_search_test.dart`: seven widget regressions cover authored
  title vs generated labels, multi-paragraph/source order, unknown types/CRLF,
  header-only/long titles, center/right headings and formatted-body fallback.
- The previous title-fallback test now exercises genuinely unmapped formatted
  body text; title navigation is intentionally supported by this change.
- Initial test command named nonexistent `callout_test.dart`; rerun uses the actual
  `callout_block_test.dart`. No behavior failures in that intermediate run.
- Focused Read/callout/highlight/table checks: **56 passed** (13s),
  `.local/custom-read-verified-focused.log`.
- Analyzer: clean (15.6s), `.local/custom-read-final-analyze.log`.
  `dart format lib test` and strict no-change formatting: clean (359 files).
- Full suite: **1,166 passed** (2m11s), `.local/custom-read-full-tests.log`.
- Normal Windows release rebuilt successfully (83.1s), original local build
  configuration retained, `.local/custom-read-windows-build.log`.
- Scoped `git diff --check`: clean. Task completed 2026-10-03.

## Follow-up validation — Read-callout link and attachment activation, 2026-10-07

Nested callout Markdown now reuses the note-level link router and image builder.
External, internal, missing and relative attachment links therefore share the
same Read behavior as ordinary prose. Relative attachment images are previewed
with the note image builder and wrapped in an accessible tap target that opens
the original attachment without changing authored Markdown.

- Added external-link, relative-attachment-link and attachment-image regressions.
- Focused Read/callout/editor suite: **65 passed**.
- Full Flutter suite: **1,353 passed** (`.local/callout-links-final-full.log`).
- Strict formatting, `flutter analyze`, and `git diff --check`: clean.
- Task completed 2026-10-07.

## Follow-up validation — Read PDF, Canvas and image recovery parity, 2026-10-07

Read PDF quote links retain precise page fragments and Canvas wiki-links retain
stable object IDs when opened. Local image previews now retry after a failed
vault read and show an explicit failure state while preserving the source path.

- Added PDF-page, Canvas-object and retry-after-failure regressions.
- Focused Read/media suite: **20 passed**.
- Full Flutter suite: **1,362 passed** (`.local/read-media-parity-pdf-canvas-final-full.log`).
- Strict formatting, `flutter analyze`, and `git diff --check`: clean.
- Task completed 2026-10-07.

## Follow-up validation — Read media activation parity, 2026-10-07

Footnote and math-adjacent images now use the shared local attachment preview.
Read-mode fenced `orbit-view` and `orbit-snapshot` blocks render their existing
interactive view/snapshot widgets instead of inert code, without rewriting the
authored fence.

- Added footnote-image, math-adjacent-image and dynamic-view regressions.
- Focused Read/callout/editor/footnote suite: **81 passed**.
- Full Flutter suite: **1,359 passed** (`.local/read-media-parity-final-full.log`).
- Strict formatting, `flutter analyze`, and `git diff --check`: clean.
- Task completed 2026-10-07.

## Follow-up validation — Read attachment activation parity, 2026-10-07

Aligned blocks, tables and block quotes now use the shared
`ReadAttachmentPreview`. Local relative images retain the supplied image
renderer and expose an accessible tap target that opens the original through the
note-level attachment handler. Remote and data images stay display-only.

- Added aligned, table and block-quote attachment-image regressions.
- Focused Read/callout/editor suite: **67 passed**.
- Full Flutter suite: **1,356 passed** (`.local/read-attachment-parity-final-full.log`).
- Strict formatting, `flutter analyze`, and `git diff --check`: clean.
- Task completed 2026-10-07.

## Limits / next task

No desktop control, native review window or native IME/clipboard test. Callout
body search retains literal editing-field Markdown semantics. Richly formatted
body text or a query spanning separately rendered paragraphs can still mismatch
the Read renderer and use approximate fallback. No global source serialization or
inline grammar changes are introduced.

Suggested next task: Read-mode media parity for attachment actions in PDF quote
cards, Canvas embeds, and inline math-adjacent media.

## Follow-up validation — Read-mode media actions for PDF quotes, Canvas embeds, and math-adjacent media, 2026-10-07

PDF review cards now copy quote text and reopen the source page. Canvas citation
and image previews expose copy-citation and open-source/original-attachment
actions. Math-adjacent images retain shared metadata, accessibility, details,
and recovery behavior.

- Added PDF review-card and Canvas quote/source action regressions.
- Focused PDF/Canvas action suite: **24 passed**.
- Read attachment recovery suite: **15 passed**.
- Full Flutter suite: **1,378 passed** (`.local/read-media-actions-final-full.log`).
- Strict formatting, `flutter analyze`, and `git diff --check`: clean.
- Task completed 2026-10-07.

Suggested next task: Read-mode media parity for PDF quote source-version
warnings, Canvas stale-source badges, and math-adjacent replacement indicators.

## Follow-up validation — Read-mode media source status, 2026-10-07

PDF review rows now warn when their stored checksum differs from the open PDF;
Canvas citation cards expose a source-changed badge while retaining source
verification; and replacement attachment bytes announce their new revision in
Read mode, including math-adjacent images.

- Added stale PDF row, stale Canvas citation, and replacement-status regressions.
- Focused PDF/Canvas action suite: **25 passed**.
- Read attachment suite: **15 passed**.
- Full Flutter suite: **1,379 passed** (`.local/read-media-source-status-final-full.log`).
- Strict formatting, `flutter analyze`, and `git diff --check`: clean.
- Task completed 2026-10-07.

Suggested next task: Read-mode media parity for attachment relinking, source
history, and user-visible recovery choices.

## Follow-up validation — Attachment relinking, source history, and recovery choices, 2026-10-07

Read-mode attachment recovery now offers checksum-checked restoration at the
original path, stable-ID relinking to a new source, retained-source browsing,
and version restoration. Existing references remain authored and failed or stale
commands preserve the active source.

- Added repository regressions for checksum enforcement, identity preservation,
  source history, and retained-version restoration.
- Focused storage/attachment recovery suite: **28 passed**.
- Full Flutter suite: **1,381 passed** (`.local/read-media-recovery-final-full.log`).
- Strict formatting, `flutter analyze`, and `git diff --check`: clean.
- Task completed 2026-10-07.

Suggested next task: attachment recovery verification UX for large files and
retained-source cleanup.

## Follow-up validation — Recovery verification and retained-source cleanup, 2026-10-07

Recovery now previews selected file size and SHA-256. Restore-original is
disabled when the selected bytes do not match recorded metadata, while relink
remains available as an explicit new source. The recovery dialog can forget a
retained source after confirmation; active and cross-object references are
protected, and only the verified immutable bytes are deleted.

- Added repository cleanup and checksum-preview regressions.
- Focused storage/attachment recovery suite: **30 passed**.
- Full Flutter suite: **1,383 passed**.
- Strict formatting, `flutter analyze`, and `git diff --check`: clean.
- Task completed 2026-10-07.

Suggested next task: streamed hashing and progress reporting for large
attachment recovery.

## Follow-up validation — Streamed attachment recovery hashing and progress, 2026-10-08

The recovery chooser verifies XFiles incrementally, displays byte progress, then
reopens the source stream for restore or relink. Native staging writes to a
temporary Vault file while hashing, so large recovery does not duplicate the
entire source in memory. Browser storage keeps the bounded compatibility path.

- Added streamed restore/relink repository regressions with progress callbacks.
- Focused storage/read/native staging suite: **37 passed**.
- Full Flutter suite: **1,385 passed**.
- Strict formatting, `flutter analyze`, and `git diff --check`: clean.
- Task completed 2026-10-08.

Suggested next task: resumable recovery after an interrupted staged transfer.

## Follow-up validation — Resumable attachment recovery after interrupted staging, 2026-10-08

Native attachment stages now retain a manifest and partial bytes when a source
stream stops. Recovery inventory shows the saved offset, resume verifies the
same source's complete checksum before publication, and discard removes only
the staged device-local files. The repository and native staging regressions
cover interruption, reopen, resume, and discard; no authored reference is
changed until commit succeeds.

- Added native interruption/reopen/resume/discard coverage and a repository resume regression.
- Focused storage/read/native staging suite: **40 tests after these additions**.
- Full Flutter suite: **1,388 passed**.
- Strict formatting, `flutter analyze`, and `git diff --check`: clean.
- Task completed 2026-10-08.

Suggested next task: recovery inventory cleanup for abandoned stages older than the retention window.

## Follow-up validation — Recovery-stage retention cleanup, 2026-10-08

Native Vault startup now prunes only well-formed attachment stages whose
durable progress timestamp is older than 30 days. It removes the corresponding
partial bytes and temporary manifest together, while preserving recent stages,
malformed recovery data, and unsupported newer workspace formats.

- Added retention regression for startup cleanup and partial-byte removal.
- Focused native staging/storage suite: **26 passed**.
- Full Flutter suite: **1,389 passed**.
- Strict formatting, `flutter analyze`, and `git diff --check`: clean.
- Task completed 2026-10-08.

Suggested next task: recovery verification UX for large files and retained-source cleanup.

## Follow-up validation — Recovery verification UX for large files, 2026-10-08

Retained-source restore and cleanup now stream native bytes through SHA-256
verification and expose progress in the recovery dialog. Cleanup verifies the
recorded checksum before changing metadata or deleting bytes; externally changed
or missing sources preserve their history for another recovery attempt.

- Added streamed verification progress and changed-byte protection regressions.
- Focused native staging/storage/read-attachment suite: **42 passed**.
- Full Flutter suite: **1,390 passed**.
- `flutter analyze`: clean; strict formatting and `git diff --check`: clean.
- Task completed 2026-10-08.

Suggested next task: attachment recovery source history pagination and large-file cancellation.

## Follow-up validation — Attachment recovery history pagination and cancellation, 2026-10-08

The recovery dialog now pages retained sources eight at a time and keeps a
cancel action available during verification, staging, relinking, restoring, or
forgetting. Stream callbacks check cancellation between chunks. A cancelled
native transfer leaves its partial manifest and bytes listed for resume; a
cancelled retained-source verification does not mutate history or delete the
immutable source.

- Added repository coverage proving cancellation preserves a resumable native stage.
- Focused storage/read/native staging suite: **43 passed**.
- Full Flutter suite: **1,391 passed**.
- `flutter analyze`, strict formatting, and `git diff --check`: clean.
- Task completed 2026-10-08.

Suggested next task: recovery dialog accessibility audit for paginated history and cancellation feedback.

## Follow-up validation — Recovery dialog accessibility and keyboard feedback, 2026-10-08

The recovery dialog now exposes semantic route and source groups, announces
history-page and progress changes, supports deterministic keyboard traversal,
and handles Escape as cancel-or-close. Ctrl+Page Up/Down pages retained source
history without requiring a pointer. Cancellation feedback is announced and
repeat requests are disabled while the transfer winds down.

- Added widget coverage for semantic pagination and Escape cancellation.
- Focused recovery suite: **45 passed**.
- Full Flutter suite: **1,393 passed**.
- `flutter analyze`, strict formatting, and `git diff --check`: clean.
- Task completed 2026-10-08.

Suggested next task: recovery dialog high-contrast and reduced-motion visual audit.

## Follow-up validation — Recovery dialog high-contrast and reduced-motion audit, 2026-10-08

High-contrast mode now adds stronger dialog and source-card boundaries, larger
action targets, and a thicker color-scheme-aware progress bar. Reduced-motion
mode disables progress ticker animation without suppressing progress values or
live status announcements.

- Added visual regression coverage for high contrast and reduced motion.
- Focused recovery suite: **46 passed**.
- Full Flutter suite: **1,394 passed**.
- `flutter analyze`, strict formatting, and `git diff --check`: clean.
- Task completed 2026-10-08.

Suggested next task: recovery dialog theme-surface contrast audit across light, dark, and custom palettes.

## Follow-up validation — Recovery dialog theme-surface contrast audit, 2026-10-08

The recovery dialog now protects readable text, outlines, and progress accents
when a custom palette supplies low-contrast tokens. The dialog chooses a
deterministic black/white fallback per surface while preserving authored
surfaces, and keeps the existing high-contrast and reduced-motion treatments.

- Added widget coverage for light, dark, and deliberately low-contrast custom palettes.
- Focused recovery suite: **47 passed**.
- Full Flutter suite: **1,395 passed**.
- `flutter analyze`, strict formatting, and `git diff --check`: clean (line-ending normalization warnings only).
- Task completed: 2026-10-08.

Suggested next task: recovery dialog font-scale and text-overflow audit across compact and large accessibility settings.

## Follow-up validation — Recovery dialog font scaling and overflow, 2026-10-08

Regression tests reproduced overflowing history pagination and a fixed title
that consumed the available height at enlarged text sizes. Recovery now scrolls
the title and content together with the footer actions outside the scroll view.
The page label wraps between its navigation controls. The cleanup confirmation
also scrolls its title/content and gives stacked actions space. Both dialogs
use narrower outer insets without capping native text scaling or truncating
filenames, paths, or status text.

- Portrait 320×640 and landscape 568×320 at 250% text: long staged details,
  paginated history, cancellation, and cleanup confirmation remain operable.
- Changing to 320% text with a 240-pixel keyboard inset during verification
  preserves progress/operation state and keeps cancellation above the keyboard.
- Recovery dialog suite: **7 passed**; full Flutter suite: **1,398 passed**.
- Full-suite evidence: `.local/recovery-font-scale-full.log`.
- Analysis, strict formatting (400 files), and `git diff --check`: passed;
  existing line-ending normalization warnings only.
- Task completed 2026-10-08; no desktop-control testing used.

Suggested next task: large-text accessibility audit of document history,
backup/restore, and settings dialogs.

## Follow-up validation — Read-mode attachment cache invalidation, 2026-10-07

Native attachment watcher events now travel through a separate repository
stream, so replacing an attachment refreshes visible Read and Canvas previews
without triggering object-index reconciliation. Read image loads are revision
gated, and Canvas decoded/failed entries use generation fencing to discard stale
in-flight decodes before reloading.

- Added revision-gated Read reload and Canvas invalidation regressions.
- Focused media/cache suite: **22 passed**.
- Full Flutter suite: **1,365 passed** (`.local/read-media-cache-final-full.log`).
- Strict formatting, `flutter analyze`, and `git diff --check`: clean.
- Task completed 2026-10-07.

## Follow-up validation — Read-mode missing attachment recovery, 2026-10-07

Read attachment previews now distinguish missing files, failed Vault reads, and
decoder failures. Each state preserves the source reference and offers Retry;
replacement revisions expose a refresh state while new bytes load.

- Added missing, failed-read, decode-failure, replacement-refresh, metadata,
  accessibility, and open-original regressions.
- Focused media/cache suite: **35 passed**.
- Full Flutter suite: **1,378 passed** (`.local/read-media-metadata-final-full.log`).
- Strict formatting, `flutter analyze`, and `git diff --check`: clean.
- Task completed 2026-10-07.
