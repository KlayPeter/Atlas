import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../ai/data/ai_secrets_repository.dart';
import '../../ai/data/bff_endpoint_policy.dart';

class AiSettings {
  final String apiKey;
  final String baseUrl;
  final String modelName;
  final String bffUrl;
  final String bffAccessToken;

  const AiSettings({
    this.apiKey = '',
    this.baseUrl = '',
    this.modelName = '',
    this.bffUrl = '',
    this.bffAccessToken = '',
  });

  AiSettings copyWith({
    String? apiKey,
    String? baseUrl,
    String? modelName,
    String? bffUrl,
    String? bffAccessToken,
  }) {
    return AiSettings(
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      modelName: modelName ?? this.modelName,
      bffUrl: bffUrl ?? this.bffUrl,
      bffAccessToken: bffAccessToken ?? this.bffAccessToken,
    );
  }
}

class AiSettingsController extends AsyncNotifier<AiSettings> {
  static const _keyBaseUrl = 'ai_settings_base_url';
  static const _keyModelName = 'ai_settings_model_name';
  static const _keyBffUrl = 'ai_settings_bff_url';

  @override
  Future<AiSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    final secrets = ref.read(aiSecretsRepositoryProvider);
    String getPref(String key, String defaultValue) {
      final val = prefs.getString(key);
      return (val != null && val.isNotEmpty) ? val : defaultValue;
    }

    return AiSettings(
      apiKey: await secrets.readProviderApiKey() ?? '',
      baseUrl: getPref(_keyBaseUrl, ''),
      modelName: getPref(_keyModelName, ''),
      bffUrl: prefs.getString(_keyBffUrl) ?? '',
      bffAccessToken: await secrets.readBffAccessToken() ?? '',
    );
  }

  Future<void> updateSettings(AiSettings settings) async {
    final normalizedBffUrl = settings.bffUrl.isEmpty
        ? ''
        : validateBffUrl(settings.bffUrl);
    final normalized = settings.copyWith(bffUrl: normalizedBffUrl);
    state = AsyncData(normalized);
    final prefs = await SharedPreferences.getInstance();
    await ref
        .read(aiSecretsRepositoryProvider)
        .writeProviderApiKey(normalized.apiKey);
    await ref
        .read(aiSecretsRepositoryProvider)
        .writeBffAccessToken(normalized.bffAccessToken);
    await prefs.setString(_keyBaseUrl, normalized.baseUrl);
    await prefs.setString(_keyModelName, normalized.modelName);
    await prefs.setString(_keyBffUrl, normalized.bffUrl);
  }
}

final aiSettingsProvider =
    AsyncNotifierProvider<AiSettingsController, AiSettings>(
      AiSettingsController.new,
    );
