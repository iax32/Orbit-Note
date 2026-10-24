# Motion studio and connected feedback — 2026-10-23

## Request and implementation boundary

Owner supplied “The ultimate animation inspiration guide for modern note editors”.
It contains 70 concepts, including mutually alternative text/page effects and
animations that presuppose AI/handwriting services. This implements a substantial
local presentation/interaction update on the existing Flutter motion and spatial
engine. It does **not** assert that every catalog concept is a complete workflow.
No model/network/account dependencies are installed, no writing is uploaded, and
no AI processing or generation is simulated as real work. No architecture change.

## Use

- Settings → search **Motion** → **Open motion studio**. Fluid, Paper & Ink and
  Experimental personalities, 0.5–2× timing, five category switches, optional
  focus typing/PDF spotlight/page position, and four page-transition styles.
  Normal/Reduced/Off and the OS cap remain authoritative. Reset retains unknown
  future options. The setting stays within the existing 43-entry settings index.
- Note **Copy as…** menu → **Text presentation…** replays the actual authored text
  read-only. Characters are Unicode grapheme clusters, with instant, character,
  natural typewriter, word, blur, ink and weight-morph alternatives, plus scramble.
  Full text remains accessible; pointer input settles playback before selecting.
  Presentation is bounded to 4,000 characters and explicitly labels truncation.
- Canvas **Canvas motion & presentation** → **Replay board or selection…** uses
  a frozen scene and the **same** spatial painter. Images reuse available decoded
  previews; uncached/offscreen images can show the existing placeholder. Replay/Pause/Resume, speed,
  timeline scrubbing and complete-board restoration affect presentation only.
  Stroke samples/pressure/unknown fields are retained; ordinary objects reveal
  across their bounds. Replay order is stored placement order, not invented
  historical timestamps. Preview caps at 1,000 visible placements, with a notice;
  select a smaller set to present another region. No export or history mutation.
- Same Canvas menu → **Temporary laser pointer**, then draw to point. Trails fade
  once, are capped at 160 samples, consume no document commands, and are not ink,
  synced trail data or exported content. Normal collaborator cursor presence
  continues. Escape/menu exits. Reduced/Off uses a direct dot
  that clears on release. Switching boards exits the ephemeral mode.
- PDF explicit page jumps glide using the existing controller. Page effects keep
  one mounted viewer and respect Reduced/Off. The menu adds a magnifying lens
  sampling rendered content (no second PDF renderer). Annotation navigation gets
  finite feedback; optional spotlight reduces other markup opacity. The optional
  PDF page-position line is **off by default**. No Markdown scroll-progress bar.
- Graph **Reveal graph paths** draws actual relationships in a finite 900ms reveal;
  direct interaction settles it, with no moving background constellation loop.
- Document history has an accessible revision slider. Moving it previews stored
  versions; it never restores a snapshot or writes until the existing explicit
  Restore command is chosen. Existing review/replace previews use finite feedback.

## Guide coverage

| Guide group | Real workflows and existing behavior | Explicit previews / remaining boundaries |
|---|---|---|
| Text (14) | Authored text replay alternatives; selection wave; toolbar state feedback; optional inactive-paragraph dimming; actual grammar replacements | Caret remains native; no delayed user typing, animated per-glyph reflow, or predictive ghost-completion backend. Weight/blur/ink/scramble are read-only presentation alternatives. |
| Drawing (14) | Existing live pressure ink/smoothing/highlighter/shape recognition, magnetic connectors/eraser/lasso; authored board/stroke replay; temporary laser | Gallery illustrates settling/shape/brush/sketch-to-text ideas. No elastic geometric interpolation or handwriting recognizer is fabricated. |
| PDF (12) | Page glide/fade/slide/paper/tilt, thumbnails navigate, search controller, finite annotation feedback, lens, optional progress, current extraction/splits | “Curl” is a small perspective tilt, not a physically simulated sheet curl. No screenshot-based thumbnail hero transition or paper-stack page renderer. |
| Workspace (14) | Existing tab/content/sidebar/disclosure/control/menu transitions; profile-aware arrivals, hover toolbar, formatting feedback and slash-menu easing | Spring drag/tilt, minimization and undo return remain concept previews where no matching animation exists. Layout/undo/commands apply immediately. |
| Smart (10) | Real review proposal/status feedback, before/after replacements, accepted grammar changes; existing OCR/source/citation operations | Streaming AI, generation shimmer, AI diagram/mind-map assembly, recognized-handwriting morphs are explicitly labeled concept previews, not new backend capabilities. |
| Signature (6) | Actual graph-edge reveal, Canvas presentation, revision scrubbing, optional reading spotlight; existing connected note/Canvas transfer | Constellation/liquid effects and document-to-Canvas geometric morph are inspiration previews. Revision scrubbing is not historical keystroke playback. |

