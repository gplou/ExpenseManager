import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/utils/ai_rate_limiter.dart';
import 'ai_response_parser.dart';
import '../domain/parsed_voice_transaction.dart';

class VoiceTransactionParser {
  VoiceTransactionParser(this._client);

  final SupabaseClient _client;
  static const String _function = 'parse-voice-transaction';

  Future<ParsedVoiceTransaction?> parse(
    String transcription, {
    List<Map<String, String>> subcategories = const [],
  }) async {
    if (!AiRateLimiter.instance.tryConsume()) {
      throw const RateLimitFailure(
        'Rate limit reached: max ${AiRateLimiter.maxPerMinute} uses per minute. Please wait.',
      );
    }
    try {
      final response = await _client.functions
          .invoke(
            _function,
            body: {
              'transcription': transcription,
              if (subcategories.isNotEmpty) 'subcategories': subcategories,
            },
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw const NetworkFailure(
              'Voice processing timed out. Please try again.',
            ),
          );

      if (response.status != 200) return null;

      final data = response.data as Map<String, dynamic>;
      final json = AiResponseParser.parseJsonResponse(data['result'] as String?);
      if (json == null) return null;

      return ParsedVoiceTransaction.fromAiJson(json);
    } catch (e, st) {
      debugPrint('VoiceTransactionParser error: $e\n$st');
      rethrow;
    }
  }
}

final voiceTransactionParserProvider = Provider<VoiceTransactionParser>((ref) {
  return VoiceTransactionParser(ref.watch(supabaseClientProvider));
});
