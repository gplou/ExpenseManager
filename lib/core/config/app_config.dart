import 'package:flutter/foundation.dart';
import 'package:expense_manager/core/utils/app_logger.dart';

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

  // AdMob — ad unit IDs de TEST de Google. Sirven como default en desarrollo;
  // validate() impide publicar un build de producción con ellos.
  static const String admobTestAndroidBannerUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String admobTestIosBannerUnitId =
      'ca-app-pub-3940256099942544/2934735716';

  static const String admobAndroidBannerUnitId = String.fromEnvironment(
    'ADMOB_ANDROID_BANNER_UNIT_ID',
    defaultValue: admobTestAndroidBannerUnitId,
  );
  static const String admobIosBannerUnitId = String.fromEnvironment(
    'ADMOB_IOS_BANNER_UNIT_ID',
    defaultValue: admobTestIosBannerUnitId,
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
  ///
  /// En producción es estricto: también falla con los AdMob ad-units de TEST
  /// o con las claves de RevenueCat/Google vacías — mejor un crash visible en
  /// la verificación pre-release que publicar con configuración de desarrollo.
  static void validate() => validateValues(
        isProd: isProduction,
        supabaseUrl: supabaseUrl,
        supabaseAnonKey: supabaseAnonKey,
        revenueCatAndroidKey: revenueCatAndroidKey,
        revenueCatIosKey: revenueCatIosKey,
        googleWebClientId: googleWebClientId,
        admobAndroidBannerUnitId: admobAndroidBannerUnitId,
        admobIosBannerUnitId: admobIosBannerUnitId,
      );

  /// Lógica de [validate] extraída con los valores como parámetros para poder
  /// testearla (los `String.fromEnvironment` no se pueden variar en tests).
  @visibleForTesting
  static void validateValues({
    required bool isProd,
    required String supabaseUrl,
    required String supabaseAnonKey,
    required String revenueCatAndroidKey,
    required String revenueCatIosKey,
    required String googleWebClientId,
    required String admobAndroidBannerUnitId,
    required String admobIosBannerUnitId,
  }) {
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

    if (isProd) {
      // Production: configuración incompleta = build no publicable.
      if (admobAndroidBannerUnitId == admobTestAndroidBannerUnitId ||
          admobIosBannerUnitId == admobTestIosBannerUnitId) {
        throw StateError(
          'Build de producción con AdMob ad-units de TEST. '
          'Define ADMOB_ANDROID_BANNER_UNIT_ID / ADMOB_IOS_BANNER_UNIT_ID '
          'en dart_defines.json.',
        );
      }
      if (revenueCatAndroidKey.isEmpty || revenueCatIosKey.isEmpty) {
        throw StateError(
          'Build de producción sin claves de RevenueCat. '
          'Define REVENUECAT_ANDROID_KEY / REVENUECAT_IOS_KEY.',
        );
      }
      if (googleWebClientId.isEmpty) {
        throw StateError(
          'Build de producción sin GOOGLE_WEB_CLIENT_ID: '
          'el inicio de sesión con Google no funcionaría.',
        );
      }
      return;
    }

    // Desarrollo: solo warnings (las claves pueden faltar al empezar).
    if (revenueCatAndroidKey.isEmpty) {
      AppLogger.log(
        '[AppConfig] REVENUECAT_ANDROID_KEY está vacío. '
        'Las compras in-app no funcionarán en Android.',
      );
    }
    if (revenueCatIosKey.isEmpty) {
      AppLogger.log(
        '[AppConfig] REVENUECAT_IOS_KEY está vacío. '
        'Las compras in-app no funcionarán en iOS.',
      );
    }
    if (googleWebClientId.isEmpty) {
      AppLogger.log(
        '[AppConfig] GOOGLE_WEB_CLIENT_ID está vacío. '
        'El inicio de sesión con Google no funcionará.',
      );
    }
  }
}
