import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ImageCompressor {
  static const int defaultMaxSide = 1024;
  static const int defaultQuality = 70;

  static Future<Uint8List> compress(
    Uint8List bytes, {
    int maxSide = defaultMaxSide,
    int quality = defaultQuality,
  }) {
    return compute(
      _compressInIsolate,
      _CompressArgs(bytes: bytes, maxSide: maxSide, quality: quality),
    );
  }
}

class _CompressArgs {
  _CompressArgs({
    required this.bytes,
    required this.maxSide,
    required this.quality,
  });

  final Uint8List bytes;
  final int maxSide;
  final int quality;
}

Uint8List _compressInIsolate(_CompressArgs args) {
  final decoded = img.decodeImage(args.bytes);
  if (decoded == null) return args.bytes;

  final w = decoded.width;
  final h = decoded.height;
  final needsResize = w > args.maxSide || h > args.maxSide;

  final processed = needsResize
      ? (w >= h
          ? img.copyResize(decoded, width: args.maxSide)
          : img.copyResize(decoded, height: args.maxSide))
      : decoded;

  return Uint8List.fromList(img.encodeJpg(processed, quality: args.quality));
}
