# Technical articles, research diagrams and CMS publishing

Status: validated. Owner requested templates and diagram/tools for articles
about game memory research and reverse engineering, plus current Google SEO
guidance. Owner selected WordPress or another CMS as the publishing destination.

Scope: EDT-09 templates/tools, REV-02/03/04 recorded context and evidence,
CAN-07/13 linked technical diagrams and PORT-05/06 export fidelity. Reuse the
shared Canvas engine, ordinary note commands/history and publishing metadata.
No debugger, live process access, new dependency, external account connection,
automatic publication, ranking promise or penalty-avoidance claim.

Plan and implementation:

- Four configurable articles: memory research, reverse-engineering case study,
  build comparison and game-system deep dive. Capture audience, research question,
  game/build, architecture and tools as authored Markdown.
- Four editable scene presets: memory layout, pointer chain, call flow and
  evidence/validation. Create from Canvas or insert a linked live diagram from a
  note. Extend the existing diagram bridge to ordinary technical shapes.
- Recorded 32/64-bit hexadecimal base+RVA arithmetic, width overflow checks,
  little-endian address representation and Markdown calculation insertion/copy.
- Optional version-1 article fields inside the existing publication record,
  preserving unknown fields and refusing replacement of future formats.
- Offline publishing panel: descriptive metadata, author/dates/canonical/image,
  indexability choice, deterministic editorial prompts, CMS HTML and handoff,
  standalone HTML metadata and honest Article JSON-LD. Preserve stale drafts.
- Explain CMS sanitation, local figures/private links, crawl/index checks and
  Search Console diagnostics. Do not invent an SEO score or diagnose a live site.

Primary references checked 2026-10-17:

- https://developers.google.com/search/docs/fundamentals/seo-starter-guide
- https://developers.google.com/search/docs/fundamentals/creating-helpful-content
- https://developers.google.com/search/docs/appearance/structured-data/article
- https://developers.google.com/search/docs/essentials/spam-policies
- https://developers.google.com/search/docs/monitor-debug/debugging-search-traffic-drops
- https://wordpress.org/documentation/article/custom-html/

Focused validation: **43 passed in 6s**, including **15 new tests** for metadata
and authored-CRLF/unknown-field retention, future records, URL/date/script
validation, HTML/CMS fidelity, code-aware prompts, actual live-object/private
links, exact address arithmetic, editable scenes/references, native restart,
configured templates/insert-mode preservation, Canvas single-step Undo,
stale-note rejection, real NoteEditor-to-Canvas creation and narrow 2x text.
The source bridge test initially caught an intentional insertion spinner keeping
the test event loop active while the interactive dialog awaited user input; the
dialog now avoids showing underlying progress during user choice. Assertions
were retained. No timeout increases, warning suppression or exclusions were added.

Headless native rendering: **2 visual tests passed**. Inspected the actual dialog
overlay and enlarged-text handoff, widened the desktop research dialog so all
three diagram nodes are visible, and retained scrolling/Expand on narrow screens.
Artifacts: work/ui/technical-{research-diagram-preset,article-cms-large-text}.png.
The first capture selected the underlying route; a test-only repaint boundary
was added to capture the dialog, without changing global test helpers.

A full run was intentionally interrupted at 843 passed/2 existing skips during
final review to add the actual `orbit-object:` link check and exclude wiki-link
examples inside code. That partial run is retained at
.local/technical-article-tests-interrupted.log and is not a full passing run.
Fresh full regression: **2,399 passed, 2 existing skips in 3m50s**, exit zero.
Existing skips cover native symlink permissions and manual Google consent.
Final analyzer: **no issues in 18.3s**. Required format and strict format pass
for **663 files**. Scoped whitespace checks pass. No packages, analyzer
exclusions, new skips, timeout changes or desktop-control tests were added.
Full regression log: .local/technical-article-tests.log.

Release validation: **Windows passed in 93.0s** with the registered Google
desktop client. The standalone server compiled without starting a server or
packaging keys. **Web JavaScript passed in 82.6s**; existing Google Identity
WebAssembly dry-run incompatibility and missing Cupertino font warnings remain.
This is not a Wasm validation. Both build commands exited zero.
Logs: .local/technical-article-{windows,web}-build.log.

The runnable release remains build/windows/x64/runner/Release/orbit_note.exe,
with Flutter/PDFium/SQLite runtimes, ICU data, Flutter assets and the server/
launcher verified present and nonempty. data/app.so is **24,511,376 bytes**,
written 2026-10-17 18:07:33 Europe/Vienna, newer than all 16 production files
in this task. The native runner retains its earlier timestamp; Dart application
code is in app.so. Web main.dart.js exists and is nonempty. Artifact evidence:
.local/technical-article-release-check.json. No ZIP was created.
Evidence: .local/technical-article-{focused,visual,format,format-check,analyze,fix,test-fix}.log.

No desktop-control testing, personal Vault access, real CMS publication or live
Google account/site audit is used. The earlier shutdown request belonged to the
completed previous task; this new task does not request another shutdown.

Suggested next task: a CMS media bundle that exports selected live diagrams and
local figures with a manifest for upload/relinking. Current public exports keep
explicit fallbacks for unavailable/private content. Do not implement that next
task in this completed update.
