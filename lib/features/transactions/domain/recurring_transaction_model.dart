import 'transaction_base.dart';
import 'transaction_model.dart';

enum RecurrenceType {
  weekly,
  monthly,
  annual;
}

/// Calcula la siguiente fecha de recurrencia a partir de [date].
DateTime nextRecurrenceDate(DateTime date, RecurrenceType type) {
  if (type == RecurrenceType.weekly) {
    return date.add(const Duration(days: 7));
  }
  if (type == RecurrenceType.annual) {
    // Anual: mismo día y mes del año siguiente, ajustando feb 29.
    final nextYear = date.year + 1;
    final lastDay = DateTime(nextYear, date.month + 1, 0).day;
    return DateTime(nextYear, date.month, date.day.clamp(1, lastDay));
  }
  // Mensual: mismo día del mes siguiente, ajustando si el mes es más corto.
  int nextMonth = date.month + 1;
  int nextYear = date.year;
  if (nextMonth > 12) {
    nextMonth = 1;
    nextYear++;
  }
  final lastDayOfNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
  return DateTime(nextYear, nextMonth, date.day.clamp(1, lastDayOfNextMonth));
}

class RecurringTransactionModel implements TransactionBase {
  const RecurringTransactionModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    required this.category,
    this.subcategory,
    this.description,
    required this.recurrenceType,
    required this.nextOccurrence,
    required this.createdAt,
  });

  final String id;
  final String userId;
  @override
  final double amount;
  @override
  final TransactionType type;
  @override
  final String category;
  @override
  final String? subcategory;
  @override
  final String? description;
  final RecurrenceType recurrenceType;
  final DateTime nextOccurrence;
  final DateTime createdAt;

  factory RecurringTransactionModel.fromJson(Map<String, dynamic> json) {
    return RecurringTransactionModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      type: TransactionType.values.byName(json['type'] as String),
      category: json['category'] as String,
      subcategory: json['subcategory'] as String?,
      description: json['description'] as String?,
      recurrenceType:
          RecurrenceType.values.byName(json['recurrence_type'] as String),
      nextOccurrence: DateTime.parse(json['next_occurrence'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
