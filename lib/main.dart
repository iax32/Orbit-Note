import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/orbit_app.dart';
import 'platform/background_sync.dart';

export 'app/orbit_app.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (await startBackgroundSync(args)) return;
  runApp(const ProviderScope(child: OrbitNoteApp()));
}

@pragma('vm:entry-point')
Future<void> orbitBackgroundSync() async {
  WidgetsFlutterBinding.ensureInitialized();
  await runAndroidBackgroundSync();
}
