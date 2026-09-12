import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/domain/calendar_event.dart';
import 'package:orbit_note/domain/search_text.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MemoryStore store;
  late WorkspaceRepository repo;
  late ProviderContainer container;
  late WorkspaceController c;

  setUp(() async {
    store = MemoryStore();
    repo = WorkspaceRepository(store: store, index: MemoryObjectIndex());
    container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    container.read(workspaceProvider);
    c = container.read(workspaceProvider.notifier);
    for (var i = 0; i < 100 && c.loading; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
  });

  tearDown(() async {
    await c.flushAll();
    container.dispose();
  });

  group('Pinned Tabs & Drag-to-Reorder Clamping', () {
    test('pinning and unpinning moves tabs into pinned partition', () async {
      final n1 = (await c.create('orbit.note', title: 'Note 1'))!;
      final n2 = (await c.create('orbit.note', title: 'Note 2'))!;
      final n3 = (await c.create('orbit.note', title: 'Note 3'))!;
      final n4 = (await c.create('orbit.note', title: 'Note 4'))!;

      c.openObject(n1.id);
      c.openObject(n2.id);
      c.openObject(n3.id);
      c.openObject(n4.id);

      expect(c.session.tabs, equals([n1.id, n2.id, n3.id, n4.id]));
      expect(c.isPinned(n3.id), isFalse);

      // Pin Note 3
      c.pinTab(n3.id);
      expect(c.isPinned(n3.id), isTrue);
      expect(c.session.pinnedTabs, contains(n3.id));
      // Note 3 moved to the pinned section (index 0)
      expect(c.session.tabs.first, equals(n3.id));

      // Pin Note 1
      c.pinTab(n1.id);
      expect(c.isPinned(n1.id), isTrue);
      expect(c.session.pinnedTabs.length, equals(2));
      expect(c.session.tabs.take(2).toSet(), equals({n3.id, n1.id}));

      // Unpin Note 3
      c.unpinTab(n3.id);
      expect(c.isPinned(n3.id), isFalse);
      expect(c.session.pinnedTabs, equals([n1.id]));
      // Note 3 moved after pinned partition
      expect(c.session.tabs.indexOf(n3.id), greaterThanOrEqualTo(1));
    });

    test('closeOtherTabs and closeTabsToTheRight preserve pinned tabs', () async {
      final n1 = (await c.create('orbit.note', title: 'Note 1'))!;
      final n2 = (await c.create('orbit.note', title: 'Note 2'))!;
      final n3 = (await c.create('orbit.note', title: 'Note 3'))!;
      final n4 = (await c.create('orbit.note', title: 'Note 4'))!;

      c.openObject(n1.id);
      c.openObject(n2.id);
      c.openObject(n3.id);
      c.openObject(n4.id);

      c.pinTab(n1.id);
      expect(c.session.pinnedTabs, contains(n1.id));

      // Close other tabs relative to Note 3: Note 1 must stay because it is pinned!
      c.closeOtherTabs(n3.id);
      expect(c.session.tabs, contains(n1.id));
      expect(c.session.tabs, contains(n3.id));
      expect(c.session.tabs.contains(n2.id), isFalse);
      expect(c.session.tabs.contains(n4.id), isFalse);

      // Open Note 2 and Note 4 again
      c.openObject(n2.id);
      c.openObject(n4.id);

      // Note 1 is pinned at 0. Close tabs to the right of Note 1:
      // Note 1 remains, unpinned are closed
      c.closeTabsToTheRight(n1.id);
      expect(c.session.tabs, equals([n1.id]));
    });

    test('reorderTab clamps between pinned and unpinned partitions', () async {
      final n1 = (await c.create('orbit.note', title: 'Note 1'))!;
      final n2 = (await c.create('orbit.note', title: 'Note 2'))!;
      final n3 = (await c.create('orbit.note', title: 'Note 3'))!;

      c.openObject(n1.id);
      c.openObject(n2.id);
      c.openObject(n3.id);

      c.pinTab(n1.id);
      // Tabs: [n1.id] (pinned), [n2.id, n3.id] (unpinned)

      // Try to drag unpinned n3 (index 2) into pinned position 0
      c.reorderTab(2, 0);
      // Clamped so n3 cannot enter pinned partition (cannot go to index 0)
      expect(c.session.tabs[0], equals(n1.id));
      expect(c.isPinned(c.session.tabs[0]), isTrue);
    });
  });

  group('Reopen Closed Tab', () {
    test('maintains bounded stack and reopens recently closed tab', () async {
      final n1 = (await c.create('orbit.note', title: 'Note 1'))!;
      final n2 = (await c.create('orbit.note', title: 'Note 2'))!;
      final n3 = (await c.create('orbit.note', title: 'Note 3'))!;

      c.openObject(n1.id);
      c.openObject(n2.id);
      c.openObject(n3.id);

      // Close Note 2
      c.closeTab(n2.id);
      expect(c.session.tabs.contains(n2.id), isFalse);
      expect(c.session.closedTabs.contains(n2.id), isTrue);

      // Reopen
      c.reopenClosedTab();
      expect(c.session.tabs.contains(n2.id), isTrue);
      expect(c.session.closedTabs.contains(n2.id), isFalse);
    });

    test('reopenClosedTab skips deleted objects gracefully', () async {
      final n1 = (await c.create('orbit.note', title: 'Note 1'))!;
      final n2 = (await c.create('orbit.note', title: 'Note 2'))!;

      c.openObject(n1.id);
      c.openObject(n2.id);

      c.closeTab(n2.id);
      expect(c.session.closedTabs.contains(n2.id), isTrue);

      // Trash n2
      await c.trash(n2.id);

      // Reopening should skip deleted n2 without throwing
      c.reopenClosedTab();
      expect(c.session.tabs.contains(n2.id), isFalse);
    });
  });

  group('Navigation History', () {
    test('back and forward history traversal', () async {
      final n1 = (await c.create('orbit.note', title: 'Note 1'))!;
      final n2 = (await c.create('orbit.note', title: 'Note 2'))!;
      final n3 = (await c.create('orbit.note', title: 'Note 3'))!;

      // create() automatically opens created objects in sequence: n1 -> n2 -> n3
      expect(c.session.activeId, equals(n3.id));
      expect(c.canNavigateBack, isTrue);
      expect(c.canNavigateForward, isFalse);

      // Navigate back to Note 2
      c.navigateBack();
      expect(c.session.activeId, equals(n2.id));
      expect(c.canNavigateBack, isTrue);
      expect(c.canNavigateForward, isTrue);

      // Navigate back to Note 1
      c.navigateBack();
      expect(c.session.activeId, equals(n1.id));
      expect(c.canNavigateBack, isFalse);
      expect(c.canNavigateForward, isTrue);

      // Navigate forward to Note 2
      c.navigateForward();
      expect(c.session.activeId, equals(n2.id));
      expect(c.canNavigateBack, isTrue);
      expect(c.canNavigateForward, isTrue);

      // Navigate forward to Note 3
      c.navigateForward();
      expect(c.session.activeId, equals(n3.id));
      expect(c.canNavigateBack, isTrue);
      expect(c.canNavigateForward, isFalse);
    });
  });

  group('Universal Search Context Snippets', () {
    test('cleanMarkdownNoise removes markdown syntax', () {
      const md =
          '# Title\n\nThis is **bold** and *italic* with [[WikiLink]] and `code`.';
      final cleaned = cleanMarkdownNoise(md);
      expect(cleaned, isNot(contains('#')));
      expect(cleaned, isNot(contains('**')));
      expect(cleaned, isNot(contains('[[')));
      expect(cleaned, isNot(contains(']]')));
      expect(cleaned, isNot(contains('`')));
      expect(cleaned, contains('bold and italic with WikiLink and code.'));
    });

    test('extractSearchSnippet extracts matching context from note body', () {
      final note = UniversalObject(
        id: 'n-search-1',
        workspaceId: 'ws',
        typeId: 'orbit.note',
        title: 'Project Architecture',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        body:
            'The database uses SQLite alongside durable Markdown files. Offline first architecture guarantees privacy.',
      );

      final snippet = extractSearchSnippet(note, 'sqlite');
      expect(snippet, isNotNull);
      expect(
        snippet!.text
            .substring(
              snippet.matchStart,
              snippet.matchStart + snippet.matchLength,
            )
            .toLowerCase(),
        equals('sqlite'),
      );
      expect(snippet.text, contains('SQLite'));
      expect(snippet.source, equals('body'));
    });

    test('extractSearchSnippet matches canvas element content', () {
      final canvas = UniversalObject(
        id: 'c-search-1',
        workspaceId: 'ws',
        typeId: 'orbit.canvas',
        title: 'Mindmap',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        body:
            '{"elements":[{"id":"el-1","type":"sticky","text":"Remember to deploy with zero downtime"}]}',
      );

      final snippet = extractSearchSnippet(canvas, 'deploy');
      expect(snippet, isNotNull);
      expect(
        snippet!.text
            .substring(
              snippet.matchStart,
              snippet.matchStart + snippet.matchLength,
            )
            .toLowerCase(),
        equals('deploy'),
      );
      expect(snippet.source, equals('canvas'));
    });

    test('extractSearchSnippet matches property values', () {
      final task = UniversalObject(
        id: 't-search-1',
        workspaceId: 'ws',
        typeId: 'orbit.task',
        title: 'Fix issue',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        body: 'Some notes',
        properties: const {'assignee': 'Alex Rivera', 'priority': 'high'},
      );

      final snippet = extractSearchSnippet(task, 'Alex Rivera');
      expect(snippet, isNotNull);
      expect(
        snippet!.text.substring(
          snippet.matchStart,
          snippet.matchStart + snippet.matchLength,
        ),
        equals('Alex Rivera'),
      );
      expect(snippet.source, equals('property'));
    });
  });

  group('Daily Note', () {
    test(
      'openTodayNote creates dated note with header and dailyDate property',
      () async {
        final todayStr = calendarDate(DateTime.now());

        await c.openTodayNote();

        final todayNote = c.activeObjects.firstWhere(
          (o) => o.title == todayStr,
        );
        expect(todayNote.properties['dailyDate'], equals(todayStr));
        expect(todayNote.body, startsWith('# '));

        // Calling again opens the existing note without duplicating
        final countBefore = c.activeObjects.length;
        await c.openTodayNote();
        expect(c.activeObjects.length, equals(countBefore));
        expect(c.session.activeId, equals(todayNote.id));
      },
    );
  });

  group('Canvas Distribute Evenly', () {
    test('horizontal distribution creates equal gaps', () {
      final el1 = CanvasElement({
        'id': 'e1',
        'type': 'rectangle',
        'x': 0.0,
        'y': 0.0,
        'width': 20.0,
        'height': 20.0,
      });
      final el2 = CanvasElement({
        'id': 'e2',
        'type': 'rectangle',
        'x': 10.0,
        'y': 0.0,
        'width': 20.0,
        'height': 20.0,
      });
      final el3 = CanvasElement({
        'id': 'e3',
        'type': 'rectangle',
        'x': 100.0,
        'y': 0.0,
        'width': 20.0,
        'height': 20.0,
      });

      final sorted = [el1, el2, el3]
        ..sort((a, b) => a.bounds.left.compareTo(b.bounds.left));
      final minL = sorted.first.bounds.left;
      final maxR = sorted.last.bounds.right;
      final totalWidth = sorted.fold<double>(
        0.0,
        (sum, e) => sum + e.bounds.width,
      );
      final gap = (maxR - minL - totalWidth) / (sorted.length - 1);

      // minL = 0, maxR = 120, totalWidth = 60, gap = (120 - 0 - 60) / 2 = 30
      expect(gap, equals(30.0));

      final positions = <double>[];
      var curX = minL;
      for (final e in sorted) {
        positions.add(curX);
        curX += e.bounds.width + gap;
      }
      expect(positions, equals([0.0, 50.0, 100.0]));
    });

    test('vertical distribution creates equal gaps', () {
      final el1 = CanvasElement({
        'id': 'e1',
        'type': 'rectangle',
        'x': 0.0,
        'y': 0.0,
        'width': 20.0,
        'height': 30.0,
      });
      final el2 = CanvasElement({
        'id': 'e2',
        'type': 'rectangle',
        'x': 0.0,
        'y': 20.0,
        'width': 20.0,
        'height': 30.0,
      });
      final el3 = CanvasElement({
        'id': 'e3',
        'type': 'rectangle',
        'x': 0.0,
        'y': 150.0,
        'width': 20.0,
        'height': 30.0,
      });

      final sorted = [el1, el2, el3]
        ..sort((a, b) => a.bounds.top.compareTo(b.bounds.top));
      final minT = sorted.first.bounds.top;
      final maxB = sorted.last.bounds.bottom;
      final totalHeight = sorted.fold<double>(
        0.0,
        (sum, e) => sum + e.bounds.height,
      );
      final gap = (maxB - minT - totalHeight) / (sorted.length - 1);

      // minT = 0, maxB = 180, totalHeight = 90, gap = (180 - 0 - 90) / 2 = 45
      expect(gap, equals(45.0));

      final positions = <double>[];
      var curY = minT;
      for (final e in sorted) {
        positions.add(curY);
        curY += e.bounds.height + gap;
      }
      expect(positions, equals([0.0, 75.0, 150.0]));
    });
  });

  group('Canvas Minimap & Snap Guides', () {
    test('CanvasMinimapPainter layout calculation', () {
      final scene = CanvasScene.fromJson({
        'schemaVersion': 1,
        'elements': [
          {
            'id': 'e1',
            'type': 'rectangle',
            'x': 0.0,
            'y': 0.0,
            'width': 200.0,
            'height': 100.0,
          },
        ],
      });
      const camera = CanvasCamera(x: 0, y: 0, zoom: 1.0);
      const viewportSize = Size(800, 600);
      const minimapSize = Size(160, 110);

      final (contentRect, scale, offsetX, offsetY) =
          CanvasMinimapPainter.layout(scene, camera, viewportSize, minimapSize);

      expect(scale, greaterThan(0));
      expect(contentRect.width, greaterThan(0));
      expect(offsetX, greaterThanOrEqualTo(0));
      expect(offsetY, greaterThanOrEqualTo(0));
    });

    test('CanvasGuideLine equality and hashCode', () {
      const g1 = CanvasGuideLine(isVertical: true, position: 150.0);
      const g2 = CanvasGuideLine(isVertical: true, position: 150.0);
      const g3 = CanvasGuideLine(isVertical: false, position: 150.0);

      expect(g1, equals(g2));
      expect(g1.hashCode, equals(g2.hashCode));
      expect(g1, isNot(equals(g3)));
    });
  });

  group('Home Local Dashboard Task Filtering', () {
    test('separates today, overdue, and upcoming tasks correctly', () {
      final now = DateTime(2026, 9, 12);
      final todayDate = calendarDate(now);
      final yesterdayDate = calendarDate(now.subtract(const Duration(days: 1)));
      final tomorrowDate = calendarDate(now.add(const Duration(days: 1)));

      expect(
        isDueDateOverdue(parseCalendarDate(yesterdayDate), now: now),
        isTrue,
      );
      expect(isDueDateOverdue(parseCalendarDate(todayDate), now: now), isFalse);
      expect(
        isDueDateOverdue(parseCalendarDate(tomorrowDate), now: now),
        isFalse,
      );

      expect(calendarDate(parseCalendarDate(todayDate)!), equals(todayDate));
      expect(
        formatFriendlyDueDate(parseCalendarDate(todayDate), now: now),
        equals('Today'),
      );
      expect(
        formatFriendlyDueDate(parseCalendarDate(tomorrowDate), now: now),
        equals('Tomorrow'),
      );
      expect(
        formatFriendlyDueDate(parseCalendarDate(yesterdayDate), now: now),
        equals('Yesterday'),
      );
    });
  });
}
