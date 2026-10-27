import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:pdfium_dart/pdfium_dart.dart' as bindings;
import 'package:pdfrx/pdfrx.dart';
// Native implementation regression: completion/wakeup must use the same predicate lock.
import 'package:pdfrx_engine/src/native/win32/file_access.dart';
import 'package:pdfrx_engine/src/native/pdfium_file_access.dart';
import 'package:pdfrx_engine/src/native/win32/kernel32.dart';
import 'package:pdfrx_engine/src/native/worker.dart';
import 'support/pdf_fixture.dart';

int callRead((int, int) params) {
  final access = Pointer<bindings.FPDF_FILEACCESS>.fromAddress(params.$1);
  final read = access.ref.m_GetBlock
      .asFunction<
        int Function(Pointer<Void>, int, Pointer<UnsignedChar>, int)
      >();
  return read(
    access.ref.m_Param,
    0,
    Pointer<UnsignedChar>.fromAddress(params.$2),
    8,
  );
}

void main() {
  test(
    'Windows read waits through a spurious wake before consuming callback bytes',
    () async {
      final helper = PdfiumFileAccessHelperWin32();
      late int address;
      var completion = Completer<void>();
      final callback =
          NativeCallable<
            Void Function(IntPtr, Pointer<Uint8>, IntPtr)
          >.listener((int position, Pointer<Uint8> buffer, int size) {
            final cs = address + sizeOf<bindings.FPDF_FILEACCESS>();
            final cv = cs + sizeOfCriticalSection;
            EnterCriticalSection(cs);
            WakeConditionVariable(
              cv,
            ); // A notification is not a completed read.
            LeaveCriticalSection(cs);
            Timer(const Duration(milliseconds: 10), () {
              buffer.asTypedList(size).fillRange(0, size, 37);
              helper.setValue(address, size);
              completion.complete();
            });
          });
      final output = calloc<Uint8>(8);
      address = await helper.create(8, callback.nativeFunction.address);
      try {
        for (var i = 0; i < 20; i++) {
          completion = Completer<void>();
          final read = BackgroundWorker.compute(callRead, (
            address,
            output.address,
          ));
          await completion.future.timeout(const Duration(seconds: 5));
          expect(await read.timeout(const Duration(seconds: 5)), 8);
          expect(output.asTypedList(8), everyElement(37));
          output.asTypedList(8).fillRange(0, 8, 0);
        }
      } finally {
        helper.destroy(address);
        callback.close();
        calloc.free(output);
      }
    },
    skip: !Platform.isWindows,
  );

  test(
    'native file callbacks report short, failed and thrown reads as failure',
    () async {
      for (final returned in [-1, 0, 7, 8, 99]) {
        final access = await PdfiumFileAccess.create(8, (
          buffer,
          position,
          size,
        ) {
          buffer.fillRange(0, size, 37);
          return returned;
        });
        final output = calloc<Uint8>(8);
        try {
          expect(
            await BackgroundWorker.compute(callRead, (
              access.fileAccess,
              output.address,
            )).timeout(const Duration(seconds: 5)),
            returned == 8 ? 1 : 0,
          );
        } finally {
          access.dispose();
          calloc.free(output);
        }
      }
      final access = await PdfiumFileAccess.create(
        8,
        (buffer, position, size) => throw StateError('Synthetic read failure'),
      );
      final output = calloc<Uint8>(8);
      try {
        expect(
          await BackgroundWorker.compute(callRead, (
            access.fileAccess,
            output.address,
          )).timeout(const Duration(seconds: 5)),
          0,
        );
      } finally {
        access.dispose();
        calloc.free(output);
      }
    },
    skip: !Platform.isWindows,
  );
  test(
    'large memory-backed PDF survives repeated distant text and page raster reads',
    () async {
      expect(await initPdfTesting(), isTrue);
      final source = largeResearchPdf(pageCount: 180, linesPerPage: 85);
      expect(
        source.length,
        greaterThan(1024 * 1024),
      ); // Exercises callback-backed reads.
      final watch = Stopwatch()..start();
      for (var cycle = 0; cycle < 3; cycle++) {
        final doc = await PdfDocument.openData(
          source,
          sourceName: 'large-memory-$cycle',
          useProgressiveLoading: false,
        );
        try {
          for (final number in [1, 2, 180, 90, 4, 177, 1]) {
            final page = doc.pages[number - 1];
            final text = await page.loadText().timeout(
              const Duration(seconds: 5),
            );
            expect(text?.fullText, contains('Orbit page $number'));
            final image = await page
                .render(fullWidth: 306, fullHeight: 396)
                .timeout(const Duration(seconds: 5));
            expect(image, isNotNull);
            final pixels = image!.pixels;
            expect(
              pixels.where((value) => value < 200).length,
              greaterThan(500),
            );
            image.dispose();
          }
        } finally {
          await doc.dispose();
        }
      }
      // Informational native timing, not an FPS or physical-pen latency claim.
      debugPrint(
        'PDF callback-backed 3 reopen cycles / 21 distant renders: ${watch.elapsedMilliseconds} ms',
      );
    },
    skip: !Platform.isWindows,
    timeout: const Timeout(Duration(seconds: 90)),
  );
  test(
    'callback and file rendering retain identical full-resolution pixels',
    () async {
      expect(await initPdfTesting(), isTrue);
      final source = largeResearchPdf(pageCount: 180, linesPerPage: 85);
      final directory = await Directory.systemTemp.createTemp(
        'orbit-pdf-fidelity-',
      );
      await File('${directory.path}/reference.pdf').writeAsBytes(source);
      final memory = await PdfDocument.openData(
        source,
        sourceName: 'full-quality-callback',
      );
      final file = await PdfDocument.openFile(
        '${directory.path}/reference.pdf',
      );
      try {
        for (final number in [1, 90, 180]) {
          for (final scale in [1.0, 3.0]) {
            final a = await memory.pages[number - 1].render(
              fullWidth: 612 * scale,
              fullHeight: 792 * scale,
            );
            final b = await file.pages[number - 1].render(
              fullWidth: 612 * scale,
              fullHeight: 792 * scale,
            );
            expect(a, isNotNull);
            expect(b, isNotNull);
            try {
              expect(a!.width, b!.width);
              expect(a.height, b.height);
              expect(
                sha256.convert(a.pixels).toString(),
                sha256.convert(b.pixels).toString(),
              );
            } finally {
              a?.dispose();
              b?.dispose();
            }
          }
        }
      } finally {
        await memory.dispose();
        await file.dispose();
        await directory.delete(recursive: true);
      }
    },
    skip: !Platform.isWindows,
  );
}
