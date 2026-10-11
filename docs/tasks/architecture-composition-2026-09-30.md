# Search and precise-reference composition — 2026-09-30

Owner: attached architectural/product leverage request. Requirements: LNK-01/03/04,
LNK-10, CAN-03 and existing navigation/storage compatibility contracts.
Existing worktree changes are preserved; no reset, package or sync protocol change.

## Current-code audit

| Initiative | Baseline classification | Evidence / delivered direction |
|---|---|---|
| Universal objects/repository | Already done | UUID identity, versioned portable sources, history, recoverable commands; retained |
| Native search/index | Partial | Rebuildable trigram FTS5, incremental upsert, bounded 100 candidates; retained |
| Shared search | Partial | Separate `searchRank`, quick rank, canvas search; shared name ranking + rich coordinator now used by global search and command results |
| Notes/LaTeX deep search | Missing | Root opening only; now source matches, headings, explicit blocks and labels route to editable blocks |
| Canvas search | Partial | Local element search/focus already works; global results now carry element UUIDs |
| PDF extraction across Vault | Architecturally blocked | PDFium text search belongs to active reader; no durable page-text index. No invented page results/OCR |
| Object/PDF-page links | Already done | Existing WikiLinks + object/page syntax; anchor loss in display rendering corrected |
| Precise block references | Missing | Added lazy explicit prose anchors, ambiguity/missing safety, lossless rich projection |
| PDF annotation identity | Already done | Annotation note UUID + source checksum/page/regions; existing source-open path retained, structured annotation targets route through it |
| Backlink context | Partial | Existing snippets and relationship types retained; exact target + source locations added |
| Whole-note Canvas cards | Already done | Live object references/presentation; retained |
| Note-block transclusion | Missing | Explicit block source + placement target, no text copy; normal controller save/history |
| Canvas-to-Note | Partial | Existing export copied selection; added explicit element reference clipboard action; export remains deliberate copying |
| Canvas spatial index | Already done | Bounded uniform grid, dynamic updates, query/hit/selection, world coordinates; Gemini linear-scan claim outdated |
| Huge spatial bounds safety | Partial | Cell-count multiplication could overflow; bounded-dimension guard added |
| Ink/static cache | Partial | Text/minimap caches already present; no new ink cache without representative paint measurements |
| Controller ownership | Partial | Repository boundary already sound; extracted search merging/background service, facade retained; other responsibilities deferred |
| Session ownership | Partial | Flat device settings mixed preferences/IDs; AppPreferences now owns appearance/editor defaults with compatible SessionState access |
| Projects/Views/resume | Already done / partial | Existing UUID views, project dashboard, tabs/positions/cameras/PDF page retained; exact targets use shared requests without persisting hover state |
| Sync | Already done / partial | Existing adapters/conflict safeguards retained; no CRDT or protocol rewrite |

The four Gemini health fixes in the owner's baseline were found in current code
and were not reimplemented. The claimed 1,016-test baseline is independently
rechecked by this task's final suite rather than adopted as fresh evidence.

## Delivered architecture and behavior

`WorkspaceRepository.search` keeps SQL authoritative only as an accelerator.
`projectWorkspaceSearch` merges indexed candidates, current drafts, names/context
and Canvas references. `OrbitSearchCoordinator` returns object, match kind,
context, snippet, deterministic score and precise target. Global Search and command
body results use it. Quick Switcher stays intentionally names/context/fuzzy only;
all surfaces now share `quickOpenRank` name ordering. Literal queries remain offline.

Exact title → alias → prefix → substring → context precede heading/body/property
matches. Within equal relevance, current project and recency precede normalized
title/object-ID/source-position tie breakers. No AI/opaque relevance.

Native projection/fallback above 64K estimated source work uses an isolate; small
work remains cheap. Browser memory index caches normalized search text per revision.
Browser projection does not claim worker execution. The index still returns 100
object candidates and global projection returns 100 location results; no complete
pagination or filter-before-index-query claim. Canvas references resolve current
canonical content, rather than stale copies of source body in index rows.

The shared `ObjectReference` carries object UUID plus optional page or typed anchor.
`[[UUID#^block-id]]`, heading text, `#element=UUID`, `#label=...` and annotation targets
are portable. Unknown fragments survive and are never silently repaired. Heading
names are readable but renaming invalidates an un-ID'd heading link. Duplicate
headings/IDs/labels are ambiguous. Search offsets are transient and checked against
the searched body snapshot; offsets are never serialized as knowledge identity.

Note copy menu: **Copy current block reference**, **Place current block on Canvas…**.
Only an ordinary prose block gains ` ^orbit-UUID`, and only on explicit reference
creation. No Vault-open rewrite. Rich prose hides/preserves the suffix; source/export
stays readable. Canvas card `objectId` plus `referenceTarget` owns no note text.
Changes read from the same canonical note; deletion shows a missing-source state.
Multiple placements share one source. Source opens at its exact block.

Canvas context menu: **Copy Canvas element reference**. Pasting into a note uses
normal WikiLink navigation back to the element and camera focus/selection. This is
a reference, not an interactive Canvas nested inside the Markdown renderer.

