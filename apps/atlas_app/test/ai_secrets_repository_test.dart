import 'package:atlas_app/features/ai/data/ai_secrets_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/memory_secure_value_store.dart';

void main() {
  test('migrates a legacy plaintext API key into secure storage', () async {
    SharedPreferences.setMockInitialValues({
      'ai_settings_api_key': 'sk-legacy',
    });
    final store = MemorySecureValueStore();
    final repository = AiSecretsRepository(store);

    expect(await repository.readProviderApiKey(), 'sk-legacy');
    expect(store.values['atlas.secure.aiProviderApiKey'], 'sk-legacy');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('ai_settings_api_key'), isFalse);
  });

  test('clearing an API key removes secure and legacy values', () async {
    SharedPreferences.setMockInitialValues({'ai_settings_api_key': 'legacy'});
    final store = MemorySecureValueStore()
      ..values['atlas.secure.aiProviderApiKey'] = 'sk-current';
    final repository = AiSecretsRepository(store);

    await repository.writeProviderApiKey('');

    expect(await repository.readProviderApiKey(), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('ai_settings_api_key'), isFalse);
  });

  test('stores the BFF enrollment token only in secure storage', () async {
    SharedPreferences.setMockInitialValues({});
    final store = MemorySecureValueStore();
    final repository = AiSecretsRepository(store);

    await repository.writeBffAccessToken('atlas-access-secret');

    expect(await repository.readBffAccessToken(), 'atlas-access-secret');
    expect(store.values['atlas.secure.bffAccessToken'], 'atlas-access-secret');
  });
}
