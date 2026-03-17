import 'dart:convert';

/// Shared utility for parsing AI responses from Supabase edge functions.
///
/// Both VoiceTransactionParser and ImageTransactionParser receive a JSON
/// response that may be wrapped in markdown code fences. This class
/// centralises the stripping + decoding logic so it isn't duplicated.
class AiResponseParser {
  AiResponseParser._();

  static final _codeFenceStart = RegExp(r'^```(?:json)?\s*', caseSensitive: false);
  static final _codeFenceEnd = RegExp(r'\s*```\s*$');

  /// Strips optional markdown code fences and decodes the JSON string.
  ///
  /// Returns `null` when [raw] is null, empty, or not valid JSON.
  static Map<String, dynamic>? parseJsonResponse(String? raw) {
    if (raw == null || raw.isEmpty) return null;

    final cleaned = raw
        .trim()
        .replaceFirst(_codeFenceStart, '')
        .replaceFirst(_codeFenceEnd, '')
        .trim();

    if (cleaned.isEmpty) return null;

    try {
      return jsonDecode(cleaned) as Map<String, dynamic>;
    } on FormatException {
      return null;
    }
  }
}
