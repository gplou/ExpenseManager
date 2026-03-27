import 'recurring_transaction_model.dart';
import 'transaction_model.dart';

/// Contract for recurring transaction data operations.
abstract class RecurringTransactionsRepositoryContract {
  Future<List<RecurringTransactionModel>> getDueRecurring();

  Future<String> createRecurring({
    required double amount,
    required TransactionType type,
    required String category,
    String? subcategory,
    String? description,
    required RecurrenceType recurrenceType,
    required DateTime nextOccurrence,
  });

  Future<RecurringTransactionModel?> getById(String id);

  Future<void> updateRecurring({
    required String id,
    required double amount,
    required TransactionType type,
    required String category,
    String? subcategory,
    String? description,
    required RecurrenceType recurrenceType,
    required DateTime nextOccurrence,
  });

  Future<void> updateNextOccurrence(String id, DateTime next);

  Future<void> deleteRecurring(String id);
}
