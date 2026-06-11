import 'package:flutter_test/flutter_test.dart';

import 'package:expense_manager/core/utils/app_logger.dart';

void main() {
  group('AppLogger', () {
    test('log() does not throw, with and without category', () {
      expect(() => AppLogger.log('plain message'), returnsNormally);
      expect(
        () => AppLogger.log('message', category: 'sync'),
        returnsNormally,
      );
    });

    test('log() with sentryBreadcrumb is safe when Sentry is not initialized',
        () {
      expect(
        () => AppLogger.log('msg', category: 'sync', sentryBreadcrumb: true),
        returnsNormally,
      );
    });
  });
}
