import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../errors/failures.dart';

/// Thin wrapper around Sentry. All methods are fire-and-forget safe:
/// any Sentry error is caught and logged, never surfaced to the user.
class SentryService {
  SentryService._();

  /// Call after login. Uses only the Supabase UUID — no email or name.
  /// Fire-and-forget: returns `void`.
  static void setUser(String userId, {bool isPro = false}) {
    unawaited(() async {
      try {
        await Sentry.configureScope((scope) async {
          await scope.setUser(SentryUser(
            id: userId,
            data: {'is_pro': isPro},
          ));
        });
      } catch (e) {
        debugPrint('[Sentry] setUser error: $e');
      }
    }());
  }

  /// Call after logout to disassociate subsequent events from the user.
  static void clearUser() {
    unawaited(() async {
      try {
        await Sentry.configureScope((scope) => scope.setUser(null));
      } catch (e) {
        debugPrint('[Sentry] clearUser error: $e');
      }
    }());
  }

  /// Reports an AppFailure to Sentry with a tag for the failure type.
  static Future<void> captureFailure(
    AppFailure failure, {
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) async {
    try {
      await Sentry.captureException(
        failure,
        stackTrace: stackTrace ?? StackTrace.current,
        withScope: (scope) {
          scope.setTag('failure_type', failure.runtimeType.toString());
          if (failure case NetworkFailure(:final statusCode?)) {
            scope.setTag('status_code', '$statusCode');
          }
          if (context != null) {
            for (final entry in context.entries) {
              scope.setContexts(entry.key, entry.value);
            }
          }
        },
      );
    } catch (e) {
      debugPrint('[Sentry] captureFailure error: $e');
    }
  }

  static Future<void> captureException(
    Object error, {
    StackTrace? stackTrace,
  }) async {
    try {
      await Sentry.captureException(error, stackTrace: stackTrace);
    } catch (e) {
      debugPrint('[Sentry] captureException error: $e');
    }
  }

  static void addBreadcrumb(String message, {String? category}) {
    try {
      Sentry.addBreadcrumb(Breadcrumb(message: message, category: category));
    } catch (_) {/* silent */}
  }
}
