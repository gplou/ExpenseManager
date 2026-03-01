import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../domain/parsed_voice_transaction.dart';
import '../domain/transaction_model.dart';

class VoiceTransactionParser {
  static const String _endpoint = 'https://api.anthropic.com/v1/messages';
  static const String _model = 'claude-haiku-4-5-20251001';

  Future<ParsedVoiceTransaction?> parse(String transcription) async {
    const apiKey = AppConfig.claudeApiKey;
    if (apiKey.isEmpty) return null;

    final prompt = '''You are a transaction parser for a personal finance app.
Extract transaction details from this text (may be in Spanish or English):
"$transcription"

Available expense categories: Comida, Transporte, Vivienda, Ocio, Salud, Educación, Ropa, Tecnología, Otros
Available income categories: Salario, Freelance, Inversión, Regalo, Otros

Return ONLY valid JSON (no explanation):
{"amount": <positive number>, "type": "expense" or "income", "category": "<exact category name>", "description": "<brief description or empty string>"}

Rules:
- amount must be a positive number
- If type is ambiguous, default to "expense"
- Pick the closest matching category; use "Otros" if unclear
- description should be concise (max 50 chars)''';

    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'x-api-key': apiKey,
              'anthropic-version': '2023-06-01',
              'content-type': 'application/json',
            },
            body: jsonEncode({
              'model': _model,
              'max_tokens': 200,
              'messages': [
                {'role': 'user', 'content': prompt},
              ],
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final text = (data['content'] as List).first['text'] as String;
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
    } catch (_) {
      return null;
    }
  }
}
