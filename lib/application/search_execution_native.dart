import 'dart:isolate';

Future<T> runSearchWork<T>(T Function() work, {int size = 0}) =>
    size >= 65536 ? Isolate.run(work) : Future.value(work());
