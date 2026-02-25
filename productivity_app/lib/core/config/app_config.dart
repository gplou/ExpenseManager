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
    defaultValue: 'https://your-project.supabase.co', // Reemplaza en dev
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'your-anon-key', // Reemplaza en dev
  );

  // Entorno
  static const bool isProduction = bool.fromEnvironment('dart.vm.product');
  static const bool isDevelopment = !isProduction;
}
