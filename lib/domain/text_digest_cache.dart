import 'dart:convert';
import 'package:crypto/crypto.dart';

/// A content-keyed single-document digest. Selection/caret changes need no new
/// UTF-8 buffer or SHA pass. No revision number can authorize a stale digest.
class TextDigestCache {
  String? _source, _hash;
  String hash(String source) {
    if (_source != source) {
      _hash = sha256.convert(utf8.encode(source)).toString();
      _source = source;
    }
    return _hash!;
  }

  void clear() => _source = _hash = null;
}
