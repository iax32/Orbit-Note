import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/infrastructure/storage/native_file_digests.dart';

void main() {
  test(
    'native staging digests preserve empty/large bytes and recheck changes',
    () async {
      final root = await Directory.systemTemp.createTemp('orbit-digest-test-');
      try {
        final file = File('${root.path}/source.bin');
        expect(await nativeFileDigests(file), isNull);
        for (final length in [0, 17, 1024 * 1024 + 31]) {
          final bytes = Uint8List.fromList(
            List.generate(length, (i) => i % 251),
          );
          await file.writeAsBytes(bytes, flush: true);
          final digests = await nativeFileDigests(file, includeMd5: true);
          expect(digests?.sha256, sha256.convert(bytes).toString());
          expect(digests?.md5, md5.convert(bytes).toString());
        }
        await file.writeAsBytes([9, 8, 7], flush: true);
        expect(
          (await nativeFileDigests(file))?.sha256,
          sha256.convert([9, 8, 7]).toString(),
        );
        expect((await nativeFileDigests(file))?.md5, isNull);
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
}
