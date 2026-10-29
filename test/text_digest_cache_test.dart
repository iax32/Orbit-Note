import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/domain/text_digest_cache.dart';

void main() {
  test(
    'caret-only work reuses a digest; same-length edits and session reset remain exact',
    () {
      final cache = TextDigestCache();
      final source = 'text α 😀\r\n' * 10000;
      final first = cache.hash(source);
      for (var i = 0; i < 100; i++) {
        expect(identical(cache.hash(source), first), isTrue);
      }
      final edited = source.replaceFirst('text', 'edit');
      expect(
        cache.hash(edited),
        sha256.convert(utf8.encode(edited)).toString(),
      );
      expect(cache.hash(edited), isNot(first));
      cache.clear();
      expect(cache.hash(''), sha256.convert(const <int>[]).toString());
    },
  );
}
