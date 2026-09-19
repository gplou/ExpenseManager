import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:expense_manager/core/errors/failures.dart';
import 'package:expense_manager/core/network/supabase_client.dart';
import 'package:expense_manager/core/utils/ai_rate_limiter.dart';
import 'package:expense_manager/features/transactions/domain/parsed_voice_transaction.dart';
import 'package:expense_manager/core/utils/app_logger.dart';

/// Parses a voice recording into transaction fields via the
/// `parse-voice-transaction` Edge Function: the raw audio is sent to
/// Gemini, which transcribes it and extracts amount/type/category/date/
/// recurrence in one call (no on-device speech-to-text step).
class VoiceTransactionParser {
  VoiceTransactionParser(this._client);

  final SupabaseClient _client;
  static const String _function = 'parse-voice-transaction';

  static final _codeFenceStart =
      RegExp(r'^```(?:json)?\s*', caseSensitive: false);
  static final _codeFenceEnd = RegExp(r'\s*```\s*$');

  Future<ParsedVoiceTransaction?> parse(
    Uint8List audioBytes, {
    String mimeType = 'audio/wav',
    List<Map<String, String>> subcategories = const [],
  }) async {
    if (!AiRateLimiter.instance.tryConsume()) {
      throw const RateLimitFailure(
        'Rate limit reached: max ${AiRateLimiter.maxPerMinute} uses per minute. Please wait.',
      );
    }
    try {
      // The edge function aborts its own Gemini call at 25s; this must stay
      // above that so the server's own timeout/result wins the race instead
      // of the client discarding (and re-uploading) a call that may still
      // succeed — mirrors ChatRepository's 30s-client/25s-server margin.
      final response = await _client.functions
          .invoke(
            _function,
            body: {
              'audio_base64': base64Encode(audioBytes),
              'mime_type': mimeType,
              'local_date': _todayLocalDate(),
              if (subcategories.isNotEmpty) 'subcategories': subcategories,
            },
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw const NetworkFailure(
              'Voice processing timed out. Please try again.',
            ),
          );

      final rawData = response.data;
      if (rawData is! Map<String, dynamic>) {
        throw const ServerFailure('Unexpected response from AI service');
      }
      final json = _parseJsonResponse(rawData['result'] as String?);
      if (json == null) return null;

      final result = ParsedVoiceTransaction.fromAiJson(json);
      // Gemini returns amount:0 when it heard nothing transaction-like
      // (silence, noise, unrelated speech) — treat that the same as a
      // failed parse rather than opening the form on a zero amount.
      if (result.amount <= 0) return null;
      return result;
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
      AppLogger.log('VoiceTransactionParser error: $e\n$st');
      throw const NetworkFailure('Failed to communicate with AI');
    }
  }

  static String _todayLocalDate() {
    final now = clock.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Strips optional markdown code fences and decodes the JSON string.
  /// Returns `null` when [raw] is null, empty, not valid JSON, or not a
  /// JSON object (Gemini has no `responseSchema` enforcing the shape, so a
  /// bare array/string/number literal is possible in principle).
  static Map<String, dynamic>? _parseJsonResponse(String? raw) {
    if (raw == null || raw.isEmpty) return null;

    final cleaned = raw
        .trim()
        .replaceFirst(_codeFenceStart, '')
        .replaceFirst(_codeFenceEnd, '')
        .trim();

    if (cleaned.isEmpty) return null;

    try {
      final decoded = jsonDecode(cleaned);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }
}

final voiceTransactionParserProvider = Provider<VoiceTransactionParser>((ref) {
  return VoiceTransactionParser(ref.watch(supabaseClientProvider));
});
