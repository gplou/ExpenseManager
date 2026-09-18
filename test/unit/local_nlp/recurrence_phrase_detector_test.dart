import 'package:flutter_test/flutter_test.dart';

import 'package:expense_manager/features/transactions/data/local_nlp/recurrence_phrase_detector.dart';

void main() {
  group('RecurrencePhraseDetector', () {
    test('not recurring when no phrase is found', () {
      final result = RecurrencePhraseDetector.detect('20 en comida', 'es');
      expect(result.isRecurring, isFalse);
      expect(result.recurrenceType, isNull);
    });

    test('detects weekly recurrence', () {
      expect(
        RecurrencePhraseDetector.detect('cada semana', 'es').recurrenceType,
        'weekly',
      );
      expect(
        RecurrencePhraseDetector.detect('every week', 'en').recurrenceType,
        'weekly',
      );
    });

    test('detects monthly recurrence', () {
      expect(
        RecurrencePhraseDetector.detect('cada mes', 'es').recurrenceType,
        'monthly',
      );
      expect(
        RecurrencePhraseDetector.detect('chaque mois', 'fr').recurrenceType,
        'monthly',
      );
    });

    test('detects annual recurrence', () {
      expect(
        RecurrencePhraseDetector.detect('jedes jahr', 'de').recurrenceType,
        'annual',
      );
    });

    test('a generic recurrence phrase defaults to monthly', () {
      expect(
        RecurrencePhraseDetector.detect('es recurrente', 'es').recurrenceType,
        'monthly',
      );
      expect(
        RecurrencePhraseDetector.detect('wiederkehrend', 'de').recurrenceType,
        'monthly',
      );
    });

    // Regression: 'anual' (es annual keyword) is a substring of 'manual'.
    test('does not match "anual" inside "manual"', () {
      final result = RecurrencePhraseDetector.detect(
        'compré un manual de cocina por 20 euros',
        'es',
      );
      expect(result.isRecurring, isFalse);
    });
  });
}
