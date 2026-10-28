import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

/// Closing Orbit (including a crash) must not leave a public tunnel forwarding
/// to a loopback port that another application could later reuse.
void Function() containOrbitChild(Process process) {
  if (!Platform.isWindows || sizeOf<IntPtr>() != 8) {
    throw StateError('Managed live sharing requires 64-bit Windows.');
  }
  final kernel = DynamicLibrary.open('kernel32.dll');
  final create = kernel
      .lookupFunction<
        IntPtr Function(Pointer<Void>, Pointer<Uint16>),
        int Function(Pointer<Void>, Pointer<Uint16>)
      >('CreateJobObjectW');
  final configure = kernel
      .lookupFunction<
        Int32 Function(IntPtr, Int32, Pointer<Void>, Uint32),
        int Function(int, int, Pointer<Void>, int)
      >('SetInformationJobObject');
  final open = kernel
      .lookupFunction<
        IntPtr Function(Uint32, Int32, Uint32),
        int Function(int, int, int)
      >('OpenProcess');
  final assign = kernel
      .lookupFunction<Int32 Function(IntPtr, IntPtr), int Function(int, int)>(
        'AssignProcessToJobObject',
      );
  final close = kernel
      .lookupFunction<Int32 Function(IntPtr), int Function(int)>('CloseHandle');
  var job = create(nullptr, nullptr);
  if (job == 0) {
    throw StateError(
      'Windows could not protect the live connection lifetime. Retry.',
    );
  }
  final limits = calloc<Uint8>(
    144,
  ); // JOBOBJECT_EXTENDED_LIMIT_INFORMATION, x64.
  var retained = false;
  try {
    limits.cast<Uint32>()[4] = 0x2000; // JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE.
    if (configure(job, 9, limits.cast<Void>(), 144) == 0) {
      throw StateError(
        'Windows could not protect the live connection lifetime. Retry.',
      );
    }
    final child = open(0x0101, 0, process.pid); // SET_QUOTA | TERMINATE.
    if (child == 0) {
      throw StateError(
        'Windows could not manage the live connection process. Retry.',
      );
    }
    try {
      if (assign(job, child) == 0) {
        throw StateError(
          'Windows could not manage the live connection process. Retry.',
        );
      }
    } finally {
      close(child);
    }
    retained = true;
    return () {
      if (job != 0) {
        close(job);
        job = 0;
      }
    };
  } finally {
    calloc.free(limits);
    if (!retained) close(job);
  }
}
