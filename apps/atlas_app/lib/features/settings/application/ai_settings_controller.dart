import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiSettings {
  final String apiKey;
  final String baseUrl;
  final String modelName;

  const AiSettings({
    this.apiKey = '',
    this.baseUrl = '',
    this.modelName = '',
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
    return AiSettings(
      apiKey: prefs.getString(_keyApiKey) ?? '',
      baseUrl: prefs.getString(_keyBaseUrl) ?? '',
      modelName: prefs.getString(_keyModelName) ?? '',
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
