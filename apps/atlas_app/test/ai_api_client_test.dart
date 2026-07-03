import 'package:atlas_app/features/ai/data/ai_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'defaultAtlasBffUrl stays on localhost for simulator or adb reverse flows',
    () {
      expect(defaultAtlasBffUrl, 'http://127.0.0.1:8787');
    },
  );

  test('buildAiProviderHeaders omits placeholder provider settings', () {
    final headers = buildAiProviderHeaders(
      token: 'device-token',
      apiKey: 'xxx',
      baseUrl: '   ',
      modelName: 'changeme',
    );

    expect(headers, {'Authorization': 'Bearer device-token'});
  });

  test('buildAiProviderHeaders preserves real provider settings', () {
    final headers = buildAiProviderHeaders(
      token: 'device-token',
      apiKey: 'sk-real',
      baseUrl: 'https://api.deepseek.com/v1',
      modelName: 'deepseek-v4-pro',
    );

    expect(headers['Authorization'], 'Bearer device-token');
    expect(headers['x-ai-provider-api-key'], 'sk-real');
    expect(headers['x-ai-provider-base-url'], 'https://api.deepseek.com/v1');
    expect(headers['x-ai-provider-model'], 'deepseek-v4-pro');
  });
}
