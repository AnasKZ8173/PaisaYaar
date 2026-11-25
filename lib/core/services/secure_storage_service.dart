import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores sensitive local preferences & session metadata securely.
class SecureStorageService {
  SecureStorageService(this._storage);

  final FlutterSecureStorage _storage;

  static const _keyLanguage = 'splitly_language_code';
  static const _keyThemeMode = 'splitly_theme_mode';
  static const _keyLastEmail = 'splitly_last_email';

  Future<String?> readLanguageCode() => _storage.read(key: _keyLanguage);
  Future<void> writeLanguageCode(String code) =>
      _storage.write(key: _keyLanguage, value: code);

  Future<String?> readThemeMode() => _storage.read(key: _keyThemeMode);
  Future<void> writeThemeMode(String mode) =>
      _storage.write(key: _keyThemeMode, value: mode);

  Future<String?> readLastEmail() => _storage.read(key: _keyLastEmail);
  Future<void> writeLastEmail(String email) =>
      _storage.write(key: _keyLastEmail, value: email);

  Future<void> clearAuthSensitive() => _storage.delete(key: _keyLastEmail);
}

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService(const FlutterSecureStorage());
});
