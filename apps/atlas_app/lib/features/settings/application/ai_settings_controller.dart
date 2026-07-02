import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiSettings {
  final String apiKey;
  final String baseUrl;
  final String modelName;

  const AiSettings({
    this.apiKey = 'xxx',
    this.baseUrl = 'https://api.deepseek.com/v1',
    this.modelName = 'deepseek-v4-pro',
  });

  AiSettings copyWith({
    String? apiKey,
    String? baseUrl,
    String? modelName,
  }) {
    return AiSettings(
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      modelName: modelName ?? this.modelName,
    );
  }
}

class AiSettingsController extends AsyncNotifier<AiSettings> {
  static const _keyApiKey = 'ai_settings_api_key';
  static const _keyBaseUrl = 'ai_settings_base_url';
  static const _keyModelName = 'ai_settings_model_name';

  @override
  Future<AiSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    String getPref(String key, String defaultValue) {
      final val = prefs.getString(key);
      return (val != null && val.isNotEmpty) ? val : defaultValue;
    }
    
    return AiSettings(
      apiKey: getPref(_keyApiKey, 'xxx'),
      baseUrl: getPref(_keyBaseUrl, 'https://api.deepseek.com/v1'),
      modelName: getPref(_keyModelName, 'deepseek-v4-pro'),
    );
  }

  Future<void> updateSettings(AiSettings settings) async {
    state = AsyncData(settings);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyApiKey, settings.apiKey);
    await prefs.setString(_keyBaseUrl, settings.baseUrl);
    await prefs.setString(_keyModelName, settings.modelName);
  }
}

final aiSettingsProvider =
    AsyncNotifierProvider<AiSettingsController, AiSettings>(
  AiSettingsController.new,
);
