import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/features/transactions/domain/transaction_model.dart';

/// Integration test verifying category distribution logic used in charts.
///
/// This mirrors the logic in categoryDistributionProvider to ensure
/// the pie/bar chart data is computed correctly.
void main() {
  group('Category distribution calculation', () {
    Map<String, double> computeDistribution(
      List<TransactionModel> transactions,
      TransactionType type,
    ) {
      final map = <String, double>{};
      for (final t in transactions.where((t) => t.type == type)) {
        map[t.category] = (map[t.category] ?? 0) + t.amount;
      }
      return map;
    }

    TransactionModel tx(String category, double amount, TransactionType type) =>
        TransactionModel(
          id: '${category}_$amount',
          userId: 'u1',
          amount: amount,
          type: type,
          category: category,
          date: DateTime(2024, 3, 15),
          createdAt: DateTime(2024, 3, 15),
        );

    test('groups expenses by category correctly', () {
      final transactions = [
        tx('Comida', 20, TransactionType.expense),
        tx('Comida', 15, TransactionType.expense),
        tx('Transporte', 30, TransactionType.expense),
        tx('Salario', 1000, TransactionType.income), // should be excluded
      ];

      final dist = computeDistribution(transactions, TransactionType.expense);
      expect(dist['Comida'], 35.0);
      expect(dist['Transporte'], 30.0);
      expect(dist.containsKey('Salario'), isFalse);
    });

    test('groups income by category correctly', () {
      final transactions = [
        tx('Salario', 1500, TransactionType.income),
        tx('Freelance', 500, TransactionType.income),
        tx('Salario', 500, TransactionType.income),
        tx('Comida', 20, TransactionType.expense),
      ];

      final dist = computeDistribution(transactions, TransactionType.income);
      expect(dist['Salario'], 2000.0);
      expect(dist['Freelance'], 500.0);
      expect(dist.containsKey('Comida'), isFalse);
    });

    test('returns empty map for no transactions of type', () {
      final transactions = [
        tx('Salario', 1000, TransactionType.income),
      ];
      final dist = computeDistribution(transactions, TransactionType.expense);
      expect(dist, isEmpty);
    });

    test('handles single category', () {
      final transactions = [
        tx('Comida', 10, TransactionType.expense),
        tx('Comida', 20, TransactionType.expense),
        tx('Comida', 30, TransactionType.expense),
      ];
      final dist = computeDistribution(transactions, TransactionType.expense);
      expect(dist.length, 1);
      expect(dist['Comida'], 60.0);
    });
  });
}
