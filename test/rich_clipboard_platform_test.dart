import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/notes/rich/rich_clipboard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('orbit_note/clipboard');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final plainWrites = <String>[];

  setUp(() {
    plainWrites.clear();
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        plainWrites.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test('native rich copy preserves Unicode and both representations', () async {
    const plain = 'Course\t数学 👩‍💻\r\nα\t&';
    const html = '<table><tr><td>数学 👩‍💻 &amp; α</td></tr></table>';
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'setRichText');
      expect(call.arguments, {'plainText': plain, 'html': html});
      return true;
    });
    expect(await writeRichClipboard(plainText: plain, html: html), isTrue);
    expect(plainWrites, isEmpty);
  });

  for (final failure in [
    'rejected',
    'missing',
    'platform-error',
    'bad-result',
  ]) {
    test('$failure rich bridge uses exact plain fallback', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        switch (failure) {
          case 'missing':
            throw MissingPluginException();
          case 'platform-error':
            throw PlatformException(code: 'clipboard_unavailable');
          case 'bad-result':
            return 'wrong-type';
          default:
            return false;
        }
      });
      expect(
        await writeRichClipboard(plainText: 'α\tβ\r\nγ', html: '<table/>'),
        isTrue,
      );
      expect(plainWrites, ['α\tβ\r\nγ']);
    });
  }

  test('failure in both paths is recoverable', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => false);
    messenger.setMockMethodCallHandler(SystemChannels.platform, (_) async {
      throw PlatformException(code: 'clipboard_busy');
    });
    expect(
      await writeRichClipboard(
        plainText: 'Keep this note',
        html: '<p>Keep this note</p>',
      ),
      isFalse,
    );
  });
}
