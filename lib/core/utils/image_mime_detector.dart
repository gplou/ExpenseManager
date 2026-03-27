import 'dart:typed_data';

/// Extensible MIME type detection based on magic byte signatures.
class ImageMimeDetector {
  const ImageMimeDetector._();

  static const _signatures = <_MimeSignature>[
    _MimeSignature('image/jpeg', [0xFF, 0xD8, 0xFF]),
    _MimeSignature('image/png', [0x89, 0x50, 0x4E, 0x47]),
    _MimeSignature('image/gif', [0x47, 0x49, 0x46]),
    // WebP: starts with RIFF....WEBP (bytes 0-3 and 8-11)
    _MimeSignature('image/webp', [0x52, 0x49, 0x46, 0x46], secondaryOffset: 8, secondaryBytes: [0x57, 0x45, 0x42, 0x50]),
  ];

  /// Returns the MIME type if [bytes] match a known image format, or null.
  static String? detect(Uint8List bytes) {
    if (bytes.length < 12) return null;
    for (final sig in _signatures) {
      if (sig.matches(bytes)) return sig.mimeType;
    }
    return null;
  }

  /// Returns true if [bytes] match any known image format.
  static bool isValidImage(Uint8List bytes) => detect(bytes) != null;
}

class _MimeSignature {
  const _MimeSignature(
    this.mimeType,
    this.headerBytes, {
    this.secondaryOffset,
    this.secondaryBytes,
  });

  final String mimeType;
  final List<int> headerBytes;
  final int? secondaryOffset;
  final List<int>? secondaryBytes;

  bool matches(Uint8List bytes) {
    if (bytes.length < headerBytes.length) return false;
    for (var i = 0; i < headerBytes.length; i++) {
      if (bytes[i] != headerBytes[i]) return false;
    }
    if (secondaryOffset != null && secondaryBytes != null) {
      final offset = secondaryOffset!;
      if (bytes.length < offset + secondaryBytes!.length) return false;
      for (var i = 0; i < secondaryBytes!.length; i++) {
        if (bytes[offset + i] != secondaryBytes![i]) return false;
      }
    }
    return true;
  }
}
