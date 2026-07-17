import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../ai/data/ai_secrets_repository.dart';

class AiSettings {
  const AiSettings({this.apiKey = '', this.baseUrl = '', this.modelName = ''});

  final String apiKey;
  final String baseUrl;
  final String modelName;
}

class AiSettingsController extends AsyncNotifier<AiSettings> {
  static const _keyBaseUrl = 'ai_settings_base_url';
  static const _keyModelName = 'ai_settings_model_name';

  @override
  Future<AiSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    final secrets = ref.read(aiSecretsRepositoryProvider);
    return AiSettings(
      apiKey: await secrets.readProviderApiKey() ?? '',
      baseUrl: prefs.getString(_keyBaseUrl) ?? '',
      modelName: prefs.getString(_keyModelName) ?? '',
    );
  }

  Future<void> updateSettings(AiSettings settings) async {
    state = AsyncData(settings);
    final prefs = await SharedPreferences.getInstance();
    await ref
        .read(aiSecretsRepositoryProvider)
        .writeProviderApiKey(settings.apiKey);
    await prefs.setString(_keyBaseUrl, settings.baseUrl.trim());
    await prefs.setString(_keyModelName, settings.modelName.trim());
  }
}

final aiSettingsProvider =
    AsyncNotifierProvider<AiSettingsController, AiSettings>(
      AiSettingsController.new,
    );
