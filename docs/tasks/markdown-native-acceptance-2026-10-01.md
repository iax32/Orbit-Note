# Native Markdown acceptance — 2026-10-01

Owner authorizes the suggested native checks for IME and cross-block undo.
Use the in-memory `tool/ui_review.dart` NoteEditor fixture with
`ORBIT_REVIEW_MARKDOWN=true`. Its final copied bundle is
`.local/markdown-native-final`; the normal release must be
restored with `lib/main.dart` before delivery. No user vault edits for acceptance.

## Planned evidence

- Normal native keyboard input, Unicode, paragraph split/join and undo/redo.
- Formatting selection, structural undo across Rich/Source and repeated paragraphs.
- Controlled input-client composition events in the native app: active range after
  source/save acknowledgement, undo/redo guards, commit/cancel and later history.
- Observed failures receive focused regressions and repairs before rebuilding.

Configured input languages are en-AT/en-US/en-GB with US/German keyboard layouts;
no CJK IME is listed. Controlled Flutter text-input events and literal Unicode
entry are not evidence of OS IME candidate-window or keyboard-layout acceptance.
Windows Application Control blocks the Flutter test runner; keep automated coverage
separate from actual native interaction.

## Delivered repair

Native review reproduced Undo restoring canceled composition text. Intermediate
input updates had been recorded as individual document edits. Rich input also
notifies controller listeners before onChanged updates Markdown, so immediately
closing the history group could record the pre-cancellation source.

NoteEditor now tracks the original source during composition, records its committed
result as one edit, and ignores a canceled no-op without clearing redo. Rich
controller completion is observed after its source projection, using a microtask.
Listeners are removed on completion, reset and disposal; document undo/redo refuses
an active composition. No knowledge storage format or dependencies change.

## Native observations

Windows release fixture uses the production NoteEditor and ephemeral strings;
it opens no workspace or user vault. The full workspace review bootstrap did not
expose a usable window, so acceptance used the isolated editor entry point.

- Controlled Rich composition range 32–34 survived the body callback and rebuild;
  committing removed that range and preserved bold Markdown around Alpha beta.
- On the corrected build, Rich cancel restored the original 157-character source.
  Clicking Undo left it unchanged, rather than resurrecting temporary kana.
- A native block control inserted a blank paragraph between formatted prose and
  the next paragraph (159 characters). Undo from Source restored 157 characters.
- With that insertion in the redo stack, a Source composition (range 60–62) was
  canceled. Returning to Rich and clicking Redo restored the 159-character document;
  cancellation preserved redo and the existing paragraph/code content.
- A committed Rich composition was then undone from Source: source shrank from
  161 to 159 characters, retaining the separately inserted paragraph and bold
  Markdown. Earlier commit/undo/redo checks also restored the whole committed word.

The F8/F9/F10 review controls deliver controlled Flutter input-client events.
They are not OS IME candidate-window tests. Scripted Unicode typing, Return and
several editing chords produced no visible change in this automation session;
their input delivery was not established. Those keyboard checks remain unverified,
and the absence of changes is not evidence that shortcut guards pass. No speculative
keyboard-routing repair was made. A real OS IME is not configured or installed.

## Validation

- Added Rich/Source widget regression for multi-update commit, undo/redo and cancel.
- `flutter analyze --no-pub`: clean (10.0s; final evidence in
  `.local/markdown-native-analyze.log`).
- `dart format lib test tool` and strict no-change format check: clean.
- `flutter test --no-pub --fail-fast`: Application Control blocked
  `flutter_tester.exe` before any tests ran. The blocked attempt was interrupted
  after repeated load failures; the new widget test is not claimed to pass.
- Native fixture Windows release build: passed (48.0s).
- Normal `lib/main.dart` release restored (59.8s) with existing local build configuration;
  final evidence in `.local/markdown-native-normal-build.log`.
- Full diff whitespace check identified existing trailing spaces in unrelated
  workspace sample Markdown. No unrelated content was rewritten for this task.

Next suggested task: a manual native keyboard and actual OS IME candidate-window
acceptance pass, covering ordinary typing, Enter/Backspace and document shortcuts.
