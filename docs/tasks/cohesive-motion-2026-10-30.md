# Cohesive interface motion — 2026-10-30

Owner requests a large clean-animation update across Orbit, continuing the
previous tablet comfort and movable-toolbar work. This is a MOT-01/02/04/06
presentation update on existing Flutter/local boundaries, with no dependency,
knowledge format or engine change. Physical live-sharing issues stay out of scope.

## Delivered

- Over 230 existing dialog entry points, including draft guards and long-running
  operation surfaces, share the same modal arrival/result/focus contract.
- More than 100 tool menus plus context menus and three mobile editing sheets
  share Orbit timings, speed and reduced/off behavior. Native platform pickers and
  specialized PDF/authored presentation retain their existing contracts.
- Desktop explorer entrance, Settings category and search-mode arrival, category
  selection, tab action fading and current save/sync labels gain consistent finite
  feedback. Typing/searching does not replay an entrance per keystroke.
- Off/Reduced transitions preserve the child hierarchy and focus/drafts. Hidden
  tab controls stop taking input/semantics at once; no outgoing editor stays alive.
- Existing active ambience controllers stop under reduced/off/OS reduction,
  disabled navigation and hidden TickerMode, avoiding invisible ticking.
- Settings checks discovered that a newly constructed session could have const
  extra options while Settings consumes a navigation hint. SessionState now owns
  a mutable shallow copy, retaining unknown values and the caller's original map.

## Validation

Initial motion/focus/ink batch: 61 checks pass. Expanded checks caught a missing
Material between an animated selection background and ListTile (fixed), the
session extra-map issue (fixed with caller-ownership/reload coverage), and a test
assertion that included unrelated theme animation; the final fixture measures its
own state opacity/static-child rebuilds and then verifies full settlement.
Seventy targeted settings/tab/split/draft/operation checks then pass in 12 s.
Final combined checks, analyzer, format and native build/publication evidence are
recorded in current.md. Actual-font 60 ms arrival and settled dialog captures were
inspected. No medical, zero-lag or physical-device acceptance claim.

## Remaining boundary

Flutter modal duration is captured when a route opens; live policy changes remove
custom spatial motion without remounting content. System pickers and third-party
native windows use platform transitions. Drawing samples/camera, text input,
persistence and export remain unchanged. Suggested next task: physical tablet
and keyboard-navigation motion review; do not start it implicitly.

Final combined regression run: 140 passes and one obsolete menu timing assertion
failed; it expected the old 200 ms focus menu rather than shared 180 ms. Updated
that assertion; all seven focus checks pass in 1 s. Thus 141 unique checks are
covered. Analyzer lib/test/tool clean (9.6 s); strict 923 files unchanged (8.03 s).
The large-Canvas test measures debug/test CPU, not native stylus latency. The
static-state child is not rebuilt across 16 animation frames; text and pen data
remain immediate and pixel fidelity checks pass. No further test broadening was
needed after the corrected timing assertion passed.
