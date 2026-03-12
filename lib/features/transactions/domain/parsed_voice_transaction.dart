import 'transaction_model.dart';

class ParsedVoiceTransaction {
  const ParsedVoiceTransaction({
    required this.amount,
    required this.type,
    required this.category,
    this.description,
    this.subcategory,
    this.isNewSubcategory = false,
    this.date,
    this.isRecurring = false,
    this.recurrenceType,
  });

  final double amount;
  final TransactionType type;
  final String category;
  final String? description;
  final String? subcategory;
  final bool isNewSubcategory;
  final DateTime? date;
  final bool isRecurring;
  final String? recurrenceType;
}
