import 'package:flutter_test/flutter_test.dart';
import 'package:expense_manager/features/transactions/domain/parsed_voice_transaction.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';

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

  group('ParsedVoiceTransaction.fromAiJson', () {
    test('maps a minimal AI JSON response', () {
      final t = ParsedVoiceTransaction.fromAiJson({
        'amount': 10.5,
        'type': 'expense',
        'category': 'Comida',
      });
      expect(t.amount, 10.5);
      expect(t.type, TransactionType.expense);
      expect(t.category, 'Comida');
      expect(t.description, isNull);
      expect(t.subcategory, isNull);
      expect(t.date, isNull);
      expect(t.isRecurring, isFalse);
    });

    test('maps type=income and full optional fields', () {
      final t = ParsedVoiceTransaction.fromAiJson({
        'amount': 1500,
        'type': 'income',
        'category': 'Salario',
        'description': 'Nómina de marzo',
        'subcategory': 'Nómina',
        'is_new_subcategory': true,
        'date': '2026-03-01',
        'is_recurring': true,
        'recurrence_type': 'monthly',
        'currency': 'EUR',
      });
      expect(t.type, TransactionType.income);
      expect(t.description, 'Nómina de marzo');
      expect(t.subcategory, 'Nómina');
      expect(t.isNewSubcategory, isTrue);
      expect(t.date, DateTime(2026, 3, 1));
      expect(t.isRecurring, isTrue);
      expect(t.recurrenceType, 'monthly');
      expect(t.currency, 'EUR');
    });

    test('any type other than "income" defaults to expense', () {
      final t = ParsedVoiceTransaction.fromAiJson({
        'amount': 5,
        'type': 'not-a-real-type',
        'category': 'Otros',
      });
      expect(t.type, TransactionType.expense);
    });

    test('treats empty strings as null/false, not literal values', () {
      final t = ParsedVoiceTransaction.fromAiJson({
        'amount': 5,
        'type': 'expense',
        'category': 'Otros',
        'description': '',
        'subcategory': '',
        'date': '',
        'currency': '',
      });
      expect(t.description, isNull);
      expect(t.subcategory, isNull);
      expect(t.date, isNull);
      expect(t.currency, isNull);
    });

    test('an unparseable date string is dropped instead of throwing', () {
      final t = ParsedVoiceTransaction.fromAiJson({
        'amount': 5,
        'type': 'expense',
        'category': 'Otros',
        'date': 'not-a-date',
      });
      expect(t.date, isNull);
    });
  });
}
