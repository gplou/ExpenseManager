/// Marca los momentos en que la app abre a propósito una pantalla externa
/// (selector de archivos, cámara/galería, hoja de compartir, compra de
/// RevenueCat, login con Google/Apple) y espera su resultado.
///
/// Esas pantallas ponen la app en `paused`, y sin esta marca `LockGate` la
/// bloquearía y pediría biometría al volver con el archivo/foto elegido.
/// Envuelve la llamada al plugin con [run]; `LockGate` consulta [isActive].
class ExternalActivityGuard {
  ExternalActivityGuard._();

  /// Si la vuelta de la pantalla externa tarda más que esto, `LockGate`
  /// bloquea igualmente: el usuario pudo irse a otra app desde el selector y
  /// volver mucho después.
  static const maxDuration = Duration(minutes: 5);

  // Contador y no bool: dos llamadas solapadas no deben desactivar la marca
  // cuando termina la primera.
  static int _pending = 0;

  static bool get isActive => _pending > 0;

  static Future<T> run<T>(Future<T> Function() action) async {
    _pending++;
    try {
      return await action();
    } finally {
      _pending--;
    }
  }
}
