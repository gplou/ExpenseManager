import 'package:flutter_test/flutter_test.dart';
import 'package:expense_manager/core/utils/extensions.dart';

void main() {
  group('StringExtensions', () {
    group('isValidEmail', () {
      test('accepts standard email', () {
        expect('user@example.com'.isValidEmail, isTrue);
      });

      test('accepts email with subdomain', () {
        expect('user@mail.example.com'.isValidEmail, isTrue);
      });

      test('accepts email with plus tag', () {
        expect('user+tag@example.com'.isValidEmail, isTrue);
      });

      test('rejects email without domain', () {
        expect('user@'.isValidEmail, isFalse);
      });

      test('rejects email without @', () {
        expect('userexample.com'.isValidEmail, isFalse);
      });

      test('rejects empty string', () {
        expect(''.isValidEmail, isFalse);
      });

      test('rejects email with trailing script tag (V5 fix)', () {
        expect('user@example.com<script>'.isValidEmail, isFalse);
      });

      test('rejects email with spaces', () {
        expect('user @example.com'.isValidEmail, isFalse);
      });

      test('rejects email with single char TLD', () {
        expect('user@example.c'.isValidEmail, isFalse);
      });
    });

    group('isValidPassword', () {
      test('accepts valid password with letter and digit', () {
        expect('password1'.isValidPassword, isTrue);
      });

      test('rejects password shorter than 8 chars', () {
        expect('pass1'.isValidPassword, isFalse);
      });

      test('rejects password without digits', () {
        expect('password'.isValidPassword, isFalse);
      });

      test('rejects password without letters', () {
        expect('12345678'.isValidPassword, isFalse);
      });

      test('accepts complex password', () {
        expect('P@ssw0rd!'.isValidPassword, isTrue);
      });
    });

    group('capitalize', () {
      test('capitalizes first letter', () {
        expect('hello'.capitalize, 'Hello');
      });

      test('returns empty string for empty input', () {
        expect(''.capitalize, '');
      });

      test('handles single character', () {
        expect('a'.capitalize, 'A');
      });
    });

    group('truncate', () {
      test('truncates long string', () {
        expect('Hello World'.truncate(5), 'Hello...');
      });

      test('does not truncate short string', () {
        expect('Hi'.truncate(5), 'Hi');
      });

      test('uses custom ellipsis', () {
        expect('Hello World'.truncate(5, ellipsis: '…'), 'Hello…');
      });
    });
  });

  group('DateTimeExtensions', () {
    test('formattedDate returns dd/MM/yyyy', () {
      final date = DateTime(2024, 3, 15);
      expect(date.formattedDate, '15/03/2024');
    });

    test('isToday returns true for today', () {
      expect(DateTime.now().isToday, isTrue);
    });

    test('isToday returns false for yesterday', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(yesterday.isToday, isFalse);
    });

    test('isTomorrow returns true for tomorrow', () {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(tomorrow.isTomorrow, isTrue);
    });

    test('isOverdue returns true for past date', () {
      final past = DateTime.now().subtract(const Duration(days: 1));
      expect(past.isOverdue, isTrue);
    });

    test('isOverdue returns false for future date', () {
      final future = DateTime.now().add(const Duration(days: 1));
      expect(future.isOverdue, isFalse);
    });
  });
}