Backlinks preserve relationship/snippet and expose precise target fragments. Source
clicks request the source location. LaTeX uses existing labels, without injecting
new ones. PDF page and annotation routes reuse source-version safeguards.

`AppPreferences` separates appearance/editor defaults. SessionState remains a
compatibility facade for existing UI; flat version-1 serialization and old defaults
stay unchanged. Unknown top-level settings survive. No eager migration or new
database schema; optional Canvas fields fit the extensible v1 envelope.

## Validation

Complete for the delivered subsystem, 2026-09-30:

- Final full suite: **1,027 tests passed** (96 seconds), including eleven new
  reference/search/composition tests. Final analyzer: **no issues**, 10.2 seconds.
- `dart format lib test tool` and final no-change format check: 346 files,
  zero final changes. Evidence: `.local/architecture-final-tests.log` and
  `.local/architecture-final-analyze.log`.
- Normal Windows release (`lib/main.dart`, existing local Google build defines):
  **built successfully, 61.0 seconds**; `.local/architecture-windows-release.log`.
  The temporary review build has been replaced. Normal release launched and
  Home, explorer calendar and **Saved locally** state were observed read-only.
- Native sample review reached Home and Search. Text injection and user activity
  prevented completion of the manual cross-type/deep-navigation/clipboard script.
  Those behaviors have automated domain/controller/widget coverage; native manual
  acceptance is partial, not claimed complete. No user content was edited.
- Android was not rebuilt: the Android SDK remains unavailable on this machine.
- CPU diagnostic (`dart --disable-dart-dev tool/search_spatial_benchmark.dart`):
  1k/5k/10k fixtures each queried 30 spatial candidates, versus 1k/5k/10k linear
  candidates. Across 300 queries, indexed times were 5,231/1,567/953 microseconds;
  linear times 10,401/18,175/28,174 microseconds. Rich search projection took
  32,764/75,029/121,698 microseconds. These are synthetic, warmup-sensitive CPU
  measurements of the existing grid, not FPS or a new-index before/after claim.
  Evidence: `.local/architecture-performance.log`.

Executable: `C:\Users\isa\Desktop\Orbit Note\build\windows\x64\runner\Release\orbit_note.exe`.
Release directory: `C:\Users\isa\Desktop\Orbit Note\build\windows\x64\runner\Release`.

## Deliberate remaining work

## Requested report checklist

1. Architecture: portable canonical objects, derived index, controller facade,
   existing scene/ink engine; see the audit above.
2. Gemini findings: classify against implementation in the audit table;
   the linear-only Canvas premise is outdated.
3. Search before: indexed object candidates and separate surface projections.
4. Search after: shared location coordinator with application snapshot boundary.
5. Ranking: explicit deterministic name/context/content tiers described above.
6. Navigation: rich/source selection, Canvas camera focus and existing PDF routes.
7. References: UUID plus optional typed fragment; unknown fragments survive.
8. Anchors: lazy unique prose IDs only on explicit reference creation.
9. Markdown: readable suffix preserved losslessly, no open-time rewrite.
10. Notes: block and heading targets; ambiguous/missing targets fail visibly.
11. Canvas: stable element UUID targets and source block cards.
12. PDF: existing page/annotation routes preserved; page-text indexing deferred.
13. LaTeX: existing section/label targets, no automatic label insertion.
14. Backlinks: precise source and target locations retained.
15. Note to Canvas: live source references through normal save boundaries.
16. Canvas to Note: portable element links; no interactive nested Canvas.
17. Spatial choice: retain the existing incremental uniform grid, not a new tree.
18. Canvas performance: oversized-cell safety and candidate diagnostics.
19. Ink caching: no new cache without representative paint evidence.
20. Controller: search composition extracted; wider decomposition remains.
21. Session: AppPreferences ownership behind compatible accessors.
22. Schema: optional Canvas referenceTarget, unchanged v1 settings/storage.
23. Compatibility: old defaults/formats and unknown settings preserved.
24. Tests: eleven new domain, reopen, projection, preferences and widget tests.
25. Total: 1,027 passing full-suite tests.
26. Analyze: no issues.
27. Windows: normal release built successfully in 61.0 seconds.
28. Android: SDK unavailable; no APK claim.
29. Smoke: normal launch/Saved locally verified; native interaction script partial.
30. Performance: synthetic CPU measurements in Validation, no FPS claim.
31. EXE: exact path in Validation.
32. Release directory: exact path in Validation.
33. Limitations: bounded search results, browser projection on main thread,
   heading rename ambiguity and incomplete native interaction acceptance.
34. Deferrals: below; no partially migrated persistent subsystem.
35. Next milestone: rebuildable PDF page-text indexing with recovery evidence.

### Deferred scope

Vault-wide PDF extracted-page indexing; complete search pagination/scope queries;
interactive Canvas previews in notes; persistent deep navigation history beyond
existing caret/camera/page state; full controller session/navigation/draft/template
decomposition; ink caching after paint profiling; native manual acceptance where
computer-use is interrupted. No partially migrated persistent subsystem remains.

Next suggested milestone: bounded, rebuildable PDF page-text indexing composed
with the same location model, including encrypted/replaced-document recovery.
