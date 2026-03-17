import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/core/utils/extensions.dart';

/// Regression tests for email validation.
///
/// These tests document and prevent known bugs from reoccurring:
/// - V5: Email regex was not anchored with $, allowing trailing garbage
///   like `user@example.com<script>` to pass validation.
void main() {
  group('Email validation regression', () {
    group('V5 fix: regex must be anchored at end', () {
      test('rejects email with trailing HTML/script', () {
        expect('user@example.com<script>alert(1)</script>'.isValidEmail, isFalse);
      });

      test('rejects email with trailing spaces', () {
        expect('user@example.com '.isValidEmail, isFalse);
      });

      test('rejects email with trailing special characters', () {
        expect('user@example.com;'.isValidEmail, isFalse);
        expect('user@example.com&'.isValidEmail, isFalse);
        expect("user@example.com'".isValidEmail, isFalse);
      });

      test('rejects email with path after TLD', () {
        expect('user@example.com/path'.isValidEmail, isFalse);
      });
    });

    group('standard valid emails still pass', () {
      test('simple email', () {
        expect('user@example.com'.isValidEmail, isTrue);
      });

      test('email with dots', () {
        expect('user.name@example.com'.isValidEmail, isTrue);
      });

      test('email with plus', () {
        expect('user+tag@example.com'.isValidEmail, isTrue);
      });

      test('email with subdomain', () {
        expect('user@mail.example.com'.isValidEmail, isTrue);
      });
    });

    group('standard invalid emails still fail', () {
      test('empty string', () {
        expect(''.isValidEmail, isFalse);
      });

      test('no @ symbol', () {
        expect('userexample.com'.isValidEmail, isFalse);
      });

      test('no domain', () {
        expect('user@'.isValidEmail, isFalse);
      });

      test('no TLD', () {
        expect('user@example'.isValidEmail, isFalse);
      });
    });
  });
}
