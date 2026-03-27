import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/utils/ai_rate_limiter.dart';
import '../../../core/utils/image_mime_detector.dart';
import 'ai_response_parser.dart';
import '../domain/parsed_voice_transaction.dart';

class ImageTransactionParser {
  ImageTransactionParser(this._client);

  final SupabaseClient _client;
  static const String _function = 'parse-image-transaction';

  Future<ParsedVoiceTransaction?> parse(Uint8List imageBytes) async {
    if (!AiRateLimiter.instance.tryConsume()) {
      throw const RateLimitFailure(
        'Rate limit reached: max ${AiRateLimiter.maxPerMinute} uses per minute. Please wait.',
      );
    }
    if (imageBytes.length > 4 * 1024 * 1024) return null;
    if (!ImageMimeDetector.isValidImage(imageBytes)) return null;

    try {
      final base64Image = base64Encode(imageBytes);
      final mimeType = ImageMimeDetector.detect(imageBytes) ?? 'image/jpeg';

      final response = await _client.functions
          .invoke(
            _function,
            body: {
              'image_base64': base64Image,
              'mime_type': mimeType,
            },
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw const NetworkFailure(
              'Image processing timed out. Please try again.',
            ),
          );

      if (response.status != 200) return null;

      final data = response.data as Map<String, dynamic>;
      final json = AiResponseParser.parseJsonResponse(data['result'] as String?);
      if (json == null) return null;

      final amount = (json['amount'] as num).toDouble();
      if (amount <= 0) return null;

      return ParsedVoiceTransaction.fromAiJson(json);
    } catch (e, st) {
      debugPrint('ImageTransactionParser error: $e\n$st');
      rethrow;
    }
  }

}

final imageTransactionParserProvider = Provider<ImageTransactionParser>((ref) {
  return ImageTransactionParser(ref.watch(supabaseClientProvider));
});
