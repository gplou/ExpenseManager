import 'package:flutter_test/flutter_test.dart';

import 'package:expense_manager/features/transactions/data/voice_transaction_parser.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';

import '../../../helpers/clock_helper.dart';

void main() {
  const parser = VoiceTransactionParser();

  group('parse — amount & description', () {
    test('returns null when no amount is found', () async {
      final result = await parser.parse('fui al parque', langCode: 'es');
      expect(result, isNull);
    });

    test('returns null for blank transcription', () async {
      final result = await parser.parse('   ', langCode: 'es');
      expect(result, isNull);
    });

    test('extracts the first amount mentioned and keeps full text as description',
        () async {
      final result =
          await parser.parse('gasté 20 en comida', langCode: 'es');
      expect(result, isNotNull);
      expect(result!.amount, 20);
      expect(result.description, 'gasté 20 en comida');
    });

    test('parses decimal amounts with a comma (es/fr/de convention)',
        () async {
      final result = await parser.parse('20,50 euros de comida', langCode: 'es');
      expect(result!.amount, 20.5);
    });

    test('parses decimal amounts with a dot (en convention)', () async {
      final result =
          await parser.parse('spent 20.50 on food', langCode: 'en');
      expect(result!.amount, 20.5);
    });
  });

  group('parse — type detection', () {
    test('defaults to expense when ambiguous', () async {
      final result = await parser.parse('20 varios', langCode: 'es');
      expect(result!.type, TransactionType.expense);
    });

    test('detects income from keywords (es)', () async {
      final result =
          await parser.parse('cobré 1500 de nómina', langCode: 'es');
      expect(result!.type, TransactionType.income);
    });

    test('detects income from keywords (en)', () async {
      final result = await parser.parse('got paid 1500 salary', langCode: 'en');
      expect(result!.type, TransactionType.income);
    });
  });

  group('parse — category detection', () {
    test('matches a known category keyword (es)', () async {
      final result =
          await parser.parse('20 en el restaurante', langCode: 'es');
      expect(result!.category, 'Comida');
    });

    test('matches a known category keyword (en)', () async {
      final result = await parser.parse('20 for a taxi', langCode: 'en');
      expect(result!.category, 'Transporte');
    });

    test('falls back to Otros when nothing matches', () async {
      final result = await parser.parse('20 de cosas raras', langCode: 'es');
      expect(result!.category, 'Otros');
    });

    test('never returns an income-only category when type is expense',
        () async {
      // "regalo" only appears under the income category "Regalo" — buying a
      // gift is an expense, so it must fall back to "Otros", not leak the
      // income-only category name.
      final result = await parser.parse('pagué 20 por un regalo', langCode: 'es');
      expect(result!.type, TransactionType.expense);
      expect(result.category, isNot('Regalo'));
    });
  });

  group('parse — date phrases', () {
    test('resolves "ayer" against the fixed clock', () async {
      final result = await withFixedClockAsync(
        DateTime(2026, 3, 10),
        () => parser.parse('20 ayer en comida', langCode: 'es'),
      );
      expect(result!.date, DateTime(2026, 3, 9));
    });

    test('returns null date when no phrase is recognized (caller defaults to today)',
        () async {
      final result = await parser.parse('20 en comida', langCode: 'es');
      expect(result!.date, isNull);
    });
  });

  group('parse — recurrence phrases', () {
    test('detects monthly recurrence (es)', () async {
      final result =
          await parser.parse('20 cada mes de suscripción', langCode: 'es');
      expect(result!.isRecurring, isTrue);
      expect(result.recurrenceType, 'monthly');
    });

    test('detects weekly recurrence (en)', () async {
      final result = await parser.parse('20 every week', langCode: 'en');
      expect(result!.isRecurring, isTrue);
      expect(result.recurrenceType, 'weekly');
    });

    test('not recurring when no phrase found', () async {
      final result = await parser.parse('20 en comida', langCode: 'es');
      expect(result!.isRecurring, isFalse);
      expect(result.recurrenceType, isNull);
    });
  });

  group('parse — explicit subcategory phrase', () {
    test('honors "subcategoría X" and flags it as new when unknown',
        () async {
      final result = await parser.parse(
        '20 en comida subcategoría panadería',
        langCode: 'es',
      );
      expect(result!.subcategory, 'panadería');
      expect(result.isNewSubcategory, isTrue);
    });

    test('flags isNewSubcategory false when it already exists', () async {
      final result = await parser.parse(
        '20 en comida subcategoría panadería',
        langCode: 'es',
        subcategories: const [
          {'category': 'Comida', 'type': 'expense', 'name': 'panadería'},
        ],
      );
      expect(result!.isNewSubcategory, isFalse);
    });

    test('no subcategory suggested without the explicit phrase', () async {
      final result = await parser.parse('20 en comida', langCode: 'es');
      expect(result!.subcategory, isNull);
      expect(result.isNewSubcategory, isFalse);
    });

    // Regression: the phrase only matched the Spanish "subcategoría" stem,
    // so en/fr/de users could never trigger the explicit-subcategory path.
    test('also honors the phrase in en/fr/de', () async {
      final en = await parser.parse(
        '20 for food subcategory bakery',
        langCode: 'en',
      );
      expect(en!.subcategory, 'bakery');

      final fr = await parser.parse(
        '20 pour nourriture sous-catégorie boulangerie',
        langCode: 'fr',
      );
      expect(fr!.subcategory, 'boulangerie');

      final de = await parser.parse(
        '20 unterkategorie bäckerei',
        langCode: 'de',
      );
      expect(de!.subcategory, 'bäckerei');
    });
  });

  group('parse — invalid amount', () {
    // Regression: unlike ImageTransactionParser (amount <= 0 rejected),
    // VoiceTransactionParser only checked for null, so a misheard "0"
    // produced a partially-filled result instead of null.
    test('returns null when the parsed amount is zero', () async {
      final result = await parser.parse('gasté 0 en nada', langCode: 'es');
      expect(result, isNull);
    });
  });
}
