# Long-note performance — 2026-10-01

Owner accepts the recommended long-note performance pass. Scope: EDT-02/03/04/13/15
performance hardening, preserving source, rich blocks, selection/history, existing
features and animations. No desktop automation, dependencies, persistence changes,
truncation, delayed saves or disabled assistance.

## Plan and implementation

- Replace repeated linear block searches and source joins with a transient source
  position index. Recreate it after content/order/projection mutations; retain
  original MarkdownBlock identities and live controllers for unaffected blocks.
- Reuse the active paragraph's inline projection and recorded heading descriptors.
- Cache footer statistics, line starts and outlines per exact source version;
  caret/selection/scroll updates reuse results without delaying content updates.
- Reuse selection statistics for an unchanged selection. Compute no-space counts
  when that metric is requested, avoiding a stripped copy of the whole note.
- Walk sorted spelling/grammar issues once when constructing spans instead of
  searching every issue for every character. Rich marks compare sets directly,
  avoiding temporary joined strings per character. Assistance remains enabled.
- Validate exact positions, source preservation, Unicode/CRLF, empty boundaries and
  edits/reorders; benchmark mixed long notes. Add an editor lifecycle regression.

Full Rich layout still uses its existing eager column. This pass removes quadratic
lookup work without introducing virtualization that could dispose focused fields
or change drag, selection, collapse, embedded blocks or precise navigation.

## Validation

- `dart format lib test tool/note_performance_benchmark.dart`: clean, followed by
  strict no-change formatting (350 files).
- `flutter analyze --no-pub`: clean (12.0s).
- `flutter test --no-pub`: **1,064 passed, four failures** (2m04s). All new index,
  rich-block/controller and footer checks pass, along with spelling/grammar,
  table/math, mode/selection/history and composition regressions. The suite is not
  clean; the failures listed below remain unresolved.
- Normal `lib/main.dart` Windows release built with the existing local build
  configuration (91.4s). No review build or desktop automation was used.
- Scoped `git diff --check`: clean. Unrelated existing work preserved.
- Reproducible pure Dart checks and benchmark:
  `dart --disable-dart-dev tool/note_performance_benchmark.dart` passed.
  Includes source/offset/identity, Unicode/CRLF, empty/EOF boundaries, edit/reorder
  refresh and repeated/forward/backward grammar-issue queries.

Logs: `.local/long-note-analyze.log`, `.local/long-note-full-tests.log`,
`.local/long-note-benchmark.log`, `.local/long-note-windows-build.log`.

## Benchmark evidence

Windows, Dart 3.12.2 JIT; same mixed-source fixtures and process. Median of 20 timed
samples after three warmups for block/source work and index rebuild; seven samples
for footer/issue lookup. Absolute times depend on the host and JIT warmup. This is
a Dart bookkeeping microbenchmark, **not native frame time or end-to-end typing
latency**. Flutter UI mounting/layout, analysis, history diffs, saving and paint
are not included. CPU model/display metrics were not captured.

| Paragraphs / blocks / source UTF-16 units | Old lookup/source work | Cached work | Fresh index + source join |
|---|---:|---:|---:|
| 200 / 467 / 11,432 | 0.565 ms | 0.072 ms | 0.345 ms |
| 1,000 / 2,323 / 57,512 | 5.402 ms | 0.044 ms | 0.371 ms |
| 3,000 / 6,963 / 174,792 | 41.923 ms | 0.217 ms | 0.775 ms |

Workload: two identity lookups per block, six source reads and 30 near-end offset
queries. The indexed result is reused only while that source/order remains valid;
a source edit pays the separately measured fresh-index cost. New caches retain
bounded current document/selection/outline versions, not an unbounded note cache.

Thirty unchanged-source caret/footer updates on the largest fixture: 868.238 ms
to 0.005 ms for the measured statistics/position work. A 30,000-character annotation
lookup workload with 1,000 issues: 31.794 ms to 0.085 ms. These isolate cache reuse
and the forward issue scan; they do not measure a whole key event or guarantee FPS.

The test runner now executes, unlike the previous native-check task. Both full
suite runs: 1,064 passed, four editor failures. The same four fail with the old linear
lookup/source paths restored, and the performance source was restored in finally:
stale selected-block menu, Delete join, bullet exit/nesting, numbered-list exit/nesting.
Evidence: `.local/long-note-linear-baseline-tests.log`. No production boundary/menu
repair or weakened test expectation is included in this performance task.

The added long-note editor regression changes prose in a mixed 120-paragraph note,
navigates using the new source offset, checks unaffected prose/table/code controller
identity and equation widget identity, then undoes to the exact original source.
The footer regression checks Unicode edits and changing selection statistics.
Both passed in the initial full suite, as did the earlier composition history test.

Next suggested task: resolve the four paragraph/list/menu regression failures now
that Flutter tests can execute, starting with their actual input/focus behavior.
