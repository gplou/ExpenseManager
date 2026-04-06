import 'package:flutter_test/flutter_test.dart';
import 'package:expense_manager/core/utils/date_helpers.dart';

void main() {
  group('dateToString', () {
    test('formats date with zero-padded month and day', () {
      expect(dateToString(DateTime(2024, 1, 5)), '2024-01-05');
    });

    test('formats date with double-digit month and day', () {
      expect(dateToString(DateTime(2024, 12, 25)), '2024-12-25');
    });

    test('formats February 29 in leap year', () {
      expect(dateToString(DateTime(2024, 2, 29)), '2024-02-29');
    });
  });
}
