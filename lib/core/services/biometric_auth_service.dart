import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import 'package:expense_manager/core/utils/app_logger.dart';

/// Wrapper fino sobre `local_auth` para poder sustituirlo en tests
/// (override de [biometricAuthServiceProvider]).
class BiometricAuthService {
  BiometricAuthService([LocalAuthentication? auth])
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  /// true si el dispositivo tiene biometría o credencial (PIN/patrón/código)
  /// configurada.
  Future<bool> isSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } on PlatformException catch (e) {
      AppLogger.log('[BiometricAuth] isSupported error: ${e.code}');
      return false;
    }
  }

  /// Lanza el prompt del sistema. `biometricOnly: false` permite el código del
  /// dispositivo como fallback. Devuelve false en error o cancelación — nunca
  /// lanza, para que el caller no necesite try/catch.
  Future<bool> authenticate(String localizedReason) async {
    try {
      return await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } on PlatformException catch (e) {
      AppLogger.log('[BiometricAuth] authenticate error: ${e.code}');
      return false;
    }
  }
}

final biometricAuthServiceProvider =
    Provider<BiometricAuthService>((ref) => BiometricAuthService());
