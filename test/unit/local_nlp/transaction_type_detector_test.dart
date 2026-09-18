import 'package:flutter_test/flutter_test.dart';

import 'package:expense_manager/features/transactions/data/local_nlp/transaction_type_detector.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';

void main() {
  group('TransactionTypeDetector', () {
    test('defaults to expense when ambiguous', () {
      expect(
        TransactionTypeDetector.detect('20 en el bar', 'es'),
        TransactionType.expense,
      );
    });

    test('detects income keywords per locale', () {
      expect(TransactionTypeDetector.detect('cobré el sueldo', 'es'),
          TransactionType.income);
      expect(TransactionTypeDetector.detect('got paid today', 'en'),
          TransactionType.income);
      expect(TransactionTypeDetector.detect("j'ai reçu mon salaire", 'fr'),
          TransactionType.income);
      expect(TransactionTypeDetector.detect('gehalt erhalten', 'de'),
          TransactionType.income);
    });

    test('falls back to English keywords for an unsupported locale', () {
      expect(TransactionTypeDetector.detect('got paid today', 'it'),
          TransactionType.income);
    });

    // Regression: 'earned' (en income keyword) is a substring of 'learned'.
    test('does not match "earned" inside "learned"', () {
      expect(
        TransactionTypeDetector.detect(
          'learned to cook, bought ingredients for 20',
          'en',
        ),
        TransactionType.expense,
      );
    });
  });
}
