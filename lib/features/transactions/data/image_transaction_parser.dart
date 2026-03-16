import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/ai_rate_limiter.dart';
import '../domain/parsed_voice_transaction.dart';
import '../domain/transaction_model.dart';

class ImageTransactionParser {
  static const String _function = 'parse-image-transaction';

  Future<ParsedVoiceTransaction?> parse(Uint8List imageBytes) async {
    if (!AiRateLimiter.instance.tryConsume()) {
      throw Exception(
        'Límite alcanzado: máximo ${AiRateLimiter.maxPerMinute} usos por minuto. Espera un momento.',
      );
    }
    if (imageBytes.length > 4 * 1024 * 1024) return null;
    if (!_isValidImageMime(imageBytes)) return null;

    try {
      final base64Image = base64Encode(imageBytes);
      final mimeType = _detectMimeType(imageBytes);

      final response = await Supabase.instance.client.functions.invoke(
        _function,
        body: {
          'image_base64': base64Image,
          'mime_type': mimeType,
        },
      );

      if (response.status != 200) return null;

      final data = response.data as Map<String, dynamic>;
      var text = data['result'] as String?;
      if (text == null || text.isEmpty) return null;

      // Strip markdown code fences (```json ... ```) that the AI may include
      text = text
          .replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
          .replaceFirst(RegExp(r'\s*```\s*$'), '')
          .trim();

      final json = jsonDecode(text) as Map<String, dynamic>;

      final amount = (json['amount'] as num).toDouble();
      if (amount <= 0) return null;

      final type = json['type'] == 'income'
          ? TransactionType.income
          : TransactionType.expense;
      final category = json['category'] as String;
      final desc = json['description'] as String?;
      final subcategory = json['subcategory'] as String?;
      final isNewSubcategory = json['is_new_subcategory'] as bool? ?? false;
      final currency = json['currency'] as String?;

      return ParsedVoiceTransaction(
        amount: amount,
        type: type,
        category: category,
        description: (desc?.isEmpty ?? true) ? null : desc,
        subcategory: (subcategory?.isEmpty ?? true) ? null : subcategory,
        isNewSubcategory: isNewSubcategory,
        currency: (currency?.isEmpty ?? true) ? null : currency,
      );
    } catch (e, st) {
      debugPrint('ImageTransactionParser error: $e\n$st');
      rethrow;
    }
  }

  // ── Image validation ────────────────────────────────────────────────────────

  /// Checks magic bytes to confirm the data is a supported image format.
  bool _isValidImageMime(Uint8List bytes) {
    if (bytes.length < 12) { return false; }
    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) { return true; }
    // PNG: 89 50 4E 47
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) { return true; }
    // WebP: RIFF....WEBP
    if (bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) { return true; }
    // GIF: GIF87a or GIF89a
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) { return true; }
    return false;
  }

  /// Returns the correct MIME type string based on magic bytes.
  String _detectMimeType(Uint8List bytes) {
    if (bytes[0] == 0xFF && bytes[1] == 0xD8) return 'image/jpeg';
    if (bytes[0] == 0x89 && bytes[1] == 0x50) return 'image/png';
    if (bytes[0] == 0x47 && bytes[1] == 0x49) return 'image/gif';
    return 'image/webp';
  }
}
