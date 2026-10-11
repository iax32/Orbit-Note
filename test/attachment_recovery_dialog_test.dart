import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/notes/attachment_recovery_dialog.dart';
import 'package:orbit_note/infrastructure/storage/workspace_store.dart';

void main() {
  final created = DateTime.utc(2026, 10, 8);

  UniversalObject objectWithHistory(int count) => UniversalObject(
    id: 'attachment-id',
    workspaceId: 'workspace-id',
    typeId: 'orbit.file',
    title: 'Research PDF',
    createdAt: created,
    updatedAt: created,
    properties: {
      'attachmentSourceHistory': [
        for (var index = 0; index < count; index++)
          {
            'originalName': 'source-$index.pdf',
            'contentRef': 'Attachments/source-$index.pdf',
            'recordedAt': created.toIso8601String(),
            'byteLength': index + 1,
          },
      ],
    },
  );

  Widget host(
    UniversalObject object, {
    Future<bool> Function()? onRestore,
    Future<bool> Function(
      AttachmentRecoveryProgress,
      AttachmentRecoveryCancellation,
    )?
    onRestoreCommand,
    MediaQueryData? mediaQuery,
    ThemeData? theme,
    List<WorkspaceAttachmentStageInfo> staged = const [],
  }) => MaterialApp(
    theme: theme,
    builder: (context, child) =>
        MediaQuery(data: mediaQuery ?? const MediaQueryData(), child: child!),
    home: AttachmentRecoveryDialog(
      staged: staged,
      object: object,
      reference: 'Attachments/missing.pdf',
      onRestoreOriginal:
          onRestoreCommand ??
          (_, _) => onRestore?.call() ?? Future.value(false),
      onRelink: (_, _) => Future.value(false),
      onRestoreVersion: (_, _, _) => Future.value(false),
      onOpen: (_) {},
      onForgetVersion: (_, _, _) => Future.value(false),
    ),
  );

  for (final size in [const Size(320, 640), const Size(568, 320)]) {
    testWidgets('large text recovery stays operable at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final pending = Completer<bool>();
      await tester.pumpWidget(
        host(
          objectWithHistory(17),
          onRestore: () => pending.future,
          mediaQuery: MediaQueryData(
            size: size,
            textScaler: const TextScaler.linear(2.5),
            highContrast: true,
            disableAnimations: true,
          ),
          staged: [
            WorkspaceAttachmentStageInfo(
              id: 'stage',
              operation: 'restore',
              target: 'Attachments/${'long-target-' * 15}.pdf',
              expectedHash: 'a' * 64,
              maxBytes: 10000000,
              length: 1234567,
              sourceName: 'Long source name ' * 15,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byTooltip('Next source history page'));
      await tester.tap(find.byTooltip('Next source history page'));
      await tester.pumpAndSettle();
      expect(find.text('Page 2 of 3'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('Locate original file'));
      await tester.tap(find.text('Locate original file'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Cancel verification').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Cancel verification'));
      await tester.pump();
      pending.complete(false);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('Forget retained source').first);
      await tester.tap(find.text('Forget retained source').first);
      await tester.pumpAndSettle();
      expect(find.text('Forget retained source?'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.text('Cancel').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Close').hitTestable(), findsOneWidget);
    });
  }

  testWidgets('font changes and keyboard insets preserve an active recovery', (
    tester,
  ) async {
    const size = Size(320, 640);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final pending = Completer<bool>();
    var started = 0;
    late AttachmentRecoveryProgress report;
    late AttachmentRecoveryCancellation isCancelled;
    final object = objectWithHistory(
      0,
    ).copyWith(title: 'Very long research document title ' * 12);
    Future<bool> restore(
      AttachmentRecoveryProgress progress,
      AttachmentRecoveryCancellation cancel,
    ) {
      started++;
      report = progress;
      isCancelled = cancel;
      return pending.future;
    }

    await tester.pumpWidget(host(object, onRestoreCommand: restore));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Locate original file'));
    await tester.tap(find.text('Locate original file'));
    await tester.pump();
    report(60, 100, 'Verifying retained source bytes safely ' * 8);
    await tester.pumpWidget(
      host(
        object,
        onRestoreCommand: restore,
        mediaQuery: const MediaQueryData(
          size: size,
          viewInsets: EdgeInsets.only(bottom: 240),
          textScaler: TextScaler.linear(3.2),
          disableAnimations: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(started, 1);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      0.6,
    );
    await tester.ensureVisible(find.byType(LinearProgressIndicator));
    expect(find.byType(LinearProgressIndicator).hitTestable(), findsOneWidget);
    expect(find.text('Cancel verification').hitTestable(), findsOneWidget);
    expect(
      tester.getRect(find.text('Cancel verification')).bottom,
      lessThanOrEqualTo(size.height - 240),
    );
    await tester.tap(find.text('Cancel verification'));
    await tester.pump();
    expect(isCancelled(), isTrue);
    pending.complete(false);
    await tester.pumpAndSettle();
    expect(find.text('Close').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('high contrast uses stronger boundaries and reduced motion', (
    tester,
  ) async {
    final completer = Completer<bool>();
    await tester.pumpWidget(
      host(
        objectWithHistory(0),
        onRestore: () => completer.future,
        mediaQuery: const MediaQueryData(
          highContrast: true,
          disableAnimations: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Locate original file'));
    await tester.pump();

    final progress = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(progress.minHeight, 6);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is TickerMode && !widget.enabled,
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Recovery in progress'), findsOneWidget);

    completer.complete(false);
    await tester.pumpAndSettle();
  });

  testWidgets('light, dark, and custom palettes keep recovery text readable', (
    tester,
  ) async {
    const customSurface = Color(0xFF777777);
    final themes = <ThemeData>[
      ThemeData.light(),
      ThemeData.dark(),
      ThemeData(
        colorScheme: const ColorScheme.light(
          surface: customSurface,
          onSurface: customSurface,
          onSurfaceVariant: customSurface,
          outline: customSurface,
          primary: customSurface,
        ),
      ),
    ];

    for (final theme in themes) {
      await tester.pumpWidget(host(objectWithHistory(0), theme: theme));
      await tester.pumpAndSettle();
      final dialogTheme = Theme.of(tester.element(find.text('Research PDF')));
      final surface = dialogTheme.colorScheme.surface;
      expect(
        OrbitContrast.ratio(dialogTheme.colorScheme.onSurface, surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        OrbitContrast.ratio(dialogTheme.colorScheme.onSurfaceVariant, surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        OrbitContrast.ratio(dialogTheme.colorScheme.outline, surface),
        greaterThanOrEqualTo(3),
      );
    }
  });

  testWidgets('retained history pagination exposes semantic controls', (
    tester,
  ) async {
    await tester.pumpWidget(host(objectWithHistory(17)));
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('Attachment recovery and source history'),
      findsOneWidget,
    );
    expect(find.text('Page 1 of 3'), findsOneWidget);
    expect(find.byTooltip('Previous source history page'), findsOneWidget);
    expect(find.byTooltip('Next source history page'), findsOneWidget);
    expect(find.text('source-16.pdf'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pump();
    expect(find.text('Page 2 of 3'), findsOneWidget);
    expect(find.text('source-8.pdf'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Next source history page'));
    await tester.tap(find.byTooltip('Next source history page'));
    await tester.pump();
    expect(find.text('Page 3 of 3'), findsOneWidget);
    expect(find.text('source-0.pdf'), findsOneWidget);
  });

  testWidgets('Escape requests cancellation and reports preserved sources', (
    tester,
  ) async {
    final completer = Completer<bool>();
    await tester.pumpWidget(
      host(objectWithHistory(0), onRestore: () => completer.future),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Locate original file'));
    await tester.pump();
    expect(find.text('Cancel verification'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(
      find.text('Cancellation requested. Preserving your sources…'),
      findsOneWidget,
    );
    expect(find.text('Cancelling…'), findsOneWidget);

    completer.complete(false);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Recovery cancelled. Your references and retained sources are preserved.',
      ),
      findsOneWidget,
    );
  });
}
