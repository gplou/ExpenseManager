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

/// Read-only operations for transactions.
abstract class TransactionReader {
  Future<List<TransactionModel>> getTransactions({
    required DateTime from,
    required DateTime to,
  });

  Future<TransactionsSummary> getSummary({
    required DateTime from,
    required DateTime to,
  });
}

/// Write operations for transactions.
abstract class TransactionWriter {
  Future<TransactionModel> createTransaction(TransactionModel transaction);

  Future<TransactionModel> updateTransaction(TransactionModel transaction);

  Future<void> deleteTransaction(String id);

  /// Inserts or updates a transaction preserving its existing [id].
  /// Used by [TransactionSyncService.migrateToCloud] to keep UUIDs intact.
  Future<void> upsertTransaction(TransactionModel transaction);
}

/// Full contract combining read and write operations.
abstract class TransactionsRepositoryContract
    implements TransactionReader, TransactionWriter {}
