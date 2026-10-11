// Ephemeral native UI review. Uses an in-memory vault and never opens user data.
// F1 Home, F2 Note, F3 Canvas, F4 Tasks, F5 Calendar, F6 Settings, F7 Inspector.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_note/app/orbit_app.dart';
import 'package:orbit_note/app/session_state.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import '../test/support/memory_store.dart';
import '../test/support/pdf_fixture.dart';
import 'package:orbit_note/features/notes/latex/latex_templates.dart';
import 'package:orbit_note/domain/search_workspace.dart';
import 'package:orbit_note/features/notes/note_editor.dart';

const _markdownReview = bool.fromEnvironment('ORBIT_REVIEW_MARKDOWN');
const _editingSample = '''# Native editing check

**Alpha beta** keeps its formatting.

Second paragraph stays separate.

Same

Middle

Same

```text
code stays here
```

After code.
''';
final _compositionStatus = ValueNotifier(
  'Temporary review · F8 compose · F9 commit · F10 cancel · F12 reset',
);
TextEditingController? _compositionController;
TextEditingValue? _compositionOriginal;

EditableTextState? _focusedEditor() => FocusManager
    .instance
    .primaryFocus
    ?.context
    ?.findAncestorStateOfType<EditableTextState>();
void _describeComposition() {
  final value = _compositionController?.value;
  if (value == null) return;
  _compositionStatus.value =
      'Temporary review · controlled composition ${value.composing.isCollapsed ? 'inactive' : '${value.composing.start}–${value.composing.end}'} · caret ${value.selection.extentOffset}';
}

// Controlled Flutter input-client events, not a claim of OS IME acceptance.
void _beginComposition() {
  final editor = _focusedEditor();
  if (editor == null) {
    _compositionStatus.value = 'Focus a text field, then press F8.';
    return;
  }
  _compositionController?.removeListener(_describeComposition);
  _compositionController = editor.widget.controller;
  _compositionOriginal = _compositionController!.value;
  _compositionController!.addListener(_describeComposition);
  final value = _compositionOriginal!;
  final selection = value.selection.isValid
      ? value.selection
      : TextSelection.collapsed(offset: value.text.length);
  TextInput.updateEditingValue(
    TextEditingValue(
      text: value.text.replaceRange(selection.start, selection.end, 'かな'),
      selection: TextSelection.collapsed(offset: selection.start + 2),
      composing: TextRange(start: selection.start, end: selection.start + 2),
    ),
  );
  _describeComposition();
}

