import 'transaction_categories.dart';
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

  /// Builds a [ParsedVoiceTransaction] from the JSON Gemini returns for a
  /// voice capture (see `VoiceTransactionParser`).
  ///
  /// Gemini has no `responseSchema` enforcing the prompt's requested shape,
  /// so every field is read defensively (wrong-typed values fall back to a
  /// safe default) rather than with unchecked casts — a malformed field
  /// should degrade to "couldn't understand" (amount 0), never throw.
  factory ParsedVoiceTransaction.fromAiJson(Map<String, dynamic> json) {
    final type = json['type'] == 'income'
        ? TransactionType.income
        : TransactionType.expense;
    final amount = _numOrZero(json['amount']);
    final category = _clampCategory(_stringOrNull(json['category']), type);
    final desc = _stringOrNull(json['description']);
    final subcategory = _stringOrNull(json['subcategory']);
    final isNewSubcategory = json['is_new_subcategory'] == true;
    final dateStr = _stringOrNull(json['date']);
    final date = (dateStr != null && dateStr.isNotEmpty)
        ? DateTime.tryParse(dateStr)
        : null;
    final isRecurring = json['is_recurring'] == true;
    final recurrenceType = _stringOrNull(json['recurrence_type']);
    final currency = _stringOrNull(json['currency']);

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

  static double _numOrZero(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '.')) ?? 0;
    return 0;
  }

  static String? _stringOrNull(Object? value) => value is String ? value : null;

  /// Falls back to "Otros" when [name] is one of the *other* type's
  /// built-in categories (e.g. the income-only "Regalo" returned for an
  /// expense) — the one concrete cross-contamination Gemini can produce
  /// since the prompt doesn't tie category to type. An unrecognized name is
  /// trusted as-is: it may be one of the user's own custom categories,
  /// which this factory has no visibility into.
  static String _clampCategory(String? name, TransactionType type) {
    if (name == null || name.isEmpty) return 'Otros';
    final ownNames = TransactionCategories.forType(type).map((c) => c.name);
    if (ownNames.contains(name)) return name;
    final oppositeType =
        type.isIncome ? TransactionType.expense : TransactionType.income;
    final oppositeNames =
        TransactionCategories.forType(oppositeType).map((c) => c.name);
    return oppositeNames.contains(name) ? 'Otros' : name;
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
