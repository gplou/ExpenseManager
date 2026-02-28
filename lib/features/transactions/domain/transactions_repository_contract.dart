import 'transaction_model.dart';

class TransactionsSummary {
  const TransactionsSummary({
    required this.income,
    required this.expense,
  });

  final double income;
  final double expense;
  double get balance => income - expense;
}

abstract class TransactionsRepositoryContract {
  Future<List<TransactionModel>> getTransactions({
    required DateTime from,
    required DateTime to,
  });

  Future<TransactionModel> createTransaction(TransactionModel transaction);

  Future<void> deleteTransaction(String id);

  Future<TransactionsSummary> getSummary({
    required DateTime from,
    required DateTime to,
  });
}
