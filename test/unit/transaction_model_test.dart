import 'package:flutter_test/flutter_test.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';

void main() {
  group('TransactionType', () {
    test('isIncome returns true for income', () {
      expect(TransactionType.income.isIncome, isTrue);
    });

    test('isIncome returns false for expense', () {
      expect(TransactionType.expense.isIncome, isFalse);
    });

    test('isExpense returns true for expense', () {
      expect(TransactionType.expense.isExpense, isTrue);
    });

    test('isExpense returns false for income', () {
      expect(TransactionType.income.isExpense, isFalse);
    });

    test('name returns expected strings', () {
      expect(TransactionType.income.name, 'income');
      expect(TransactionType.expense.name, 'expense');
    });
  });

  group('TransactionModel', () {
    test('creates with required fields', () {
      final model = TransactionModel(
        id: '1',
        userId: 'u1',
        amount: 42.5,
        type: TransactionType.expense,
        category: 'Comida',
        date: DateTime(2024, 3, 15),
        createdAt: DateTime(2024, 3, 15),
      );
      expect(model.id, '1');
      expect(model.amount, 42.5);
      expect(model.currency, 'EUR');
      expect(model.subcategory, isNull);
      expect(model.description, isNull);
    });

    test('copyWith creates new instance with changed fields', () {
      final original = TransactionModel(
        id: '1',
        userId: 'u1',
        amount: 10,
        type: TransactionType.income,
        category: 'Salario',
        date: DateTime(2024, 1, 1),
        createdAt: DateTime(2024, 1, 1),
      );
      final updated = original.copyWith(amount: 20, category: 'Freelance');
      expect(updated.amount, 20);
      expect(updated.category, 'Freelance');
      expect(updated.id, '1'); // unchanged
      expect(updated.type, TransactionType.income); // unchanged
    });
  });
}
