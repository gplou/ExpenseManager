import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:expense_manager/core/utils/image_mime_detector.dart';

void main() {
  /// Helper to build a Uint8List of at least 12 bytes from a short prefix.
  Uint8List makeBytes(List<int> prefix, {int totalLength = 12}) {
    final list = List<int>.filled(totalLength, 0x00);
    for (var i = 0; i < prefix.length; i++) {
      list[i] = prefix[i];
    }
    return Uint8List.fromList(list);
  }

  group('ImageMimeDetector.detect', () {
    test('returns image/jpeg for JPEG magic bytes', () {
      final bytes = makeBytes([0xFF, 0xD8, 0xFF, 0xE0]);
      expect(ImageMimeDetector.detect(bytes), 'image/jpeg');
    });

    test('returns image/png for PNG magic bytes', () {
      final bytes = makeBytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      expect(ImageMimeDetector.detect(bytes), 'image/png');
    });

    test('returns image/gif for GIF magic bytes', () {
      final bytes = makeBytes([0x47, 0x49, 0x46, 0x38, 0x39, 0x61]);
      expect(ImageMimeDetector.detect(bytes), 'image/gif');
    });

    test('returns image/webp for WebP magic bytes', () {
      // RIFF....WEBP pattern: bytes 0-3 = RIFF, bytes 8-11 = WEBP
      final bytes = makeBytes([
        0x52, 0x49, 0x46, 0x46, // RIFF
        0x00, 0x00, 0x00, 0x00, // file size (don't care)
        0x57, 0x45, 0x42, 0x50, // WEBP
      ]);
      expect(ImageMimeDetector.detect(bytes), 'image/webp');
    });

    test('returns null for unknown bytes', () {
      final bytes = makeBytes([0x00, 0x01, 0x02, 0x03]);
      expect(ImageMimeDetector.detect(bytes), isNull);
    });

    test('returns null for bytes shorter than 12', () {
      final bytes = Uint8List.fromList([0xFF, 0xD8, 0xFF]);
      expect(ImageMimeDetector.detect(bytes), isNull);
    });
  });

  group('ImageMimeDetector.isValidImage', () {
    test('returns true for a known image format', () {
      final bytes = makeBytes([0x89, 0x50, 0x4E, 0x47]);
      expect(ImageMimeDetector.isValidImage(bytes), isTrue);
    });

    test('returns false for unknown bytes', () {
      final bytes = makeBytes([0x00, 0x01, 0x02, 0x03]);
      expect(ImageMimeDetector.isValidImage(bytes), isFalse);
    });

    test('returns false for bytes shorter than 12', () {
      final bytes = Uint8List.fromList([0x89, 0x50]);
      expect(ImageMimeDetector.isValidImage(bytes), isFalse);
    });
  });
}
