/// Configuración global de la aplicación.
/// 
/// En producción, usa --dart-define para inyectar las variables:
/// flutter run --dart-define=SUPABASE_URL=tu_url --dart-define=SUPABASE_ANON_KEY=tu_key
class AppConfig {
  AppConfig._();

  static const String appName = 'Productivity App';

  // Supabase
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ufchsvyhcqfppguqxfht.supabase.co', // Reemplaza en dev
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVmY2hzdnloY3FmcHBndXF4Zmh0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIwNDQ1NTYsImV4cCI6MjA4NzYyMDU1Nn0.X-XCDXEngLC9IfkSBaCrD5sGqxUXTGVxsMiWamK96hc', // Reemplaza en dev
  );

  // Google OAuth — Web Client ID de Google Cloud Console
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '633018728869-1nmmrjl5bq00bhsbuvvah0q4co1nhn0r.apps.googleusercontent.com',
  );

  // Entorno
  static const bool isProduction = bool.fromEnvironment('dart.vm.product');
  static const bool isDevelopment = !isProduction;
}
