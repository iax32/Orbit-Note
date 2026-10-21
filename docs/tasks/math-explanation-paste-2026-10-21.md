# Math explanation paste — 2026-10-21

## Scope

Owner-requested EDT-04/12 clipboard subset. Normal Rich paste imports mixed
explanations and LaTeX from plain text and browser HTML. No account/API, external
renderer, dependency, persistent schema or document migration. Existing Markdown
save/history boundaries remain authoritative; unrelated changes are preserved.

## Behavior

- Balanced `\(...\)` inline and `\[...\]` display delimiters become ordinary
  `$...$` / `$$` Markdown. Existing dollar equations and Unicode remain intact.
- KaTeX wrappers recover TeX once from MathML annotations rather than duplicating
  their accessibility/rendered output. MathJax MathML, direct TeX annotations,
  data-latex attributes and legacy math/tex source scripts are supported.
- TeX entities and spacing survive conversion; quoted HTML attributes are parsed
  without mistaking their contents for source attributes. annotation-xml fallback
  cannot consume a later TeX annotation. Multiple independent formulas survive.
- Display boundaries avoid extra empty paragraphs. In browser tables/list items,
  equations use inline form to stay within the same cell/item; table pipes escape.
- Read, embedded/column/callout/Study math and publication export share the table
  quoting correction. Norm bars retain authored backslashes; surrounding bold,
  links (including forward definitions) and literal code keep normal parsing.
  This is a presentation snapshot adjustment, never a rewrite of stored notes.
- Code spans/fences (including longer fences), indented code, reference
  destinations, links and URLs stay literal. Ctrl/Cmd+Shift+V, Source and code-field
  paste retain the plain clipboard text. Currency is not inferred into math.
- Incomplete/unsupported fragments retain available text; unsupported TeX source
  retains the existing render fallback. Existing
  clipboard ownership/revision/composition guards and document undo/redo remain.

## Use

Copy a response/explanation, open the note's **Rich** mode and press Ctrl+V (Cmd+V
on macOS). Equations remain editable with the existing math controls. Use Source
to inspect the stored Markdown; use Ctrl/Cmd+Shift+V for literal pasted text.

## Validation

- 46 added regressions; focused editor/clipboard/publication batch: **192 passed**.
- Final full suite: **2,815 passed, 2 existing environment-dependent skips**
  (Windows link privilege and manual Google consent), 5m02s.
- Format and strict check: **714 files clean**. `flutter analyze --no-pub`:
  **No issues found**. Full tests use configured Python and concurrency 6.
- Read-mode rendering and export nodes agree on norm bars; enclosing formatting,
  forward links, literal code, keyboard paste, undo/redo and literal modes verified.
- Configured Windows/server build passed (132.2s), standard JS web build passed
  (74.2s). A separately staged, hash-verified 485-file source snapshot retained the
  configured app client and avoided the running app's locked release folder.
- Runtime files and custom font hashes match. Payload freshness verified; no
  application/server was launched. Native dependency setup reused verified plugin
  targets via directory junctions; no Developer Mode/security settings changed.
- Verification at **2026-10-21 13:12 CEST**:
  - Windows `data/app.so`: 25,133,968 bytes,
    `0C0D13F8C86B554FA5FC97855553E2193E08C62668F27293C2D4C5BEFA17C64E`.
  - Web `main.dart.js`: 10,750,348 bytes,
    `18B98D5DC078A2CB729809CC71D88EE58EAA00FA5CA354F8B848455B1EB28688`.
  - Server: 7,595,520 bytes,
    `E16203230DE8A221FD034EF02A610907627B46DBADC726DCA0DE105150DFDAAA`.

Run `build/releases/Math Paste/orbit_note.exe` with its runtime siblings. No ZIP.
Release evidence: `.local/math-paste-release-verification.json`,
`.local/math-source-snapshot.json`, `.local/math-paste-windows-build.log` and
`.local/math-paste-web-build.log`.

Logs: `.local/math-paste-format.log`, `.local/math-paste-format-strict.log`,
`.local/math-paste-analyze.log`, `.local/math-paste-focused.log`,
`.local/math-paste-full.log` and `.local/math-render-focused.log`.
Synthetic browser/clipboard payloads and headless editor tests only; no desktop
control, personal Vaults, cloud operations or app launch.

A standalone Dart debug/JIT probe on this Windows host preserved 1,400,000 UTF-16
units / 100,000 unfinished delimiters in 175 ms for each delimiter kind. 100,000
multiline openers sharing one closer retained later valid math in 195 ms. This
measures the normalizer only, not end-to-end clipboard/rendering performance.
Closing-delimiter caching prevents repeatedly rescanning malformed suffixes;
code-fence matching avoids copying the remaining document for each fence.
A synthetic 1,000-formula HTML explanation verifies no duplicates/token leakage.

An initial full run overlapped scanner edits and was stopped at its slow malformed-
input case; it is not counted as passing. A later run was stopped before the
final table-bar correction. Final validation runs only after the source is saved.
Interrupted output remains `.local/math-paste-full-interrupted.log` and
`.local/math-paste-full-before-table-fix.log`. A subsequent passing run before
rendered table parity is retained as `.local/math-paste-full-before-render-fix.log`;
final evidence below supersedes it.

## Limits

A clipboard carrying only raster/rendered glyphs with no TeX source cannot recover
an exact equation. Copy the response as Markdown/LaTeX in that case. Unsupported
TeX macros retain the existing source fallback; this is not a new TeX engine.
Browser table/list display math uses inline presentation. OS clipboard/hardware
acceptance remains unverified. Existing standard-web warnings concern the Google
SDK's Wasm dry-run compatibility and missing Cupertino font; this is a successful
standard JS build, not a Wasm build. Platform adapters are exercised through their
existing mocked channel tests. No Android APK or GitHub release is requested.

Suggested next task: equation labels, numbering and cross-references; stop before
implementing it.
