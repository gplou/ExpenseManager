import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/core/utils/extensions.dart';

/// Regression tests for password validation.
///
/// Ensures the password validation rules (>= 8 chars, at least one letter,
/// at least one digit) remain consistent after any changes to extensions.dart.
void main() {
  group('Password validation regression', () {
    test('exactly 8 characters with letter + digit is valid', () {
      expect('abcdefg1'.isValidPassword, isTrue);
    });

    test('7 characters is too short', () {
      expect('abcdef1'.isValidPassword, isFalse);
    });

    test('all letters, no digit is invalid', () {
      expect('abcdefgh'.isValidPassword, isFalse);
    });

    test('all digits, no letter is invalid', () {
      expect('12345678'.isValidPassword, isFalse);
    });

    test('special characters + letter + digit is valid', () {
      expect('P@ss!0rd'.isValidPassword, isTrue);
    });

    test('long password is valid', () {
      expect('a1${'x' * 50}'.isValidPassword, isTrue);
    });

    test('empty string is invalid', () {
      expect(''.isValidPassword, isFalse);
    });

    test('spaces count as characters', () {
      expect('pass 12a'.isValidPassword, isTrue); // 8 chars including space
    });
  });
}
