import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../core/utils/ai_rate_limiter.dart';
import 'ai_response_parser.dart';
import '../domain/parsed_voice_transaction.dart';
import '../domain/transaction_model.dart';

class VoiceTransactionParser {
  static const String _function = 'parse-voice-transaction';

  Future<ParsedVoiceTransaction?> parse(String transcription) async {
    if (!AiRateLimiter.instance.tryConsume()) {
      throw RateLimitFailure(
        'Límite alcanzado: máximo ${AiRateLimiter.maxPerMinute} usos por minuto. Espera un momento.',
      );
    }
    try {
      final response = await Supabase.instance.client.functions.invoke(
        _function,
        body: {'transcription': transcription},
      );

      if (response.status != 200) return null;

      final data = response.data as Map<String, dynamic>;
      final json = AiResponseParser.parseJsonResponse(data['result'] as String?);
      if (json == null) return null;

      final type = json['type'] == 'income'
          ? TransactionType.income
          : TransactionType.expense;
      final amount = (json['amount'] as num).toDouble();
      final category = json['category'] as String;
      final desc = json['description'] as String?;
      final subcategory = json['subcategory'] as String?;
      final isNewSubcategory = json['is_new_subcategory'] as bool? ?? false;
      final dateStr = json['date'] as String?;
      final date = (dateStr != null && dateStr.isNotEmpty)
          ? DateTime.tryParse(dateStr)
          : null;
      final isRecurring = json['is_recurring'] as bool? ?? false;
      final recurrenceType = json['recurrence_type'] as String?;
      final currency = json['currency'] as String?;

      return ParsedVoiceTransaction(
        amount: amount,
        type: type,
        category: category,
        description: (desc?.isEmpty ?? true) ? null : desc,
        subcategory: (subcategory?.isEmpty ?? true) ? null : subcategory,
        isNewSubcategory: isNewSubcategory,
        date: date,
        isRecurring: isRecurring,
        recurrenceType: recurrenceType,
        currency: (currency?.isEmpty ?? true) ? null : currency,
      );
    } catch (e, st) {
      debugPrint('VoiceTransactionParser error: $e\n$st');
      rethrow;
    }
  }
}
