import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/parsed_voice_transaction.dart';
import '../domain/transaction_model.dart';

class VoiceTransactionParser {
  static const String _function = 'parse-voice-transaction';

  Future<ParsedVoiceTransaction?> parse(String transcription) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        _function,
        body: {'transcription': transcription},
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

      final type = json['type'] == 'income'
          ? TransactionType.income
          : TransactionType.expense;
      final amount = (json['amount'] as num).toDouble();
      final category = json['category'] as String;
      final desc = json['description'] as String?;

      return ParsedVoiceTransaction(
        amount: amount,
        type: type,
        category: category,
        description: (desc?.isEmpty ?? true) ? null : desc,
      );
    } catch (e, st) {
      debugPrint('VoiceTransactionParser error: $e\n$st');
      rethrow;
    }
  }
}
