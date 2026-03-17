import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/features/transactions/domain/recurring_transaction_model.dart';

void main() {
  group('nextRecurrenceDate', () {
    test('weekly adds 7 days', () {
      final date = DateTime(2024, 3, 1);
      final next = nextRecurrenceDate(date, RecurrenceType.weekly);
      expect(next, DateTime(2024, 3, 8));
    });

    test('monthly advances to next month', () {
      final date = DateTime(2024, 1, 15);
      final next = nextRecurrenceDate(date, RecurrenceType.monthly);
      expect(next, DateTime(2024, 2, 15));
    });

    test('monthly from December wraps to January', () {
      final date = DateTime(2024, 12, 10);
      final next = nextRecurrenceDate(date, RecurrenceType.monthly);
      expect(next, DateTime(2025, 1, 10));
    });

    test('monthly clamps day to shorter month (Jan 31 -> Feb 28/29)', () {
      final date = DateTime(2024, 1, 31);
      final next = nextRecurrenceDate(date, RecurrenceType.monthly);
      // 2024 is a leap year, so Feb has 29 days
      expect(next, DateTime(2024, 2, 29));
    });

    test('monthly clamps day for non-leap year', () {
      final date = DateTime(2023, 1, 31);
      final next = nextRecurrenceDate(date, RecurrenceType.monthly);
      expect(next, DateTime(2023, 2, 28));
    });

    test('annual advances one year', () {
      final date = DateTime(2024, 6, 15);
      final next = nextRecurrenceDate(date, RecurrenceType.annual);
      expect(next, DateTime(2025, 6, 15));
    });

    test('annual clamps Feb 29 to Feb 28 in non-leap year', () {
      final date = DateTime(2024, 2, 29);
      final next = nextRecurrenceDate(date, RecurrenceType.annual);
      expect(next, DateTime(2025, 2, 28));
    });
  });

  group('RecurrenceType', () {
    test('has correct labels', () {
      expect(RecurrenceType.weekly.label, 'Semanal');
      expect(RecurrenceType.monthly.label, 'Mensual');
      expect(RecurrenceType.annual.label, 'Anual');
    });
  });

  group('RecurringTransactionModel.fromJson', () {
    test('parses valid JSON', () {
      final json = {
        'id': 'r1',
        'user_id': 'u1',
        'amount': 50.0,
        'type': 'expense',
        'category': 'Vivienda',
        'subcategory': null,
        'description': 'Alquiler',
        'recurrence_type': 'monthly',
        'next_occurrence': '2024-04-01',
        'created_at': '2024-03-01T00:00:00',
      };
      final model = RecurringTransactionModel.fromJson(json);
      expect(model.id, 'r1');
      expect(model.amount, 50.0);
      expect(model.recurrenceType, RecurrenceType.monthly);
      expect(model.description, 'Alquiler');
    });
  });
}
