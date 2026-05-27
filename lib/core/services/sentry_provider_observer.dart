import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/failures.dart';
import 'sentry_service.dart';

/// Riverpod observer that automatically reports any AsyncError to Sentry.
/// Registered in ProviderScope so no repository needs to be touched individually.
base class SentryProviderObserver extends ProviderObserver {
  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) {
    if (newValue is AsyncError) {
      final error = newValue.error;
      final stackTrace = newValue.stackTrace;
      if (error is AppFailure) {
        SentryService.captureFailure(error, stackTrace: stackTrace);
      } else {
        SentryService.captureException(error, stackTrace: stackTrace);
      }
    }
  }
}
