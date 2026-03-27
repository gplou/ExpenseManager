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
    this.currency,
  });

  /// Factory to create from AI-parsed JSON, eliminating duplication
  /// between VoiceTransactionParser and ImageTransactionParser.
  factory ParsedVoiceTransaction.fromAiJson(Map<String, dynamic> json) {
    final type = json['type'] == 'income'
        ? TransactionType.income
        : TransactionType.expense;
    final amount = (json['amount'] as num).toDouble();
    final category = json['category'] as String;
    final desc = json['description'] as String?;
    final subcategory = json['subcategory'] as String?;
    final isNewSubcategory = json['is_new_subcategory'] as bool? ?? false;
    final dateStr = json['date'] as String?;
    final date = (dateStr != null && dateStr.isNotEmpty)
        ? DateTime.tryParse(dateStr)
        : null;
    final isRecurring = json['is_recurring'] as bool? ?? false;
    final recurrenceType = json['recurrence_type'] as String?;
    final currency = json['currency'] as String?;

    return ParsedVoiceTransaction(
      amount: amount,
      type: type,
      category: category,
      description: (desc?.isEmpty ?? true) ? null : desc,
      subcategory: (subcategory?.isEmpty ?? true) ? null : subcategory,
      isNewSubcategory: isNewSubcategory,
      date: date,
      isRecurring: isRecurring,
      recurrenceType: recurrenceType,
      currency: (currency?.isEmpty ?? true) ? null : currency,
    );
  }

  final double amount;
  final TransactionType type;
  final String category;
  final String? description;
  final String? subcategory;
  final bool isNewSubcategory;
  final DateTime? date;
  final bool isRecurring;
  final String? recurrenceType;
  final String? currency;
}
