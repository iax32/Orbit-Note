# Writing font and zoom quality

Status: completed and validated 2026-10-18. Owner reports low-quality Minecraft/Pixel notebook headings
and other fonts, especially after Ctrl-plus zoom. Scope: writing typography and
its existing app/OS scaling, font assets, Rich/Read/Source/Split presentation.
Preserve existing writing designs, content, selections and unrelated work.

Plan: inspect actual font metadata/outlines and render real-font zoom specimens;
repair unsuitable heading weights and missing font faces; keep native scalable
text and normal zoom for non-pixel content. Verify actual themed headings,
accessibility/DPI zoom, font changes, selection and controller retention. Run
formatting, analysis, full tests and configured Windows/web release builds.
No desktop-control testing, personal Vault changes or shutdown.

Observed: Tiny5 regular outlines use a 128-unit grid in a 1024-unit em. The
requested 600/700 variable weights move their outline edges off that grid;
font-size snapping alone cannot make those outlines crisp. Space Mono only
registers its regular face despite bold/italic formatting requests. The current
PixelFontScope also quantizes every descendant font, including specialist code
and math. Evidence and final behavior will be recorded after verification.

## Implemented

- NoteTypography requests Tiny5's original 400 heading weight rather than the
  expanded off-grid 600 outlines. Note title, six heading levels, table headings,
  Rich/Read callout titles and font previews follow the same choice. Heading
  sizes retain hierarchy; authored emphasis and stored content are unchanged.
- Space Mono's real 700, italic and bold-italic files are bundled/registered.
  The existing regular file exactly matches the chosen upstream source commit;
  provenance and unchanged OFL notices are in `assets/writing/README.md`.
  Terminal headings choose real bold, with serif/sans behavior preserved.
- Symbol/emoji fallback families supplement the selected text family.
- Nested PixelFontScope restores the original app/OS scaler when disabled,
  rather than inheriting an already snapped scaler. Native code fields and
  rendered/editable math opt out; ordinary writing fonts stay continuous.
- No application package, storage/preference schema, note migration or renderer
  replacement. The optional headless capture ratio now records physical display
  resolution for the new specimens; other capture callers keep their defaults.

## Evidence

`.local/writing-font-repro.log` records three original heading/scaling failures.
The initial focused writing/design/font batch passed **36 tests** before the
additional integration matrix. The final new test file passes **14 tests**,
including actual code fields, math rendering, Ctrl-plus in Rich/Read/Source/Split,
and five custom families at 2x density plus enlarged OS text. Controllers,
selection and source callbacks remain unchanged through zoom.

Real bundled font captures at `work/ui/writing-font-quality-{rich,read,write,split}.png`
use 1.25 display density and 175% app zoom, at physical capture resolution.
`writing-font-quality-rich-before.png` retains the initial logical-resolution
specimen (not a pixel-for-pixel visual baseline). `.local/writing-font-visual.log`
records the passing matrix. Font table metadata, sizes and SHA-256 hashes are in
`.local/writing-font-assets.json`; all faces contain scalable outlines and no
embedded bitmap tables. FontTools was used only as ignored local inspection
tooling, not an app dependency. Real monitor/ClearType behavior is unverified.

Final source checks, 2026-10-18:

- `dart format lib test` and strict check: **667 files, clean**.
- `flutter analyze --no-pub`: **no issues**, 22.8s.
- `flutter test --no-pub --concurrency=6 --reporter expanded`: **2,465 passed**,
  **2 existing skips**, 4m01s. Skips remain Windows native symlink permission and
  manual real-Google-account consent/upload acceptance. Logs are in
  `.local/writing-font-{format,format-check,analyze,tests}.log`.
- `flutter pub get --offline` succeeded without lockfile/package changes; the
  manifest only adds actual font faces under the existing family.

- Configured Windows release: **passed**, 88.4s, with the existing Google desktop
  registration retained. Standalone server rebuilt; no server started or keys
  packaged. `.local/writing-font-windows-build.log`.
- Standard JavaScript web release: **passed**, 78.4s. Existing Google Identity
  Wasm dry-run incompatibility and missing Cupertino font-family warnings remain;
  no Wasm build is claimed. `.local/writing-font-web-build.log`.
- Runtime verification: Windows EXE, required DLLs, assets, Dart payload and
  standalone server/launcher present. Windows and web font manifests each contain
  all four OrbitTerminal faces; every packaged font hash matches its source.
  Both compiled payloads are newer than Dart, manifest and writing-asset inputs.
  `.local/writing-font-release-verification.json` records the result and SHA-256:
  Windows `data/app.so`, 24,560,528 bytes,
  `457BD299A40266AEE4469B4EE5E52720F27AC108F01C3714194F49524C54C69F`;
  web `main.dart.js`, 10,503,122 bytes,
  `A04DFC9A0C1D1B34C97016BBA10EB97BACB0AE0DDE5DFFBEECB2402AE425174B`.
- Scoped `git diff --check` passed, with only existing CRLF normalization notices.
  No app, test or collaboration-server process remains running.

Runnable Windows release: `build/windows/x64/runner/Release/orbit_note.exe`, with
its adjacent files. No desktop-control testing or personal Vault access was used.
Physical monitor-specific raster quality remains unverified; the square pixel
letter shapes are intentional. No claim that every font/display rasterizes
identically is made.

Suggested next task: document preview/export font-style fidelity audit. Stop
here; do not begin that next task without approval.
