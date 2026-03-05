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
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  Future<void> delete(String key) => _storage.delete(key: key);

  Future<void> deleteAll() => _storage.deleteAll();
}
