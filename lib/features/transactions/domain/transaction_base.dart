import 'transaction_model.dart';

/// Shared interface for common fields between TransactionModel
/// and RecurringTransactionModel, enabling polymorphic operations
/// on either type (e.g., category display, amount formatting).
abstract class TransactionBase {
  double get amount;
  TransactionType get type;
  String get category;
  String? get subcategory;
  String? get description;
}
