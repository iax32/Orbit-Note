import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../domain/sync_device.dart';
import '../../domain/workspace_failure.dart';
import '../storage/native_workspace_store.dart';

/// Non-secret installation identity, outside every portable Vault. Lazy: called
/// only when sync is configured. This store never holds account credentials.
Future<SyncDevice> loadSyncDevice({
  required String appVersion,
  String? supportDirectory,
}) async {
  final support =
      supportDirectory ?? (await getApplicationSupportDirectory()).path;
  final store = NativeWorkspaceStore();
  try {
    await store.initialize(path: p.join(support, 'orbit-sync-installation'));
    const path = '.orbit/device/identity-v1.json';
    var bytes = await store.read(path);
    if (bytes == null) {
      bytes = Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'format': 'orbit-note-sync-device',
            'version': 1,
            'id': const Uuid().v4(),
            'name': '${Platform.operatingSystem} device',
          }),
        ),
      );
      await store.write(path, bytes, expectedHash: null);
    }
    final json = jsonDecode(utf8.decode(bytes)) as Map;
    if (json['format'] != 'orbit-note-sync-device' ||
        json['version'] != 1 ||
        json['id'] is! String ||
        !RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        ).hasMatch(json['id'] as String) ||
        json['name'] is! String) {
      throw const WorkspaceFailure(
        'Device identity is unsupported; it has been preserved.',
      );
    }
    return SyncDevice(
      id: json['id'] as String,
      name: json['name'] as String,
      platform: Platform.operatingSystem,
      appVersion: appVersion,
    );
  } finally {
    await store.close();
  }
}
