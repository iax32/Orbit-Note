import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/orbit_components.dart';
import '../../app/workspace_controller.dart';
import '../../domain/study_card.dart';
import '../../domain/universal_object.dart';
import '../../platform/export_file.dart';
import '../notes/rich/note_math.dart';
import 'study_resume_panel.dart';

Future<void> showStudyWorkspace(
  BuildContext context,
  WorkspaceController c, {
  String? course,
  String? courseId,
  DateTime? exam,
}) => showOrbitDialog<void>(
  context: context,
  builder: (_) => StudyWorkspace(
    controller: c,
    initialCourse: course,
    initialCourseId: courseId,
    initialExam: exam,
  ),
);

Future<void> showStudyCardEditor(
  BuildContext context,
  WorkspaceController c, {
  UniversalObject? card,
  UniversalObject? source,
  String passage = '',
  int? page,
  String? checksum,
  String? course,
  String? courseId,
}) async {
  if (passage.length > 100000) {
    await showOrbitDialog<void>(
      context: context,
      builder: (ctx) => OrbitDialog(
        title: const Text('Choose a smaller passage'),
        content: const Text(
          'Cards retain up to 100,000 source characters. Open the note and select a shorter passage; the original note remains complete.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    return;
  }
  final question = TextEditingController(text: card?.title ?? '');
  final answer = TextEditingController(text: card?.body ?? passage);
  final courseField = TextEditingController(
    text:
        card?.properties['course']?.toString() ??
        course ??
        source?.properties['course']?.toString() ??
        '',
  );
  bool busy = false;
  final locked = c.repository.readOnly || card?.isReadOnly == true;
  String? error;
  try {
    await showOrbitDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, refresh) => OrbitDialog(
          title: Text(card == null ? 'New study card' : 'Edit study card'),
          maxWidth: 680,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (source != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Linked to ${source.title}${page == null ? '' : ' · page $page'}',
                  ),
                ),
              TextField(
                controller: question,
                autofocus: true,
                enabled: !busy && !locked,
                maxLength: 2000,
                maxLines: null,
                decoration: const InputDecoration(labelText: 'Question'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: answer,
                enabled: !busy && !locked,
                maxLength: 100000,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Answer',
                  helperText:
                      'Markdown supported. Edit the answer without changing the original source.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: courseField,
                readOnly: courseId != null,
                enabled: !busy && !locked,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Course or subject (optional)',
                ),
              ),
              if (error != null)
                Semantics(liveRegion: true, child: Text(error!)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: busy || locked
                  ? null
                  : () async {
                      refresh(() => busy = true);
                      final ok = card == null
                          ? await c.createStudyCard(
                                  question: question.text,
                                  answer: answer.text,
                                  course: courseField.text,
                                  courseId: courseId,
                                  source: source,
                                  passage: passage,
                                  page: page,
                                  checksum: checksum,
                                ) !=
                                null
                          : await c.editStudyCard(
                              card,
                              question.text,
                              answer.text,
                              courseField.text,
                            );
                      if (!ctx.mounted) return;
                      if (ok) {
                        Navigator.pop(ctx);
                      } else {
                        refresh(() {
                          busy = false;
                          error = c.error ?? 'Card could not be saved.';
                        });
                      }
                    },
              child: Text(card == null ? 'Create card' : 'Save changes'),
            ),
          ],
        ),
      ),
    );
  } finally {
    question.dispose();
    answer.dispose();
    courseField.dispose();
  }
}

class StudyWorkspace extends ConsumerStatefulWidget {
  const StudyWorkspace({
    super.key,
    required this.controller,
    this.initialCourse,
    this.initialCourseId,
    this.initialExam,
  });
  final WorkspaceController controller;
  final String? initialCourse;
  final String? initialCourseId;
  final DateTime? initialExam;
  @override
  ConsumerState<StudyWorkspace> createState() => _StudyWorkspaceState();
}

class _StudyWorkspaceState extends ConsumerState<StudyWorkspace> {
  String? _course;
  String _filter = '';
  int _tab = 0;
  DateTime? _exam;
  UniversalObject? _review;
  bool _revealed = false, _busy = false;
  String? _message;
  WorkspaceController get c => widget.controller;
  @override
  void initState() {
    super.initState();
    _course = widget.initialCourse;
    _exam = widget.initialExam;
  }

