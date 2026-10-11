import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/notes/read_attachment_preview.dart';

void main() {
  testWidgets('retryable attachment image reloads after a failed load', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ReadAttachmentImage(
          label: 'Attachments/figure.png',
          load: () async {
            attempts++;
            if (attempts == 1) return null;
            return Uint8List.fromList([1, 2, 3]);
          },
          builder: (bytes) => Text('loaded ${bytes.length} bytes'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Attachment missing: Attachments/figure.png'),
      findsOneWidget,
    );
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('loaded 3 bytes'), findsOneWidget);
    expect(attempts, 2);
  });

  testWidgets('read preview distinguishes a failed attachment read', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReadAttachmentImage(
          label: 'Attachments/broken.png',
          load: () async => throw StateError('vault temporarily unavailable'),
          builder: (bytes) => Text('loaded ${bytes.length} bytes'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Could not read attachment: Attachments/broken.png'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('read preview offers recovery when image decoding fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReadAttachmentImage(
          label: 'Attachments/corrupt.png',
          load: () async => Uint8List.fromList([1, 2, 3]),
          builder: (bytes) => Text('loaded ${bytes.length} bytes'),
          retryableBuilder: (bytes, retry) => Image.memory(
            bytes,
            errorBuilder: (_, _, _) => ReadAttachmentDecodeFailure(
              label: 'Attachments/corrupt.png',
              onRetry: retry,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Preview could not be decoded: Attachments/corrupt.png'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('attachment image reloads only when its revision changes', (
    tester,
  ) async {
    var attempts = 0;
    Widget image(int revision) => MaterialApp(
      home: ReadAttachmentImage(
        label: 'Attachments/figure.png',
        revision: revision,
        load: () async {
          attempts++;
          return Uint8List.fromList([revision]);
        },
        builder: (bytes) => Text('loaded ${bytes.single}'),
      ),
    );

    await tester.pumpWidget(image(0));
    await tester.pumpAndSettle();
    expect(find.text('loaded 0'), findsOneWidget);
    await tester.pumpWidget(image(0));
    await tester.pumpAndSettle();
    expect(attempts, 1);
    await tester.pumpWidget(image(1));
    await tester.pumpAndSettle();
    expect(find.text('loaded 1'), findsOneWidget);
    expect(attempts, 2);
  });

  testWidgets('attachment replacement reports its refresh state', (
    tester,
  ) async {
    final replacement = Completer<Uint8List?>();
    Widget image(int revision) => MaterialApp(
      home: ReadAttachmentImage(
        label: 'Attachments/figure.png',
        revision: revision,
        showReplacementStatus: true,
        load: () => revision == 0
            ? Future.value(Uint8List.fromList([0]))
            : replacement.future,
        builder: (bytes) => Text('loaded ${bytes.single}'),
      ),
    );

    await tester.pumpWidget(image(0));
    await tester.pumpAndSettle();
    await tester.pumpWidget(image(1));
    await tester.pump();
    expect(find.text('Refreshing preview…'), findsOneWidget);
    replacement.complete(Uint8List.fromList([1]));
    await tester.pumpAndSettle();
    expect(find.text('loaded 1'), findsOneWidget);
    expect(find.text('Preview updated · revision 1'), findsOneWidget);
  });

  testWidgets('details distinguish loaded bytes from recorded metadata', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReadAttachmentImage(
            label: 'Attachments/figure.png',
            title: 'Course diagram',
            mimeType: 'image/png',
            recordedByteLength: 10,
            load: () async => Uint8List.fromList([1, 2, 3]),
            builder: (_) => const Text('Preview'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Attachment details for Course diagram'));
    await tester.pumpAndSettle();
    expect(find.text('Type: image/png'), findsOneWidget);
    expect(find.text('Preview source: 3 bytes'), findsOneWidget);
    expect(find.text('Recorded size: 10 bytes'), findsOneWidget);
    expect(
      find.text('The loaded size differs from the recorded size.'),
      findsOneWidget,
    );
    expect(find.text('Attachments/figure.png'), findsOneWidget);
  });

  for (final fails in [false, true]) {
    testWidgets(
      'recovery actions remain available for ${fails ? 'read errors' : 'missing files'}',
      (tester) async {
        final actions = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReadAttachmentImage(
                label: 'Attachments/figure.png',
                title: 'Diagram',
                load: () async {
                  if (fails) throw StateError('unavailable');
                  return null;
                },
                builder: (_) => const Text('Preview'),
                onOpenOriginal: () => actions.add('open'),
                onReveal: () => actions.add('folder'),
                onCopyReference: () => actions.add('copy'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Open original Diagram'));
        await tester.tap(find.byTooltip('Show Diagram in folder'));
        await tester.tap(
          find.byTooltip('Copy attachment reference for Diagram'),
        );
        expect(actions, ['open', 'folder', 'copy']);
        await tester.tap(find.byTooltip('Attachment details for Diagram'));
        await tester.pumpAndSettle();
        expect(find.text('Type: Unknown'), findsOneWidget);
        expect(find.textContaining('Preview source:'), findsNothing);
        expect(find.textContaining('Recorded size:'), findsNothing);
      },
    );
  }

  testWidgets('decoder failure keeps original and folder actions', (
    tester,
  ) async {
    var opens = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReadAttachmentImage(
            label: 'Attachments/corrupt.png',
            title: 'Unreadable diagram',
            load: () async => Uint8List.fromList([1, 2, 3]),
            builder: (_) => const SizedBox.shrink(),
            retryableBuilder: (bytes, retry) => Image.memory(
              bytes,
              errorBuilder: (_, _, _) => ReadAttachmentDecodeFailure(
                label: 'Attachments/corrupt.png',
                onRetry: retry,
              ),
            ),
            onOpenOriginal: () => opens++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.byTooltip('Open original Unreadable diagram'));
    expect(opens, 1);
  });

  testWidgets('attachment controls wrap at narrow widths and large text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: SizedBox(
              width: 180,
              child: ReadAttachmentDetails(
                reference: 'Attachments/a-very-long-reference/figure.png',
                title: 'A long imported attachment title that needs to wrap',
                onOpenOriginal: () {},
                onReveal: () {},
                onCopyReference: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('authored image description is accessible and Enter opens it', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    String? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReadAttachmentPreview(
            uri: Uri.parse('../Attachments/diagram.png'),
            description: 'An overview of the game loop',
            onOpen: (path) => opened = path,
            child: const SizedBox(width: 120, height: 80),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(
        'An overview of the game loop. Open attachment ../Attachments/diagram.png',
      ),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(opened, '../Attachments/diagram.png');
    semantics.dispose();
  });

  testWidgets('a synchronous loader error uses the same recovery state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReadAttachmentImage(
          label: 'Attachments/failure.png',
          load: () => throw StateError('offline'),
          builder: (_) => const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Could not read attachment: Attachments/failure.png'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('recovery buttons do not activate the surrounding image link', (
    tester,
  ) async {
    var openedLink = 0, openedOriginal = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReadAttachmentPreview(
            uri: Uri.parse('../Attachments/diagram.png'),
            onOpen: (_) => openedLink++,
            child: ReadAttachmentImage(
              label: 'Attachments/diagram.png',
              title: 'Diagram',
              load: () async => null,
              builder: (_) => const SizedBox.shrink(),
              onOpenOriginal: () => openedOriginal++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open original Diagram'));
    expect(openedOriginal, 1);
    expect(openedLink, 0);
    await tester.tap(find.byTooltip('Attachment details for Diagram'));
    await tester.pumpAndSettle();
    expect(openedLink, 0);
  });

  testWidgets('remote images keep display-only behavior', (tester) async {
    var opens = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReadAttachmentPreview(
            uri: Uri.parse('https://example.test/diagram.png'),
            description: 'Remote diagram',
            onOpen: (_) => opens++,
            child: const Text('Remote preview'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Remote preview'));
    expect(opens, 0);
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('retry discards old bytes while a new read is pending', (
    tester,
  ) async {
    final next = Completer<Uint8List?>();
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReadAttachmentImage(
            label: 'Attachments/diagram.png',
            load: () => ++attempts == 1
                ? Future.value(Uint8List.fromList([1]))
                : next.future,
            builder: (_) => const SizedBox.shrink(),
            retryableBuilder: (bytes, retry) => TextButton(
              onPressed: retry,
              child: Text('Old bytes ${bytes.single}'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Old bytes 1'));
    await tester.pump();
    expect(find.text('Old bytes 1'), findsNothing);
    next.complete(null);
    await tester.pumpAndSettle();
    expect(
      find.text('Attachment missing: Attachments/diagram.png'),
      findsOneWidget,
    );
  });
}
