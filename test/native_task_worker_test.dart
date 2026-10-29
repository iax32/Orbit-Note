import 'dart:isolate';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/infrastructure/workers/native_task_worker.dart';

var _sequence = 0;
(int, int) _task(int value) {
  if (value == -1) throw const FormatException('invalid synthetic request');
  if (value == -2) Isolate.exit();
  return (value, ++_sequence);
}

void main() {
  test(
    'reuses one worker, orders accepted requests and drains before close',
    () async {
      final worker = NativeTaskWorker<int, (int, int)>(_task);
      final first = worker.run(10),
          second = worker.run(20),
          third = worker.run(30);
      final closing = worker.close();
      expect(await first, (10, 1));
      expect(await second, (20, 2));
      expect(await third, (30, 3));
      await closing;
      await expectLater(worker.run(40), throwsStateError);
    },
  );
  test(
    'failed request preserves the worker and unexpected exit restarts safely',
    () async {
      final worker = NativeTaskWorker<int, (int, int)>(_task);
      addTearDown(worker.close);
      expect(await worker.run(1), (1, 1));
      await expectLater(worker.run(-1), throwsStateError);
      expect(await worker.run(2), (2, 2));
      await expectLater(
        worker.run(-2).timeout(const Duration(seconds: 3)),
        throwsStateError,
      );
      expect(await worker.run(3), (3, 1));
    },
  );
}
