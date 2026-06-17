import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:expense_manager/core/errors/failures.dart';
import 'package:expense_manager/core/network/supabase_client.dart';
import 'package:expense_manager/core/utils/ai_rate_limiter.dart';
import 'package:expense_manager/core/utils/image_compressor.dart';
import 'package:expense_manager/core/utils/image_mime_detector.dart';
import 'ai_response_parser.dart';
import 'package:expense_manager/features/transactions/domain/parsed_voice_transaction.dart';
import 'package:expense_manager/core/utils/app_logger.dart';

class ImageTransactionParser {
  ImageTransactionParser(this._client);

  final SupabaseClient _client;
  static const String _function = 'parse-image-transaction';

  Future<ParsedVoiceTransaction?> parse(
    Uint8List imageBytes, {
    List<Map<String, String>> subcategories = const [],
  }) async {
    if (!AiRateLimiter.instance.tryConsume()) {
      throw const RateLimitFailure(
        'Rate limit reached: max ${AiRateLimiter.maxPerMinute} uses per minute. Please wait.',
      );
    }
    if (imageBytes.length > 4 * 1024 * 1024) return null;
    if (!ImageMimeDetector.isValidImage(imageBytes)) return null;

    try {
      final compressed = await ImageCompressor.compress(imageBytes);
      final base64Image = base64Encode(compressed);
      final mimeType = ImageMimeDetector.detect(compressed) ?? 'image/jpeg';

      final response = await _client.functions
          .invoke(
            _function,
            body: {
              'image_base64': base64Image,
              'mime_type': mimeType,
              if (subcategories.isNotEmpty) 'subcategories': subcategories,
            },
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw const NetworkFailure(
              'Image processing timed out. Please try again.',
            ),
          );

      final data = response.data as Map<String, dynamic>;
      final json = AiResponseParser.parseJsonResponse(data['result'] as String?);
      if (json == null) return null;

      final amount = (json['amount'] as num).toDouble();
      if (amount <= 0) return null;

      return ParsedVoiceTransaction.fromAiJson(json);
    } on AppFailure {
      rethrow;
    } on FunctionException catch (e) {
      final details = e.details;
      final serverError = details is Map ? details['error'] as String? : null;
      if (e.status == 429) {
        throw RateLimitFailure(serverError ?? 'Rate limit exceeded');
      }
      throw ServerFailure(serverError ?? 'AI service error (${e.status})');
    } catch (e, st) {
      AppLogger.log('ImageTransactionParser error: $e\n$st');
      rethrow;
    }
  }

}

final imageTransactionParserProvider = Provider<ImageTransactionParser>((ref) {
  return ImageTransactionParser(ref.watch(supabaseClientProvider));
});
