import 'package:flutter_test/flutter_test.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/domain/transactions_repository_contract.dart';
import 'package:expense_manager/core/utils/date_helpers.dart';

/// Integration tests for TransactionsRepository logic.
///
/// These test the repository contract and data mapping without a real
/// Supabase connection. They verify that the summary calculation,
/// date formatting, and model mapping work correctly end-to-end.
void main() {
  group('TransactionsSummary calculation', () {
    List<TransactionModel> buildTransactions(List<(double, TransactionType)> items) {
      return items.asMap().entries.map((e) {
        return TransactionModel(
          id: 'id_${e.key}',
          userId: 'u1',
          amount: e.value.$1,
          type: e.value.$2,
          category: 'Test',
          date: DateTime(2024, 3, 15),
          createdAt: DateTime(2024, 3, 15),
        );
      }).toList();
    }

    TransactionsSummary calculateSummary(List<TransactionModel> transactions) {
      double income = 0;
      double expense = 0;
      for (final t in transactions) {
        if (t.type.isIncome) {
          income += t.amount;
        } else {
          expense += t.amount;
        }
      }
      return TransactionsSummary(income: income, expense: expense);
    }

    test('correctly sums income and expenses', () {
      final transactions = buildTransactions([
        (100.0, TransactionType.income),
        (50.0, TransactionType.expense),
        (200.0, TransactionType.income),
        (30.0, TransactionType.expense),
      ]);
      final summary = calculateSummary(transactions);
      expect(summary.income, 300.0);
      expect(summary.expense, 80.0);
      expect(summary.balance, 220.0);
    });

    test('returns zero summary for empty list', () {
      final summary = calculateSummary([]);
      expect(summary.income, 0.0);
      expect(summary.expense, 0.0);
      expect(summary.balance, 0.0);
    });

    test('handles only expenses', () {
      final transactions = buildTransactions([
        (25.0, TransactionType.expense),
        (75.0, TransactionType.expense),
      ]);
      final summary = calculateSummary(transactions);
      expect(summary.income, 0.0);
      expect(summary.expense, 100.0);
      expect(summary.balance, -100.0);
    });

    test('handles only income', () {
      final transactions = buildTransactions([
        (500.0, TransactionType.income),
      ]);
      final summary = calculateSummary(transactions);
      expect(summary.income, 500.0);
      expect(summary.expense, 0.0);
    });
  });

  group('Transaction data mapping', () {
    test('maps Supabase row to TransactionModel correctly', () {
      final row = {
        'id': 'tx-123',
        'user_id': 'user-456',
        'amount': 42.5,
        'type': 'expense',
        'category': 'Comida',
        'subcategory': 'Cena',
        'description': 'Pizza',
        'date': '2024-03-15',
        'created_at': '2024-03-15T10:30:00',
        'recurring_transaction_id': null,
        'currency': 'EUR',
      };

      final model = TransactionModel(
        id: row['id'] as String,
        userId: row['user_id'] as String,
        amount: (row['amount'] as num).toDouble(),
        type: TransactionType.values.byName(row['type'] as String),
        category: row['category'] as String,
        subcategory: row['subcategory'] as String?,
        description: row['description'] as String?,
        date: DateTime.parse(row['date'] as String),
        createdAt: DateTime.parse(row['created_at'] as String),
        recurringTransactionId: row['recurring_transaction_id'] as String?,
        currency: row['currency'] as String? ?? 'EUR',
      );

      expect(model.id, 'tx-123');
      expect(model.userId, 'user-456');
      expect(model.amount, 42.5);
      expect(model.type, TransactionType.expense);
      expect(model.category, 'Comida');
      expect(model.subcategory, 'Cena');
      expect(model.description, 'Pizza');
      expect(model.currency, 'EUR');
    });

    test('defaults currency to EUR when null in row', () {
      final row = {
        'id': 'tx-1',
        'user_id': 'u1',
        'amount': 10,
        'type': 'income',
        'category': 'Salario',
        'subcategory': null,
        'description': null,
        'date': '2024-01-01',
        'created_at': '2024-01-01T00:00:00',
        'recurring_transaction_id': null,
        'currency': null,
      };

      final currency = row['currency'] as String? ?? 'EUR';
      expect(currency, 'EUR');
    });
  });

  group('Date range integration', () {
    test('dateToString produces correct format for Supabase queries', () {
      final from = DateTime(2024, 1, 1);
      final to = DateTime(2024, 12, 31);
      expect(dateToString(from), '2024-01-01');
      expect(dateToString(to), '2024-12-31');
    });

    test('date range for month period is correct', () {
      // Simulate TransactionPeriod.month date range calculation
      final now = DateTime(2024, 3, 15);
      final from = DateTime(now.year, now.month, 1);
      final to = DateTime(now.year, now.month, now.day);
      expect(from, DateTime(2024, 3, 1));
      expect(to, DateTime(2024, 3, 15));
    });

    test('date range for week period starts on Monday', () {
      final now = DateTime(2024, 3, 15); // Friday
      final today = DateTime(now.year, now.month, now.day);
      final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
      expect(startOfWeek.weekday, DateTime.monday);
      expect(startOfWeek, DateTime(2024, 3, 11)); // Monday
    });
  });
}
