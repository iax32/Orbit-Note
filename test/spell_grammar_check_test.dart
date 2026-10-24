import 'support/settings_navigation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/session_state.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/grammar/spell_grammar_engine.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/workspace/workspace_views.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

void main() {
  group('EnglishSpellGrammarEngine unit tests', () {
    late EnglishSpellGrammarEngine engine;

    setUp(() {
      engine = EnglishSpellGrammarEngine();
    });

    test('validates correct words without issues', () {
      final issues = engine.analyze(
        'The quick brown fox jumps over the lazy dog.',
      );
      expect(issues, isEmpty);
    });

    test('does not underline ordinary note prose as spelling errors', () {
      final issues = engine.analyze(
        'This is a normal sentence with everything working. '
        'The grammar correction highlight is not working here. '
        'I am writing a note about my project.',
      );
      expect(issues, isEmpty);
    });

    test('detects typos and suggests corrections', () {
      final issues = engine.analyze('I recieve teh package definately.');
      expect(issues.length, greaterThanOrEqualTo(3));

      final recieve = issues.firstWhere((i) => i.originalText == 'recieve');
      expect(recieve.type, IssueType.spelling);
      expect(recieve.suggestions, contains('receive'));

      final teh = issues.firstWhere((i) => i.originalText == 'teh');
      expect(teh.type, IssueType.spelling);
      expect(teh.suggestions, contains('the'));

      final definately = issues.firstWhere(
        (i) => i.originalText == 'definately',
      );
      expect(definately.type, IssueType.spelling);
      expect(definately.suggestions, contains('definitely'));
    });

    test('grammar rule: repeated words', () {
      final issues = engine.analyze('This is the the best idea.');
      final repeated = issues.firstWhere((i) => i.originalText == 'the the');
      expect(repeated.type, IssueType.grammar);
      expect(repeated.suggestions, contains('the'));
    });

    test('grammar rule: indefinite article a/an agreement', () {
      final aApple = engine.analyze('I ate a apple yesterday.');
      expect(
        aApple.any(
          (i) =>
              i.originalText == 'a apple' && i.suggestions.contains('an apple'),
        ),
        isTrue,
      );

      final anBanana = engine.analyze('He bought an banana today.');
      expect(
        anBanana.any(
          (i) =>
              i.originalText == 'an banana' &&
              i.suggestions.contains('a banana'),
        ),
        isTrue,
      );
    });

    test('grammar rule: homophone confusions', () {
      final couldOf = engine.analyze('You could of told me.');
      expect(
        couldOf.any(
          (i) =>
              i.originalText == 'could of' &&
              i.suggestions.contains('could have'),
        ),
        isTrue,
      );

      final yourWelcome = engine.analyze('Thank you! your welcome.');
      expect(
        yourWelcome.any((i) => i.originalText.toLowerCase() == 'your welcome'),
        isTrue,
      );
    });

    test('grammar rule: subject-verb agreement', () {
      final theyIs = engine.analyze('They is very happy.');
      expect(
        theyIs.any(
          (i) =>
              i.originalText == 'They is' && i.suggestions.contains('They are'),
        ),
        isTrue,
      );

      final heAre = engine.analyze('He are working today.');
      expect(
        heAre.any(
          (i) => i.originalText == 'He are' && i.suggestions.contains('He is'),
        ),
        isTrue,
      );
    });

    test('grammar rule: standalone pronoun i capitalization', () {
      final iThink = engine.analyze('Well, i think so.');
      expect(
        iThink.any((i) => i.originalText == 'i' && i.suggestions.contains('I')),
        isTrue,
      );
    });

    test('user dictionary suppresses unknown words', () {
      const customWord = 'recieve';
      final before = engine.analyze('I recieve the package.');
      expect(before.any((i) => i.originalText == customWord), isTrue);

      engine.addWord(customWord);
      final after = engine.analyze('I recieve the package.');
      expect(after.any((i) => i.originalText == customWord), isFalse);
    });

    test('session ignore suppresses word', () {
      const rareWord = 'definately';
      final before = engine.analyze('I definately agree.');
      expect(before.any((i) => i.originalText == rareWord), isTrue);

      engine.ignoreWord(rareWord);
      final after = engine.analyze('I definately agree.');
      expect(after.any((i) => i.originalText == rareWord), isFalse);
    });

    test('exclusion masks protect code, math, urls, wikilinks', () {
      final text = '''
Check out `const x = recieve` and:
```dart
void foobar() {
  teh(definately);
}
```
Math: \$a_i + b_j = c_k\$ and \$\$\\frac{foo}{bar}\$\$
Link: https://example.com/recieve
Wiki: [[teh_note|Custom Title]]
''';
      final issues = engine.analyze(text);
      expect(issues, isEmpty);
    });
  });

  group('NoteEditor spell check integration', () {
    testWidgets('renders spellcheck toggle and responds to clicks', (
      tester,
    ) async {
      var toggled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditor(
              noteId: 'n1',
              title: 'Test Note',
              body: 'Hello world',
              onTitleChanged: (_) {},
              onBodyChanged: (_) {},
              linkTargets: const [],
              onOpenObject: (_) {},
              spellCheckEnabled: true,
              onToggleSpellCheck: () => toggled = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final toggleFinder = find.byKey(const ValueKey('note-spellcheck-toggle'));
      expect(toggleFinder, findsOneWidget);

      await tester.tap(toggleFinder);
      await tester.pump();
      expect(toggled, isTrue);
    });

    testWidgets('SessionState serializes and deserializes spellCheck fields', (
      tester,
    ) async {
      final state = SessionState(
        spellCheckEnabled: false,
        userDictionary: ['CustomWord1', 'CustomWord2'],
      );
      final json = state.toJson();
      expect(json['spellCheckEnabled'], isFalse);
      expect(json['userDictionary'], ['CustomWord1', 'CustomWord2']);

      final restored = SessionState.fromJson(json);
      expect(restored.spellCheckEnabled, isFalse);
      expect(restored.userDictionary, ['CustomWord1', 'CustomWord2']);
    });

    testWidgets(
      'right click context menu offers fix suggestions and updates text',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        String currentTitle = 'teh title';
        final addedWords = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NoteEditor(
                noteId: 'n1',
                title: currentTitle,
                body: 'content',
                onTitleChanged: (v) => currentTitle = v,
                onBodyChanged: (_) {},
                linkTargets: const [],
                onOpenObject: (_) {},
                spellCheckEnabled: true,
                onAddToUserDictionary: (w) => addedWords.add(w),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final titleFinder = find.byKey(const ValueKey('note-title'));
        expect(titleFinder, findsOneWidget);

        // Place caret in the misspelled word "teh" and right-click
        final gesture = await tester.startGesture(
          tester.getTopLeft(titleFinder) + const Offset(10, 10),
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
        await gesture.up();
        await tester.pumpAndSettle();

        // Verify custom context menu items appear
        expect(find.text('Replace with: "the"'), findsOneWidget);
        expect(
          find.text('Add "teh" to Dictionary', skipOffstage: false),
          findsOneWidget,
        );
        expect(find.text('Ignore "teh"', skipOffstage: false), findsOneWidget);

        // Tap the fix button
        await tester.tap(find.text('Replace with: "the"'));
        await tester.pumpAndSettle();

        expect(currentTitle, 'the title');
      },
    );

    testWidgets('SettingsView toggles spell check and clears user dictionary', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final store = MemoryStore();
        final repo = WorkspaceRepository(
          store: store,
          index: MemoryObjectIndex(),
        );
        final container = ProviderContainer(
          overrides: [repositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);
        final controller = container.read(workspaceProvider.notifier);
        for (var i = 0; i < 100 && controller.loading; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 2));
        }

        controller.updateSession((s) {
          s.spellCheckEnabled = true;
          s.userDictionary = ['CustomWord'];
        });

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: SettingsView(
                  controller: controller,
                  onExport: () {},
                  onImport: () {},
                  onOpenWorkspace: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        await searchSettings(tester, 'Spelling');
        expect(
          find.byKey(const ValueKey('settings-spellcheck-switch')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('settings-clear-dictionary-button')),
          findsOneWidget,
        );

        await tester.ensureVisible(
          find.byKey(const ValueKey('settings-clear-dictionary-button')),
        );
        await tester.tap(
          find.byKey(const ValueKey('settings-clear-dictionary-button')),
        );
        await tester.pump();

        await tester.tap(find.text('Clear words'));
        await tester.pump(const Duration(milliseconds: 350));

        expect(controller.session.userDictionary, isEmpty);
      });
    });
  });
}
