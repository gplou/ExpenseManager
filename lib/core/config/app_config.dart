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

  // Claude API — para interpretar transacciones por voz
  static const String claudeApiKey =
      String.fromEnvironment('CLAUDE_API_KEY');

  // RevenueCat
  static const String revenueCatAndroidKey =
      String.fromEnvironment('REVENUECAT_ANDROID_KEY');
  static const String revenueCatIosKey =
      String.fromEnvironment('REVENUECAT_IOS_KEY');

  // PostHog
  static const String postHogApiKey =
      String.fromEnvironment('POSTHOG_API_KEY');
  static const String postHogHost = String.fromEnvironment(
    'POSTHOG_HOST',
    defaultValue: 'https://eu.i.posthog.com',
  );

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
    if (claudeApiKey.isEmpty) {
      debugPrint(
        '[AppConfig] CLAUDE_API_KEY está vacío. '
        'Las funciones de voz, imagen y chat IA no funcionarán.',
      );
    }
  }
}