## Safety and performance

Input, IME, selection, saves, undo and source navigation apply immediately.
Editable widgets keep a stable wrapper/focus tree throughout effects; outgoing
editors are never retained. Direct input settles finite visual effects. Reduced
removes spatial travel and replay; Off removes nonessential custom animation.
No repeat timers or constant decorative tickers. Canvas export defaults have an
empty reveal map and render complete source, independent of replay position.
Device-only `motionOptions` preserves old/malformed/unknown settings. No content
schema, migration, repository command or storage-authority change.

## Final integration validation

- **28 new regressions** across presentation, session compatibility, Unicode,
  focus/composition, OS caps, ephemeral gestures, image lifetime, reset/Undo and
  compact enlarged-text dialogs.
- Full run: **3,003 passed, two existing skips** in **12:09**. A subsequent localized
  dialog cleanup put previews first, folded detailed controls and widened desktop
  presentation. **59 focused/real-font checks passed** in **9 seconds** after that
  cleanup and one added UI test. No additional full run is claimed afterward.
  Earlier native PDF/motion batch: **94 passed** in **21 seconds**.
- Final analysis clean (**7.5 seconds**); format/strict clean across **751 files**.
  PDF checks verify requested page restoration even if closed before animation
  completes, and cancellation on direct interaction. Sparse pressure-tip
  interpolation and preview image ownership are also covered.
- Actual-widget renders with real fonts visually reviewed:
  `build/previews/orbit-motion-studio.png` and
  `build/previews/orbit-canvas-presentation.png`. Advanced controls remain
  keyboard accessible; choosing a concept brings its preview into view.
- Windows app + matching host built (**92.1 seconds** Windows compile). **897**
  frozen inputs unchanged; seven runtime/host files, **13** packaged font hashes
  and registered Google client verified. The new studio, presentation and laser
  strings are present in the actual Windows AOT payload.
- Standard JavaScript web build passed (**111.1 seconds**). Existing Google-identity
  SDK Wasm dry-run and Cupertino font warnings remain. No Wasm/Android build or
  physical-device/manual pen acceptance is claimed in this validation.
- No desktop control, app/host launch, private account/Vault work, publication or
  shutdown. Tests use synthetic/private test data and approved local loopback.
  Existing unrelated work and older packaging artifacts are preserved.

**Run the current direct build:**
`build/windows/x64/runner/Release/orbit_note.exe` with sibling runtime/data files.
The archive recorded below belongs to earlier validation; it was not regenerated
for the final dialog changes. The coverage table remains authoritative: the
70-item inspiration catalog does not imply 70 complete application workflows.

## Earlier validation (retained)

Focused and regression suites passed (94 focused checks, including motion studio,
settings, UML interaction, and PDF navigation regressions). Corrected edge cases:
PDF paper tones observe reader controls, motion previews halt on OS reduced motion,
and Canvas preview images persist throughout dialog closing animations. Fixed unbraced
flow control in PDF reader navigation to satisfy strict analyzer rules.
Formatting clean: 751 files checked with 0 changes (`dart format --output=none --set-exit-if-changed lib test`).
Analyzer clean with zero issues in 13.6s (`flutter analyze --no-pub`).
Windows release compiled in 95.1s (`build/windows/x64/runner/Release/orbit_note.exe`).
Distribution package assembled: `release-assets/OrbitNote-Windows-x64.zip` (34.5 MB,
SHA-256: `e64cb0890b6b23bbfbe020c4ac4b93588f06d81add5b0f20e6dc7c68f1535795`),
with matching checksum recorded in `release-assets/SHA256SUMS-Windows.txt`.
No desktop-control or manual hardware pen acceptance claimed.

Suggested next task: native PDF/pen performance and interaction acceptance for
these effects with large real documents; do not build another feature ahead.
