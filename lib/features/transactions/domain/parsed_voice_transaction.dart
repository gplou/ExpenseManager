import 'transaction_model.dart';

class ParsedVoiceTransaction {
  const ParsedVoiceTransaction({
    required this.amount,
    required this.type,
    required this.category,
    this.description,
    this.subcategory,
    this.isNewSubcategory = false,
  });

  final double amount;
  final TransactionType type;
  final String category;
  final String? description;
  final String? subcategory;
  final bool isNewSubcategory;
}
