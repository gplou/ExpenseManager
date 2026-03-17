import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/features/transactions/domain/parsed_voice_transaction.dart';
import 'package:productivity_app/features/transactions/domain/transaction_model.dart';

void main() {
  group('ParsedVoiceTransaction', () {
    test('creates with required fields', () {
      const t = ParsedVoiceTransaction(
        amount: 25.0,
        type: TransactionType.expense,
        category: 'Comida',
      );
      expect(t.amount, 25.0);
      expect(t.type, TransactionType.expense);
      expect(t.category, 'Comida');
      expect(t.description, isNull);
      expect(t.subcategory, isNull);
      expect(t.isNewSubcategory, isFalse);
      expect(t.isRecurring, isFalse);
      expect(t.date, isNull);
      expect(t.currency, isNull);
    });

    test('creates with all optional fields', () {
      final t = ParsedVoiceTransaction(
        amount: 100.0,
        type: TransactionType.income,
        category: 'Salario',
        description: 'Monthly',
        subcategory: 'Nómina',
        isNewSubcategory: true,
        date: DateTime(2024, 3, 1),
        isRecurring: true,
        recurrenceType: 'monthly',
        currency: 'EUR',
      );
      expect(t.description, 'Monthly');
      expect(t.subcategory, 'Nómina');
      expect(t.isNewSubcategory, isTrue);
      expect(t.isRecurring, isTrue);
      expect(t.recurrenceType, 'monthly');
      expect(t.currency, 'EUR');
    });
  });
}
