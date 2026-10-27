import 'dart:typed_data';
import 'package:crypto/crypto.dart';

String attachmentChecksum(Uint8List bytes) => sha256.convert(bytes).toString();

/// Header-only dimensions; no image decompression or dependency on Flutter.
({int width, int height})? attachmentImageSize(Uint8List b) {
  ({int width, int height})? size(int w, int h) =>
      w > 0 && h > 0 && w <= 100000 && h <= 100000
      ? (width: w, height: h)
      : null;
  final data = ByteData.sublistView(b);
  if (b.length >= 24 &&
      b[0] == 137 &&
      b[1] == 80 &&
      b[2] == 78 &&
      b[3] == 71 &&
      b[12] == 73 &&
      b[13] == 72 &&
      b[14] == 68 &&
      b[15] == 82) {
    return size(data.getUint32(16), data.getUint32(20));
  }
  if (b.length >= 10 && b[0] == 71 && b[1] == 73 && b[2] == 70) {
    return size(
      data.getUint16(6, Endian.little),
      data.getUint16(8, Endian.little),
    );
  }
  if (b.length >= 4 && b[0] == 0xff && b[1] == 0xd8) {
    var offset = 2;
    while (offset + 4 <= b.length) {
      if (b[offset] != 0xff) return null;
      while (offset < b.length && b[offset] == 0xff) {
        offset++;
      }
      if (offset >= b.length) return null;
      final marker = b[offset++];
      if (marker == 0xd9 || marker == 0xda) return null;
      if (marker == 0x01 || marker >= 0xd0 && marker <= 0xd7) continue;
      if (offset + 2 > b.length) return null;
      final length = data.getUint16(offset);
      if (length < 2 || offset + length > b.length) return null;
      if (const {
            0xc0,
            0xc1,
            0xc2,
            0xc3,
            0xc5,
            0xc6,
            0xc7,
            0xc9,
            0xca,
            0xcb,
            0xcd,
            0xce,
            0xcf,
          }.contains(marker) &&
          length >= 7) {
        return size(data.getUint16(offset + 5), data.getUint16(offset + 3));
      }
      offset += length;
    }
  }
  return null;
}
