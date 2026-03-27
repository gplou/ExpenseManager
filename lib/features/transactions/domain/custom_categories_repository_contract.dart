import 'transaction_categories.dart';
import 'transaction_model.dart';

/// Contract for custom category data operations.
abstract class CustomCategoriesRepositoryContract {
  Future<List<TransactionCategory>> getByType(TransactionType type);

  Future<void> add(TransactionType type, TransactionCategory cat);

  Future<void> remove(TransactionType type, String name);
}
