import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:expense_manager/core/config/app_config.dart';

/// `beforeSend` filter for the Sentry SDK. Extracted from `main.dart`'s
/// `_initSentry` so the noise-filtering rules can be unit tested without
/// spinning up Sentry itself.
SentryEvent? filterExpectedNoise(SentryEvent event, Hint hint) {
  final isSimulator = event.contexts.device?.simulator ?? false;
  if (isSimulator) {
    // Los reportes de "OnePlus8Pro" con pantalla 288x448 / archs x86 provienen
    // de emuladores y granjas de testing (pre-launch report de Google Play,
    // revisores de tiendas) que falsifican el modelo. Corre tras el
    // enriquecido nativo, así que device.simulator ya está poblado aquí.
    if (AppConfig.isProduction) return null; // descartar ruido en prod
    event.tags = {...?event.tags, 'simulator': 'true'}; // visible en dev
  }
  // Supabase auto-refreshes the session token in the background. When the
  // connection is offline/flaky this fails with a SocketException / host
  // lookup / connection-reset error — expected behaviour, not a real bug
  // worth alerting on. GoTrue only ever throws AuthRetryableFetchException
  // for exactly this class of transient network failure (see
  // GotrueFetch._handleError), after its own internal retries are
  // exhausted, so match on the type rather than enumerate every possible
  // underlying network error message.
  final exceptions = event.exceptions ?? [];
  final isOfflineAuthRefresh = exceptions.any((ex) {
    final msg = ex.value ?? '';
    if (!msg.contains('auth/v1/token')) return false;
    return (ex.type ?? '').contains('AuthRetryableFetchException') ||
        msg.contains('Failed host lookup') ||
        msg.contains('SocketException');
  });
  if (isOfflineAuthRefresh) return null;
  // Riverpod completa el `.future` de un provider que muere en pleno load
  // con este StateError (p. ej. logout/login desmonta
  // allTransactionsProvider mientras carga). Es ruido de teardown sin
  // acción posible: el awaiter o se re-construye (watch) o murió con el
  // mismo scope.
  final isProviderDisposedMidLoad = exceptions
      .any((ex) => (ex.value ?? '').contains('was disposed during loading state'));
  if (isProviderDisposedMidLoad) return null;
  return event;
}
