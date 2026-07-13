import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class SecureValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class PlatformSecureValueStore implements SecureValueStore {
  const PlatformSecureValueStore();

  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

final aiSecretsRepositoryProvider = Provider<AiSecretsRepository>((ref) {
  return const AiSecretsRepository(PlatformSecureValueStore());
});

class AiSecretsRepository {
  const AiSecretsRepository(this._store);

  static const _providerApiKey = 'atlas.secure.aiProviderApiKey';
  static const _deviceToken = 'atlas.secure.deviceToken';
  static const _legacyProviderApiKey = 'ai_settings_api_key';
  static const _legacyDeviceToken = 'atlas.auth.deviceToken';

  final SecureValueStore _store;

  Future<String?> readProviderApiKey() {
    return _readWithMigration(_providerApiKey, _legacyProviderApiKey);
  }

  Future<void> writeProviderApiKey(String value) {
    return _writeSecret(_providerApiKey, _legacyProviderApiKey, value);
  }

  Future<String?> readDeviceToken() {
    return _readWithMigration(_deviceToken, _legacyDeviceToken);
  }

  Future<void> writeDeviceToken(String value) {
    return _writeSecret(_deviceToken, _legacyDeviceToken, value);
  }

  Future<void> deleteDeviceToken() async {
    await _store.delete(_deviceToken);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyDeviceToken);
  }

  Future<String?> _readWithMigration(String secureKey, String legacyKey) async {
    final secureValue = await _store.read(secureKey);
    if (secureValue != null && secureValue.isNotEmpty) {
      return secureValue;
    }

    final prefs = await SharedPreferences.getInstance();
    final legacyValue = prefs.getString(legacyKey)?.trim();
    if (legacyValue == null || legacyValue.isEmpty) {
      return null;
    }
    await _store.write(secureKey, legacyValue);
    await prefs.remove(legacyKey);
    return legacyValue;
  }

  Future<void> _writeSecret(
    String secureKey,
    String legacyKey,
    String value,
  ) async {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      await _store.delete(secureKey);
    } else {
      await _store.write(secureKey, normalized);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(legacyKey);
  }
}
