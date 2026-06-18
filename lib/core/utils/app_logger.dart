import 'package:flutter/foundation.dart';

import 'package:expense_manager/core/services/sentry_service.dart';

/// Logger mínimo de la app. Usar en lugar de `debugPrint`.
///
/// `debugPrint` SÍ imprime en builds de release (solo es un `print` con
/// throttle), así que los logs de repos/servicios acababan en el log del
/// sistema del dispositivo. Este wrapper calla en release y, opcionalmente,
/// deja un breadcrumb en Sentry para conservar contexto de diagnóstico.
class AppLogger {
  AppLogger._();

  static void log(
    String message, {
    String? category,
    bool sentryBreadcrumb = false,
  }) {
    if (kDebugMode) {
      debugPrint(category != null ? '[$category] $message' : message);
    }
    if (sentryBreadcrumb) {
      SentryService.addBreadcrumb(message, category: category);
    }
  }
}
