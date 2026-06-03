import 'package:flutter/foundation.dart';

/// Configuración global de la aplicación.
///
/// Los valores se inyectan en tiempo de compilación via --dart-define-from-file:
///   flutter run --dart-define-from-file=dart_defines.json
///   flutter build apk --dart-define-from-file=dart_defines.json
///
/// Copia dart_defines.json.example → dart_defines.json y rellena tus valores.
/// Nunca commitees dart_defines.json al repositorio.
class AppConfig {
  AppConfig._();

  static const String appName = 'Expense Manager';

  // Supabase
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  // Google OAuth — Web Client ID de Google Cloud Console
  static const String googleWebClientId =
      String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  // RevenueCat
  static const String revenueCatAndroidKey =
      String.fromEnvironment('REVENUECAT_ANDROID_KEY');
  static const String revenueCatIosKey =
      String.fromEnvironment('REVENUECAT_IOS_KEY');

  // AdMob — ad unit IDs (test IDs used by default; replace via dart-define before publishing)
  static const String admobAndroidBannerUnitId = String.fromEnvironment(
    'ADMOB_ANDROID_BANNER_UNIT_ID',
    defaultValue: 'ca-app-pub-3940256099942544/6300978111',
  );
  static const String admobIosBannerUnitId = String.fromEnvironment(
    'ADMOB_IOS_BANNER_UNIT_ID',
    defaultValue: 'ca-app-pub-3940256099942544/2934735716',
  );

  // PostHog
  static const String postHogApiKey =
      String.fromEnvironment('POSTHOG_API_KEY');
  static const String postHogHost = String.fromEnvironment(
    'POSTHOG_HOST',
    defaultValue: 'https://eu.i.posthog.com',
  );

  // Sentry
  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN');

  /// Override opcional vía --dart-define=SENTRY_ENVIRONMENT=...
  /// Si está vacío, el entorno se deriva automáticamente del build mode
  /// (ver [sentryEnvironment]). Así un build de release nunca queda marcado
  /// como `development` por olvidar el dart-define.
  static const String _sentryEnvironmentOverride =
      String.fromEnvironment('SENTRY_ENVIRONMENT');

  /// Entorno reportado a Sentry. Prioriza el override; en su defecto deriva
  /// `production` / `development` del build mode.
  static String get sentryEnvironment {
    if (_sentryEnvironmentOverride.isNotEmpty) return _sentryEnvironmentOverride;
    return isProduction ? 'production' : 'development';
  }

  // Entorno
  static const bool isProduction = bool.fromEnvironment('dart.vm.product');
  static const bool isDevelopment = !isProduction;

  /// Valida que las variables de entorno obligatorias estén presentes.
  /// Lanza [StateError] si falta alguna.
  static void validate() {
    if (supabaseUrl.isEmpty) {
      throw StateError(
        'SUPABASE_URL no está configurado.\n'
        'Ejecuta con: flutter run --dart-define-from-file=dart_defines.json',
      );
    }
    if (supabaseAnonKey.isEmpty) {
      throw StateError(
        'SUPABASE_ANON_KEY no está configurado.\n'
        'Ejecuta con: flutter run --dart-define-from-file=dart_defines.json',
      );
    }

    // RevenueCat keys — warn only (may be empty during early development).
    if (revenueCatAndroidKey.isEmpty) {
      debugPrint(
        '[AppConfig] REVENUECAT_ANDROID_KEY está vacío. '
        'Las compras in-app no funcionarán en Android.',
      );
    }
    if (revenueCatIosKey.isEmpty) {
      debugPrint(
        '[AppConfig] REVENUECAT_IOS_KEY está vacío. '
        'Las compras in-app no funcionarán en iOS.',
      );
    }
    if (googleWebClientId.isEmpty) {
      debugPrint(
        '[AppConfig] GOOGLE_WEB_CLIENT_ID está vacío. '
        'El inicio de sesión con Google no funcionará.',
      );
    }
  }
}
