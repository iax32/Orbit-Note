/// Browser fallback yields before bounded candidate projection. Native uses an
/// isolate; no unsupported Isolate API runs in web builds.
Future<T> runSearchWork<T>(T Function() work, {int size = 0}) =>
    Future.value(work());
