import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:expense_manager/core/config/sentry_filters.dart';

SentryEvent _eventWith(SentryException exception) {
  return SentryEvent(exceptions: [exception]);
}

void main() {
  group('filterExpectedNoise — AuthRetryableFetchException (EXPENSE-MANAGER-1F)',
      () {
    test('drops the exact production event (connection reset by peer)', () {
      // Reproduces Sentry issue EXPENSE-MANAGER-1F verbatim: GoTrue's
      // background auto-refresh timer failing on a flaky connection.
      final event = _eventWith(SentryException(
        type: 'AuthRetryableFetchException',
        value: 'AuthRetryableFetchException(message: ClientException: '
            'Connection reset by peer, uri=https://ufchsvyhcqfppguqxfht.supabase.co/'
            'auth/v1/token?grant_type=refresh_token, statusCode: null)',
      ));

      expect(filterExpectedNoise(event, Hint()), isNull);
    });

    test('still drops the legacy SocketException / Failed host lookup shape',
        () {
      final event = _eventWith(SentryException(
        type: 'SocketException',
        value: 'SocketException: Failed host lookup: '
            "'xyz.supabase.co' (auth/v1/token?grant_type=refresh_token)",
      ));

      expect(filterExpectedNoise(event, Hint()), isNull);
    });

    test('does NOT drop an AuthRetryableFetchException unrelated to token '
        'refresh (different endpoint)', () {
      final event = _eventWith(SentryException(
        type: 'AuthRetryableFetchException',
        value: 'AuthRetryableFetchException(message: ClientException: '
            'Connection reset by peer, uri=https://ufchsvyhcqfppguqxfht.supabase.co/'
            'auth/v1/signup, statusCode: null)',
      ));

      expect(filterExpectedNoise(event, Hint()), same(event));
    });

    test('does NOT drop an unrelated exception on the token endpoint', () {
      final event = _eventWith(SentryException(
        type: 'FormatException',
        value: 'FormatException: Unexpected character (at auth/v1/token)',
      ));

      expect(filterExpectedNoise(event, Hint()), same(event));
    });
  });

  group('filterExpectedNoise — provider disposed mid-load', () {
    test('drops the Riverpod teardown StateError', () {
      final event = _eventWith(SentryException(
        type: 'StateError',
        value: 'Bad state: allTransactionsProvider was disposed during '
            'loading state',
      ));

      expect(filterExpectedNoise(event, Hint()), isNull);
    });
  });

  group('filterExpectedNoise — unrelated exceptions', () {
    test('passes through an unrelated exception unchanged', () {
      final event = _eventWith(SentryException(
        type: 'RangeError',
        value: 'RangeError: Index out of range',
      ));

      expect(filterExpectedNoise(event, Hint()), same(event));
    });

    test('passes through an event with no exceptions unchanged', () {
      final event = SentryEvent();

      expect(filterExpectedNoise(event, Hint()), same(event));
    });
  });
}
