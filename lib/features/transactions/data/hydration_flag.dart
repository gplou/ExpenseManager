import 'package:shared_preferences/shared_preferences.dart';

/// Flag persistente `pro_hydrated_{userId}`.
///
/// Invariante: el flag está a `true` **solo** mientras el store local es un
/// espejo puro de la nube (usuario PRO hidratado y sin periodos FREE
/// posteriores). [SyncNotifier] lo invalida en cuanto el usuario opera como
/// FREE (sus escrituras locales dejan de estar en la nube) y
/// [InitialSyncService] lo activa al completar la hidratación.
///
/// De ese invariante dependen decisiones de seguridad de datos:
/// - El merge del refresh en segundo plano solo infiere borrados ("no está en
///   la nube → quitar de local") cuando el flag está activo.
/// - El chequeo de datos huérfanos del arranque solo re-migra a la nube cuando
///   el flag está inactivo (local podría tener filas que la nube no conoce).
class HydrationFlag {
  const HydrationFlag._();

  static String key(String userId) => 'pro_hydrated_$userId';

  static Future<bool> isSet(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key(userId)) == true;
  }

  static Future<void> markHydrated(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key(userId), true);
  }

  static Future<void> clear(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key(userId));
  }
}
