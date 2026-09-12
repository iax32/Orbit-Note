import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:web/web.dart' as web;

import '../../domain/workspace_failure.dart';
import 'path_safety.dart';
import 'workspace_store.dart';

WorkspaceStore createWorkspaceStore() => BrowserWorkspaceStore();

/// A browser-only compatibility adapter. Clearing site data removes this store;
/// callers must identify its limits and make a portable export available.
class BrowserWorkspaceStore implements WorkspaceStore {
  static const _prefix = 'orbit-note.workspace.v1/';
  @override
  bool get isBrowser => true;
  @override
  String get location => 'Browser storage on this device';
  @override
  Future<void> initialize({String? path}) async {
    if (path != null) {
      throw const WorkspaceFailure(
        'Opening an operating-system folder requires the desktop app.',
      );
    }
  }

  @override
  Future<List<String>> listFiles() async {
    final store = web.window.localStorage;
    return [
      for (var i = 0; i < store.length; i++)
        if (store.key(i) case final String key when key.startsWith(_prefix))
          key.substring(_prefix.length),
    ]..sort();
  }

  @override
  Future<Uint8List?> read(String relativePath) async {
    validateRelativePath(relativePath);
    final value = web.window.localStorage.getItem('$_prefix$relativePath');
    return value == null ? null : base64Decode(value);
  }

  @override
  Future<void> write(
    String relativePath,
    Uint8List bytes, {
    required String? expectedHash,
  }) async {
    validateRelativePath(relativePath);
    final old = await read(relativePath);
    final oldHash = old == null ? null : sha256.convert(old).toString();
    if (oldHash != expectedHash) {
      throw const WorkspaceConflict(
        'Browser content changed in another tab. Your edit was not applied.',
      );
    }
    try {
      if (old != null) {
        final area = relativePath.startsWith('.orbit/device/')
            ? '.orbit/device'
            : '.orbit';
        web.window.localStorage.setItem(
          '$_prefix$area/history/${DateTime.now().microsecondsSinceEpoch}.before',
          base64Encode(old),
        );
      }
      web.window.localStorage.setItem(
        '$_prefix$relativePath',
        base64Encode(bytes),
      );
    } on Object {
      throw const WorkspaceFailure(
        'Browser storage could not save this edit. Keep this tab open and export your workspace; site storage may be full or unavailable.',
      );
    }
  }

  @override
  Future<void> deleteFile(String relativePath) async {
    validateRelativePath(relativePath);
    web.window.localStorage.removeItem('$_prefix$relativePath');
  }

  @override
  Future<void> close() async {}
}
