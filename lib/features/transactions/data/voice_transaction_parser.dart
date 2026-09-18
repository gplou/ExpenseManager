import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:expense_manager/features/transactions/domain/parsed_voice_transaction.dart';
import 'local_nlp/amount_extractor.dart';
import 'local_nlp/category_matcher.dart';
import 'local_nlp/date_phrase_parser.dart';
import 'local_nlp/recurrence_phrase_detector.dart';
import 'local_nlp/transaction_type_detector.dart';

/// Parses a speech-to-text transcription into transaction fields entirely
/// on-device (no AI/network call): amount, type and category are guessed
/// from keywords per [local_nlp], and the full transcription is kept as the
/// description so the user can always see/edit exactly what was said.
class VoiceTransactionParser {
  const VoiceTransactionParser();

  static final _subcategoryPhrase = RegExp(
    r'(?:subcategor[íi]a|subcategory|sous.?cat[ée]gorie|unterkategorie)'
    r'\s+([\p{L} ]+)',
    caseSensitive: false,
    unicode: true,
  );

  Future<ParsedVoiceTransaction?> parse(
    String transcription, {
    required String langCode,
    List<Map<String, String>> subcategories = const [],
  }) async {
    final text = transcription.trim();
    if (text.isEmpty) return null;

    final amount = AmountExtractor.firstIn(text);
    if (amount == null || amount <= 0) return null;

    final type = TransactionTypeDetector.detect(text, langCode);
    final category = CategoryMatcher.match(text, type);
    final date = DatePhraseParser.resolve(text, langCode);
    final recurrence = RecurrencePhraseDetector.detect(text, langCode);
    final subcategoryResult = _resolveSubcategory(text, category, subcategories);

    return ParsedVoiceTransaction(
      amount: amount,
      type: type,
      category: category,
      description: text,
      subcategory: subcategoryResult.$1,
      isNewSubcategory: subcategoryResult.$2,
      date: date,
      isRecurring: recurrence.isRecurring,
      recurrenceType: recurrence.recurrenceType,
    );
  }

  /// Honors an explicit "subcategoría X" / "subcategory X" phrase; otherwise
  /// no subcategory is suggested (auto-suggestion without AI isn't reliable
  /// enough to be worth it — the user can still pick one in the edit sheet).
  (String?, bool) _resolveSubcategory(
    String text,
    String category,
    List<Map<String, String>> subcategories,
  ) {
    final match = _subcategoryPhrase.firstMatch(text);
    final name = match?.group(1)?.trim();
    if (name == null || name.isEmpty) return (null, false);

    final exists = subcategories.any((s) =>
        s['category']?.toLowerCase() == category.toLowerCase() &&
        s['name']?.toLowerCase() == name.toLowerCase());
    return (name, !exists);
  }
}

final voiceTransactionParserProvider = Provider<VoiceTransactionParser>((ref) {
  return const VoiceTransactionParser();
});
