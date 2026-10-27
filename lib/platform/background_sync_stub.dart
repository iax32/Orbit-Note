bool get backgroundSyncSupported => false;
Future<void> configureBackgroundSync(bool enabled) async =>
    throw UnsupportedError('Background sync is unavailable on this platform.');
Future<bool> startBackgroundSync(List<String> args) async => false;
Future<void> runAndroidBackgroundSync() async {}
Future<String?> backgroundSyncLastRun() async => null;
