import 'package:flutter_test/flutter_test.dart';
import 'package:expense_manager/features/transactions/domain/transactions_repository_contract.dart';

void main() {
  group('TransactionsSummary', () {
    test('balance is income minus expense', () {
      const summary = TransactionsSummary(income: 1000, expense: 300);
      expect(summary.balance, 700);
    });

    test('balance can be negative', () {
      const summary = TransactionsSummary(income: 200, expense: 500);
      expect(summary.balance, -300);
    });

    test('balance is zero when income equals expense', () {
      const summary = TransactionsSummary(income: 100, expense: 100);
      expect(summary.balance, 0);
    });
  });
}
