import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wrapper singleton over flutter_secure_storage.
///
/// - Android: EncryptedSharedPreferences (AES-256, hardware-backed when available)
/// - iOS: Keychain with first_unlock_this_device accessibility
///
/// Use this for any sensitive data that must survive app restarts
/// (subscription state, session tokens, etc.).
class SecureStorageService {
  SecureStorageService._();
  static final SecureStorageService instance = SecureStorageService._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    // flutter_secure_storage v10+ on Android uses custom ciphers instead of
    // EncryptedSharedPreferences, which avoids AndroidKeyStore hangs on some
    // devices after app updates. No extra options needed.
    aOptions: AndroidOptions.defaultOptions,
  );

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  Future<void> delete(String key) => _storage.delete(key: key);

  Future<void> deleteAll() => _storage.deleteAll();
}
