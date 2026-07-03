import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiSettings {
  final String apiKey;
  final String baseUrl;
  final String modelName;
  final String bffUrl;

  const AiSettings({
    this.apiKey = '',
    this.baseUrl = 'https://api.deepseek.com/v1',
    this.modelName = 'deepseek-v4-pro',
    this.bffUrl = '',
  });

  AiSettings copyWith({
    String? apiKey,
    String? baseUrl,
    String? modelName,
    String? bffUrl,
  }) {
    return AiSettings(
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      modelName: modelName ?? this.modelName,
      bffUrl: bffUrl ?? this.bffUrl,
    );
  }
}

class AiSettingsController extends AsyncNotifier<AiSettings> {
  static const _keyApiKey = 'ai_settings_api_key';
  static const _keyBaseUrl = 'ai_settings_base_url';
  static const _keyModelName = 'ai_settings_model_name';
  static const _keyBffUrl = 'ai_settings_bff_url';

  @override
  Future<AiSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    String getPref(String key, String defaultValue) {
      final val = prefs.getString(key);
      return (val != null && val.isNotEmpty) ? val : defaultValue;
    }

    return AiSettings(
      apiKey: getPref(_keyApiKey, ''),
      baseUrl: getPref(_keyBaseUrl, 'https://api.deepseek.com/v1'),
      modelName: getPref(_keyModelName, 'deepseek-v4-pro'),
      bffUrl: prefs.getString(_keyBffUrl) ?? '',
    );
  }

  Future<void> updateSettings(AiSettings settings) async {
    state = AsyncData(settings);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyApiKey, settings.apiKey);
    await prefs.setString(_keyBaseUrl, settings.baseUrl);
    await prefs.setString(_keyModelName, settings.modelName);
    await prefs.setString(_keyBffUrl, settings.bffUrl);
  }
}

final aiSettingsProvider =
    AsyncNotifierProvider<AiSettingsController, AiSettings>(
      AiSettingsController.new,
    );
