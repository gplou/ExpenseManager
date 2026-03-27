import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/core/errors/failures.dart';

void main() {
  group('AppFailure', () {
    test('AuthFailure stores message', () {
      const failure = AuthFailure('bad credentials');
      expect(failure.message, 'bad credentials');
      expect(failure.toString(), 'bad credentials');
    });

    test('NetworkFailure stores status code', () {
      const failure = NetworkFailure('timeout', statusCode: 504);
      expect(failure.statusCode, 504);
      expect(failure.message, 'timeout');
    });

    test('ServerFailure has default message', () {
      const failure = ServerFailure();
      expect(failure.message, 'Internal server error');
    });

    test('CacheFailure has default message', () {
      const failure = CacheFailure();
      expect(failure.message, isNotEmpty);
    });

    test('ValidationFailure stores field errors', () {
      const failure = ValidationFailure('invalid', fieldErrors: {'email': 'bad'});
      expect(failure.fieldErrors?['email'], 'bad');
    });

    test('UnexpectedFailure has default message', () {
      const failure = UnexpectedFailure();
      expect(failure.message, isNotEmpty);
    });
  });

  group('AppFailureExtension.userMessage', () {
    test('AuthFailure returns its message', () {
      const failure = AuthFailure('credentials error');
      expect(failure.userMessage, 'credentials error');
    });

    test('NetworkFailure returns its message', () {
      const failure = NetworkFailure('connection failed');
      expect(failure.userMessage, 'connection failed');
    });

    test('ServerFailure returns its default message', () {
      const failure = ServerFailure();
      expect(failure.userMessage, contains('server'));
    });

    test('CacheFailure returns its default message', () {
      const failure = CacheFailure();
      expect(failure.userMessage, contains('storage'));
    });

    test('ValidationFailure returns its message', () {
      const failure = ValidationFailure('field invalid');
      expect(failure.userMessage, 'field invalid');
    });

    test('UnexpectedFailure returns its default message', () {
      const failure = UnexpectedFailure();
      expect(failure.userMessage, contains('unexpected'));
    });
  });
}
