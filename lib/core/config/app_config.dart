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
  }
}