  Future<void> _run(Future<bool> Function() command) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final ok = await command();
      if (!mounted) return;
      setState(() {
        if (ok) {
          _review = null;
          _revealed = false;
          _message = 'Saved locally.';
        } else {
          _message = c.error ?? 'Could not save. Your review has not advanced.';
        }
      });
    } on Object catch (e) {
      if (mounted) setState(() => _message = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rate(StudyRating rating) async {
    final card = _review;
    if (!_revealed || card == null || c.repository.readOnly) return;
    await _run(() => c.reviewStudyCard(card, rating));
  }

  bool _matches(UniversalObject o) =>
      (widget.initialCourseId != null
          ? c.matchesStudyCourse(o, widget.initialCourseId!)
          : (_course == null || o.properties['course'] == _course)) &&
      (_filter.isEmpty ||
          '${o.title} ${o.body}'.toLowerCase().contains(_filter.toLowerCase()));

  @override
  Widget build(BuildContext context) {
    ref.watch(workspaceProvider);
    if (!c.hasWorkspace) {
      return OrbitDialog(
        title: const Text('Study & Review'),
        content: const Text(
          'The Vault was closed. Reopen it to review your cards.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    }
    final cards = c.studyCards.where(_matches).toList();
    final unsupported = c.activeObjects
        .where(
          (o) =>
              _matches(o) &&
              o.properties['studyCard'] != null &&
              !StudyCard.supported(o),
        )
        .length;
    final now = DateTime.now().toUtc();
    final due = studyQueue(cards, now);
    final upcoming = studyQueue(
      cards,
      now,
      horizon: _exam ?? now.add(const Duration(days: 7)),
    );
    final courses = <String>{
      ?_course,
      for (final o in c.activeObjects)
        if (o.properties['course'] is String &&
            (o.properties['course'] as String).isNotEmpty)
          o.properties['course'] as String,
    }.toList()..sort();
    final readonly = c.repository.readOnly || _busy;
    return OrbitDialog(
      title: const Text('Study & Review'),
      maxWidth: 900,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Read, recall, and return to the source. Your cards and review history stay in this Vault.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 230,
                child: DropdownButtonFormField<String>(
                  initialValue: _course ?? '',
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Course'),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('All subjects'),
                    ),
                    for (final course in courses)
                      DropdownMenuItem(
                        value: course,
                        child: Text(course, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: _busy || widget.initialCourseId != null
                      ? null
                      : (v) => setState(() {
                          _course = v == '' ? null : v;
                          _review = null;
                          _revealed = false;
                        }),
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.event_outlined),
                label: Text(
                  _exam == null
                      ? 'Set exam horizon'
                      : 'Through ${_exam!.toLocal().toIso8601String().substring(0, 10)}',
                ),
                onPressed: _busy
                    ? null
                    : () async {
                        final day = await showDatePicker(
                          context: context,
                          initialDate: _exam?.toLocal() ?? DateTime.now(),
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 1),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 3650),
                          ),
                        );
                        if (day != null && mounted) {
                          setState(
                            () => _exam = DateTime(
                              day.year,
                              day.month,
                              day.day + 1,
                            ).toUtc().subtract(const Duration(microseconds: 1)),
                          );
                        }
                      },
              ),
              if (_exam != null)
                TextButton(
                  onPressed: () => setState(() => _exam = null),
                  child: const Text('Clear horizon'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_course != null)
            StudyResumePanel(
              key: ValueKey(widget.initialCourseId ?? _course),
              controller: c,
              course: widget.initialCourseId ?? _course!,
            ),
          Text(
            '${due.length} due now · ${upcoming.length} due ${_exam == null ? 'within 7 days' : 'before your exam'} · ${cards.where((o) => StudyCard(o).suspended).length} paused',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (i, label) in [
                (0, 'Review'),
                (1, 'Cards'),
                (2, 'Material'),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: _tab == i,
                  onSelected: _busy ? null : (_) => setState(() => _tab = i),
                ),
              OutlinedButton.icon(
                onPressed: readonly
                    ? null
                    : () async {
                        await showStudyCardEditor(
                          context,
                          c,
                          course: _course,
                          courseId: widget.initialCourseId,
                        );
                        if (mounted) setState(() {});
                      },
                icon: const Icon(Icons.add),
                label: const Text('New card'),
              ),
              OutlinedButton.icon(
                onPressed: _busy || (cards.isEmpty && unsupported == 0)
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        try {
                          final ok = await exportFile(
                            'orbit-study.json',
                            exportStudyCards(c.activeObjects.where(_matches)),
                          );
                          if (mounted) {
                            setState(
                              () => _message = ok
                                  ? 'Cards, sources and history exported.'
                                  : 'Export cancelled.',
                            );
                          }
                        } on Object catch (e) {
                          if (mounted) {
                            setState(() => _message = 'Export failed: $e');
                          }
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('Export cards'),
              ),
              if (c.canUndoPlanning)
                TextButton(
                  onPressed: readonly ? null : () => _run(c.undoPlanning),
                  child: const Text('Undo last change'),
                ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _review = null;
                        _revealed = false;
                        _message = null;
                      }),
                child: const Text('Refresh queue'),
              ),
            ],
          ),
          if (unsupported > 0)
            Text(
              '$unsupported card records need a newer version or format repair. Their Markdown and metadata remain intact and are included in export.',
            ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Semantics(liveRegion: true, child: Text(_message!)),
            ),
          if (_tab == 0) _reviewPanel(due, readonly),
          if (_tab != 0) ...[
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Find cards or material',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _filter = v),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 360,
              child: _tab == 1
                  ? _cardList(cards, readonly)
                  : _materialList(readonly),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _reviewPanel(List<UniversalObject> due, bool readonly) {
    _review ??= due.firstOrNull;
    final object = _review;
    if (object == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Text(
          'You’re caught up. Add a card from your material, or return when more cards are due.',
        ),
      );
    }
    final card = StudyCard(object);
    if (!_busy && !identical(c.find(object.id), object)) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'This card changed while you were reviewing. Refresh the queue before rating it.',
        ),
      );
    }
    final warning = c.studySourceWarning(object);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): () =>
            setState(() => _revealed = true),
        const SingleActivator(LogicalKeyboardKey.digit1): () =>
            _rate(StudyRating.again),
        const SingleActivator(LogicalKeyboardKey.digit2): () =>
            _rate(StudyRating.hard),
        const SingleActivator(LogicalKeyboardKey.digit3): () =>
            _rate(StudyRating.good),
        const SingleActivator(LogicalKeyboardKey.digit4): () =>
            _rate(StudyRating.easy),
      },
      child: Focus(
        autofocus: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectableText(
                object.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              if (_revealed) ...[
                MarkdownBody(
                  data: object.body,
                  selectable: true,
                  inlineSyntaxes: [MathInlineSyntax()],
                  blockSyntaxes: const [MathBlockSyntax(), MathTableSyntax()],
                  builders: {
                    'math-inline': MathElementBuilder(),
                    'math-block': MathElementBuilder(display: true),
                  },
                  imageBuilder: (uri, title, alt) =>
                      Text(alt ?? title ?? 'Image — open the source to view'),
                  styleSheet: MarkdownStyleSheet(
                    p: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                const SizedBox(height: 16),
                if (card.source != null) ...[
                  Text(
                    'Source: ${card.source!['title']}${card.source!['page'] == null ? '' : ' · page ${card.source!['page']}'}',
                  ),
                  if ((card.source!['passage'] as String).isNotEmpty)
                    ExpansionTile(
                      title: const Text('Captured passage'),
                      children: [
                        SelectableText(card.source!['passage'] as String),
                      ],
                    ),
                  if (warning != null)
                    Text(
                      warning,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  TextButton.icon(
                    onPressed: () {
                      if (c.openStudySource(object)) {
                        Navigator.pop(context);
                      } else {
                        setState(
                          () => _message =
                              'Source unavailable. The captured passage is retained.',
                        );
                      }
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open source'),
                  ),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final rating in StudyRating.values)
                      OutlinedButton(
                        onPressed: readonly || object.isReadOnly
                            ? null
                            : () => _rate(rating),
                        child: Text(
                          '${rating.name[0].toUpperCase()}${rating.name.substring(1)} · ${_intervalLabel(card, rating)}',
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Space reveals · 1 Again · 2 Hard · 3 Good · 4 Easy. Intervals follow a simple fixed rule; they are not a prediction of mastery.',
                ),
              ] else
                FilledButton(
                  onPressed: () => setState(() => _revealed = true),
                  child: const Text('Reveal answer'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _intervalLabel(StudyCard card, StudyRating rating) {
    try {
      final changed = card.reviewed(rating, DateTime.now());
      return rating == StudyRating.again
          ? '10 min'
          : '${changed['intervalDays']} days';
    } on FormatException {
      return 'review unavailable';
    }
  }

  Widget _cardList(List<UniversalObject> cards, bool readonly) {
    if (cards.isEmpty) {
      return const Center(child: Text('No cards in this subject yet.'));
    }
    return ListView.builder(
      itemCount: cards.length,
      itemBuilder: (context, i) {
        final o = cards[i];
        final card = StudyCard(o);
        return ListTile(
          title: Text(o.title),
          subtitle: Text(
            card.suspended ? 'Paused' : 'Due ${card.due.toLocal()}',
          ),
          onTap: () async {
            await showStudyCardEditor(context, c, card: o);
            if (mounted) {
              setState(() {
                _review = null;
                _revealed = false;
              });
            }
          },
          trailing: PopupMenuButton<String>(
            popUpAnimationStyle: OrbitMotionScope.popupStyle(context),
            enabled: !_busy,
            tooltip: 'Card actions',
            onSelected: (v) async {
              if (v == 'pause') {
                await _run(() => c.suspendStudyCard(o, !card.suspended));
                return;
              }
              if (v == 'open') {
                c.openObject(o.id);
                if (context.mounted) Navigator.pop(context);
                return;
              }
              if (v == 'history') {
                final history = card.history.reversed.toList();
                await showOrbitDialog<void>(
                  context: context,
                  builder: (_) => OrbitDialog(
                    title: const Text('Review history'),
                    content: history.isEmpty
                        ? const Text('No reviews yet.')
                        : SizedBox(
                            height: 320,
                            child: ListView.builder(
                              itemCount: history.length,
                              itemBuilder: (context, i) {
                                final h = history[i];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    '${h['at']} · ${h['rating']} · next ${h['due']}',
                                  ),
                                );
                              },
                            ),
                          ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'pause',
                enabled: !readonly && !o.isReadOnly,
                child: Text(
                  card.suspended ? 'Resume reviews' : 'Pause reviews',
                ),
              ),
              const PopupMenuItem(
                value: 'history',
                child: Text('Review history'),
              ),
              const PopupMenuItem(
                value: 'open',
                child: Text('Open Markdown note'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _materialList(bool readonly) {
    final material = c.activeObjects
        .where(
          (o) =>
              _matches(o) &&
              o.typeId == 'orbit.note' &&
              o.properties['studyCard'] == null,
        )
        .toList();
    if (material.isEmpty) {
      return const Center(
        child: Text('Create a lecture note or extract a PDF passage to start.'),
      );
    }
    return ListView.builder(
      itemCount: material.length,
      itemBuilder: (context, i) {
        final o = material[i];
        final pdf = o.properties['pdfSource'];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(o.title, style: Theme.of(context).textTheme.titleMedium),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final state in studyUnderstandingStates)
                    ChoiceChip(
                      label: Text(state),
                      selected: o.properties['studyUnderstanding'] == state,
                      onSelected: readonly
                          ? null
                          : (_) =>
                                _run(() => c.markStudyUnderstanding(o, state)),
                    ),
                  TextButton.icon(
                    onPressed: readonly
                        ? null
                        : () async {
                            final passage = pdf is Map && pdf['quote'] is String
                                ? pdf['quote'] as String
                                : o.body;
                            await showStudyCardEditor(
                              context,
                              c,
                              source: o,
                              passage: passage,
                              page: pdf is Map && pdf['page'] is int
                                  ? pdf['page'] as int
                                  : null,
                              course: _course,
                              courseId: widget.initialCourseId,
                            );
                            if (mounted) setState(() {});
                          },
                    icon: const Icon(Icons.style_outlined),
                    label: const Text('Make card'),
                  ),
                  TextButton(
                    onPressed: () {
                      c.openObject(o.id);
                      Navigator.pop(context);
                    },
                    child: const Text('Open note'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
