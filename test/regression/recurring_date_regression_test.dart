import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/features/transactions/domain/recurring_transaction_model.dart';

/// Regression tests for recurring date calculations.
///
/// These ensure edge cases in date arithmetic (month overflow, leap years,
/// short months) continue to work correctly after any refactoring.
void main() {
  group('Recurring date edge cases regression', () {
    test('monthly from Jan 31 -> Feb 28 (non-leap year)', () {
      final date = DateTime(2023, 1, 31);
      final next = nextRecurrenceDate(date, RecurrenceType.monthly);
      expect(next.month, 2);
      expect(next.day, 28);
    });

    test('monthly from Jan 31 -> Feb 29 (leap year)', () {
      final date = DateTime(2024, 1, 31);
      final next = nextRecurrenceDate(date, RecurrenceType.monthly);
      expect(next.month, 2);
      expect(next.day, 29);
    });

    test('monthly from March 31 -> April 30', () {
      final date = DateTime(2024, 3, 31);
      final next = nextRecurrenceDate(date, RecurrenceType.monthly);
      expect(next.month, 4);
      expect(next.day, 30);
    });

    test('monthly from Dec 31 -> Jan 31 (year rollover)', () {
      final date = DateTime(2024, 12, 31);
      final next = nextRecurrenceDate(date, RecurrenceType.monthly);
      expect(next.year, 2025);
      expect(next.month, 1);
      expect(next.day, 31);
    });

    test('annual from Feb 29 -> Feb 28 (leap to non-leap)', () {
      final date = DateTime(2024, 2, 29);
      final next = nextRecurrenceDate(date, RecurrenceType.annual);
      expect(next.year, 2025);
      expect(next.month, 2);
      expect(next.day, 28);
    });

    test('annual from Feb 28 -> Feb 28 (non-leap to non-leap)', () {
      final date = DateTime(2023, 2, 28);
      final next = nextRecurrenceDate(date, RecurrenceType.annual);
      expect(next.year, 2024);
      expect(next.month, 2);
      expect(next.day, 28);
    });

    test('weekly is always exactly 7 days', () {
      final date = DateTime(2024, 2, 28); // Wed in leap year
      final next = nextRecurrenceDate(date, RecurrenceType.weekly);
      expect(next.difference(date).inDays, 7);
      expect(next, DateTime(2024, 3, 6)); // crosses month boundary
    });

    test('weekly crosses year boundary', () {
      final date = DateTime(2024, 12, 29);
      final next = nextRecurrenceDate(date, RecurrenceType.weekly);
      expect(next.year, 2025);
      expect(next.month, 1);
      expect(next.day, 5);
    });
  });
}
