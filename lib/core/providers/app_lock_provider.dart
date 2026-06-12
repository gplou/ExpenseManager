import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kAppLockKey = 'app_lock_enabled';

/// Bloqueo de la app con biometría/código del dispositivo (app lock).
///
/// Persistido en SharedPreferences. La pantalla de ajustes exige una
/// autenticación correcta ANTES de llamar a [setEnabled] con `true`; este
/// notifier solo guarda la preferencia. El bloqueo efectivo lo aplica
/// `LockGate` (lib/core/widgets/lock_gate.dart).
class AppLockNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kAppLockKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    state = AsyncData(enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAppLockKey, enabled);
  }
}

final appLockProvider =
    AsyncNotifierProvider<AppLockNotifier, bool>(AppLockNotifier.new);