void _finishComposition({bool cancel = false}) {
  final editor = _focusedEditor();
  if (editor == null ||
      !identical(editor.widget.controller, _compositionController)) {
    _compositionStatus.value = 'Focus the composing field to commit or cancel.';
    return;
  }
  final value = cancel ? _compositionOriginal! : editor.widget.controller.value;
  TextInput.updateEditingValue(value.copyWith(composing: TextRange.empty));
  _describeComposition();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_markdownReview) {
    runApp(const _MarkdownReview());
    return;
  }
  final repo = WorkspaceRepository(
    store: MemoryStore(),
    index: MemoryObjectIndex(),
  );
  final container = ProviderContainer(
    overrides: [repositoryProvider.overrideWithValue(repo)],
  );
  container.read(workspaceProvider);
  final c = container.read(workspaceProvider.notifier);
  while (c.loading) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  if (const bool.fromEnvironment('ORBIT_REVIEW_EMPTY')) {
    c.updateSession((s) {
      s.spellCheckEnabled = false;
      s.motion = 'reduced';
    });
    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const OrbitNoteApp(),
      ),
    );
    return;
  }
  final note = (await c.create(
    'orbit.note',
    title: 'Linear algebra · lecture notes',
  ))!;
  c.edit(
    note.id,
    body: r'''# Eigenvectors and transformations

A matrix transforms a vector. An eigenvector keeps its direction.

## The central relationship

$$
A\mathbf{v}=\lambda\mathbf{v}
$$

The scalar $\lambda$ tells us how much the vector stretches.

- Review the geometric interpretation
- Work through the diagonal matrix example
- [ ] Connect this to the reading notes

> Keep the calculation beside the explanation.
''',
  );
  final board = (await c.create(
    'orbit.canvas',
    title: 'Study board · transformations',
  ))!;
  c.edit(
    board.id,
    data: {
      'schemaVersion': 1,
      'elements': [
        {
          'id': 'lecture',
          'type': 'card',
          'objectId': note.id,
          'x': 60.0,
          'y': 80.0,
          'width': 290.0,
          'height': 260.0,
        },
        for (var i = 0; i < 6; i++)
          {
            'id': 'idea-$i',
            'type': 'sticky',
            'text': [
              'Eigenvectors\n\nDirection stays the same.',
              'Eigenvalues\n\nScale along each direction.',
              'Diagonalization\n\nChoose a useful basis.',
            ][i % 3],
            'x': 400.0 + (i % 3) * 260,
            'y': 80.0 + (i ~/ 3) * 250,
            'width': 230.0,
            'height': 190.0,
            'color': i.isEven ? 0xff6f7fea : 0xff8b7cf6,
          },
      ],
    },
  );
  await c.placeNoteBlock(
    note.id,
    c.find(note.id)!.body.indexOf('A matrix'),
    board.id,
  );
  await c.create(
    'orbit.task',
    title: 'Work through the eigenvector exercises',
    properties: {'dueDate': DateTime.now().toIso8601String().substring(0, 10)},
  );
  await c.create(
    'orbit.event',
    title: 'Linear algebra seminar',
    properties: {
      'allDay': false,
      'startAt': DateTime.now()
          .toUtc()
          .add(const Duration(days: 1))
          .toIso8601String(),
      'endAt': DateTime.now()
          .toUtc()
          .add(const Duration(days: 1, hours: 1))
          .toIso8601String(),
    },
  );
  final pdf = await repo.importAttachment(
    name: 'Reading sample.pdf',
    bytes: researchPdf(illustrated: true),
  );
  await c.refresh();
  c.updateProperty(pdf.id, 'pageCount', 2);
  c.updateProperty(pdf.id, 'lastReadPage', 1);
  for (final title in [
    'Linear algebra · course reader.pdf',
    'Research methods · field notes.pdf',
  ]) {
    await repo.importAttachment(
      name: title,
      bytes: researchPdf(illustrated: true),
    );
  }
  await c.refresh();
  final latex = (await c.create(
    'orbit.note',
    title: 'Academic document',
    body: LatexTemplates.blank.body,
    properties: {'documentFormat': 'latex'},
  ))!;
  final project = (await c.create(
    'orbit.view',
    title: 'Linear algebra project',
    properties: {'viewType': 'project', 'project': 'Linear algebra'},
  ))!;
  await c.flushAll();
  c.navigate(OrbitDestination.home);
  c.updateSession((s) {
    s.spellCheckEnabled = false;
    s.motion = 'reduced';
    if (const bool.fromEnvironment('ORBIT_REVIEW_SEARCH')) {
      s.destination = OrbitDestination.search;
      s.searchWorkspace = const SearchLibrary(
        {},
      ).save(const SavedSearch('Eigenvectors', 'eigenvector', SearchOptions()));
    }
  });
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.f1): () =>
              c.navigate(OrbitDestination.home),
          const SingleActivator(LogicalKeyboardKey.f2): () =>
              c.openObject(note.id),
          const SingleActivator(LogicalKeyboardKey.f3): () =>
              c.openObject(board.id),
          const SingleActivator(LogicalKeyboardKey.f4): () =>
              c.navigate(OrbitDestination.tasks),
          const SingleActivator(LogicalKeyboardKey.f5): () =>
              c.navigate(OrbitDestination.calendar),
          const SingleActivator(LogicalKeyboardKey.f6): () =>
              c.navigate(OrbitDestination.settings),
          const SingleActivator(LogicalKeyboardKey.f7): () {
            c.openObject(note.id);
            c.updateSession((s) => s.inspectorVisible = true);
          },
          const SingleActivator(LogicalKeyboardKey.f8): () =>
              c.navigate(OrbitDestination.graph),
          const SingleActivator(LogicalKeyboardKey.f9): () =>
              c.openObject(pdf.id),
          const SingleActivator(LogicalKeyboardKey.f11): () =>
              c.navigate(OrbitDestination.search),
          const SingleActivator(LogicalKeyboardKey.f12): () =>
              c.openObject(project.id),
          const SingleActivator(LogicalKeyboardKey.f10): () =>
              c.openObject(latex.id),
        },
        child: const OrbitNoteApp(),
      ),
    ),
  );
}

class _MarkdownReview extends StatefulWidget {
  const _MarkdownReview();

  @override
  State<_MarkdownReview> createState() => _MarkdownReviewState();
}

class _MarkdownReviewState extends State<_MarkdownReview> {
  String body = _editingSample;
  int revision = 0;

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    home: CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f8): _beginComposition,
        const SingleActivator(LogicalKeyboardKey.f9): _finishComposition,
        const SingleActivator(LogicalKeyboardKey.f10): () =>
            _finishComposition(cancel: true),
        const SingleActivator(LogicalKeyboardKey.f12): () => setState(() {
          _compositionController?.removeListener(_describeComposition);
          _compositionController = null;
          _compositionOriginal = null;
          body = _editingSample;
          revision++;
        }),
      },
      child: Scaffold(
        body: NoteEditor(
          key: ValueKey(revision),
          noteId: 'native-sample',
          title: 'Editing checks · temporary sample',
          body: body,
          onTitleChanged: (_) {},
          onBodyChanged: (value) => setState(() => body = value),
          linkTargets: const [],
          onOpenObject: (_) {},
        ),
        bottomNavigationBar: ValueListenableBuilder(
          valueListenable: _compositionStatus,
          builder: (context, status, _) =>
              Padding(padding: const EdgeInsets.all(8), child: Text(status)),
        ),
      ),
    ),
  );
}
