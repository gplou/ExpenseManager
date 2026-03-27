import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/features/transactions/presentation/providers/transactions_provider.dart';

void main() {
  group('TransactionPeriod', () {
    test('values covers all 3 periods', () {
      expect(TransactionPeriod.values.length, 3);
      expect(TransactionPeriod.values, contains(TransactionPeriod.week));
      expect(TransactionPeriod.values, contains(TransactionPeriod.month));
      expect(TransactionPeriod.values, contains(TransactionPeriod.year));
    });
  });

  group('TransactionPeriod.dateRange', () {
    test('month: from is the first day of current month', () {
      final range = TransactionPeriod.month.dateRange;
      final now = DateTime.now();
      expect(range.from, DateTime(now.year, now.month, 1));
    });

    test('month: to is today (time stripped)', () {
      final range = TransactionPeriod.month.dateRange;
      final today = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
      expect(range.to, today);
    });

    test('year: from is January 1st of current year', () {
      final range = TransactionPeriod.year.dateRange;
      expect(range.from, DateTime(DateTime.now().year, 1, 1));
    });

    test('year: to is today (time stripped)', () {
      final range = TransactionPeriod.year.dateRange;
      final today = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
      expect(range.to, today);
    });

    test('week: from is Monday (weekday == 1)', () {
      final range = TransactionPeriod.week.dateRange;
      expect(range.from.weekday, 1);
    });

    test('week: from is not after to', () {
      final range = TransactionPeriod.week.dateRange;
      expect(range.from.isAfter(range.to), isFalse);
    });

    test('month: from is not after to', () {
      final range = TransactionPeriod.month.dateRange;
      expect(range.from.isAfter(range.to), isFalse);
    });

    test('year: from is not after to', () {
      final range = TransactionPeriod.year.dateRange;
      expect(range.from.isAfter(range.to), isFalse);
    });

    test('week: from is within the last 7 days', () {
      final range = TransactionPeriod.week.dateRange;
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      expect(range.from.isAfter(sevenDaysAgo), isTrue);
    });

    test('week: from has no time component', () {
      final range = TransactionPeriod.week.dateRange;
      expect(range.from.hour, 0);
      expect(range.from.minute, 0);
      expect(range.from.second, 0);
    });

    test('month: from has no time component', () {
      final range = TransactionPeriod.month.dateRange;
      expect(range.from.hour, 0);
      expect(range.from.minute, 0);
    });
  });
}
