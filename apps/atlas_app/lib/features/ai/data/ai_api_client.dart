import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/ai/study_models.dart';
import '../application/ai_models.dart';

const defaultAtlasBffUrl = String.fromEnvironment(
  'ATLAS_BFF_URL',
  defaultValue: 'http://127.0.0.1:8787',
);

final aiApiClientProvider = Provider<AiApiClient>((ref) {
  return AiApiClient(
    Dio(
      BaseOptions(
        baseUrl: defaultAtlasBffUrl,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 45),
      ),
    ),
    defaultBffUrl: defaultAtlasBffUrl,
  );
});

class AiApiClient {
  AiApiClient(this._dio, {required this.defaultBffUrl});

  static const _tokenKey = 'atlas.auth.deviceToken';
  static const _bffUrlKey = 'ai_settings_bff_url';

  final Dio _dio;
  final String defaultBffUrl;

  Future<AiResult> explain({
    required AiDocumentContext context,
    required String selectedText,
  }) async {
    final response = await _post('/v1/ai/explain', {
      'selectedText': selectedText,
      'context': context.toJson(),
    });
    final data = response['data'] as Map<String, Object?>;
    return AiResult(
      title: data['title'] as String? ?? '解释',
      body: data['explanation'] as String? ?? '',
      points: (data['points'] as List?)?.cast<String>() ?? const [],
    );
  }

  Future<AiResult> summarize(AiDocumentContext context) async {
    final response = await _post('/v1/ai/summarize', {
      'context': context.toJson(),
      'mode': 'structured',
    });
    final data = response['data'] as Map<String, Object?>;
    return AiResult(
      title: data['title'] as String? ?? '全文总结',
      body: data['summary'] as String? ?? '',
      points: (data['keyPoints'] as List?)?.cast<String>() ?? const [],
    );
  }

  Future<AiResult> ask({
    required AiDocumentContext context,
    required String question,
  }) async {
    final response = await _post('/v1/ai/ask', {
      'question': question,
      'context': context.toJson(),
      'stream': false,
    });
    final data = response['data'] as Map<String, Object?>;
    return AiResult(
      title: '问答',
      body: data['answer'] as String? ?? '',
      points: (data['references'] as List?)?.cast<String>() ?? const [],
    );
  }

  Stream<String> askStream({
    required AiDocumentContext context,
    required String question,
  }) async* {
    final client = await _createClient();
    final headers = await _getAiHeaders();
    Response<ResponseBody> response;
    try {
      response = await client.post<ResponseBody>(
        '/v1/ai/ask',
        data: {
          'question': question,
          'context': context.toJson(),
          'stream': true,
        },
        options: Options(
          headers: {...headers, 'Accept': 'text/event-stream'},
          responseType: ResponseType.stream,
        ),
      );
    } on DioException catch (e) {
      throw Exception(_describeDioError(e));
    }

    final stream = response.data?.stream;
    if (stream == null) {
      throw Exception('AI 流式响应为空');
    }

    var eventName = '';
    await for (final line
        in stream
            .cast<List<int>>()
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (line.startsWith('event:')) {
        eventName = line.substring(6).trim();
      }
      if (line.startsWith('data:')) {
        final payload = jsonDecode(line.substring(5).trim());
        if (eventName == 'chunk') {
          yield payload['text'] as String? ?? '';
        } else if (eventName == 'error') {
          throw Exception(payload['message'] ?? 'AI 流式响应失败');
        }
      }
    }
  }

  Future<StudyResult> generateStudyQuestions({
    required AiDocumentContext context,
    String difficulty = 'basic',
  }) async {
    final response = await _post('/v1/ai/study/questions', {
      'context': context.toJson(),
      'difficulty': difficulty,
    });
    final data = response['data'] as Map<String, dynamic>;
    return StudyResult.fromJson(data);
  }

  Future<HtmlEnhanceResult> enhanceHtml({
    required AiDocumentContext context,
    String mode = 'summary',
  }) async {
    final response = await _post('/v1/exports/html/enhance', {
      'context': context.toJson(),
      'mode': mode,
    });
    final data = response['data'] as Map<String, dynamic>;
    return HtmlEnhanceResult.fromJson(data);
  }

  Future<Map<String, Object?>> _post(
    String path,
    Map<String, Object?> body,
  ) async {
    try {
      final client = await _createClient();
      final headers = await _getAiHeaders();
      final response = await client.post<Map<String, Object?>>(
        path,
        data: body,
        options: Options(headers: headers),
      );
      final data = response.data;
      if (data == null || data['ok'] != true) {
        throw Exception('AI 请求失败');
      }
      return data;
    } on DioException catch (e) {
      throw Exception(_describeDioError(e));
    }
  }

  Future<Map<String, String>> _getAiHeaders() async {
    final token = await _deviceToken();
    final prefs = await SharedPreferences.getInstance();

    final apiKey = prefs.getString('ai_settings_api_key');
    final baseUrl = prefs.getString('ai_settings_base_url');
    final modelName = prefs.getString('ai_settings_model_name');

    return buildAiProviderHeaders(
      token: token,
      apiKey: apiKey,
      baseUrl: baseUrl,
      modelName: modelName,
    );
  }

  Future<String> _deviceToken() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_tokenKey);
    if (existing != null) {
      return existing;
    }

    Response<Map<String, Object?>> response;
    try {
      final client = await _createClient();
      response = await client.post<Map<String, Object?>>('/v1/auth/device');
    } on DioException catch (e) {
      throw Exception(_describeDioError(e));
    }

    final payload = response.data?['data'] as Map<String, Object?>?;
    final token = payload?['token'] as String?;
    if (token == null) {
      throw Exception('无法获取匿名设备 token');
    }
    await prefs.setString(_tokenKey, token);
    return token;
  }

  String _describeDioError(DioException error) {
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return '网络连接失败，请检查 Atlas BFF 是否启动，或确认 `ATLAS_BFF_URL` 配置是否正确。';
    }

    final responseData = error.response?.data;
    if (responseData is Map) {
      final errorBody = responseData['error'];
      if (errorBody is Map) {
        final message = errorBody['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
    }

    return '网络异常 (${error.response?.statusCode ?? '未知错误'})';
  }

  Future<AiConnectivityReport> diagnoseConnectivity() async {
    final bffUrl = await _getBffUrl();
    final headers = await _getAiHeaders();
    final client = _clientForBaseUrl(bffUrl);
    final steps = <AiConnectivityStep>[];

    try {
      final response = await client.get<Map<String, Object?>>('/health');
      final status = response.data?['data'];
      steps.add(
        AiConnectivityStep(
          name: 'Atlas BFF /health',
          ok: true,
          detail:
              'HTTP ${response.statusCode} ${status is Map ? (status['status'] ?? '') : ''}'
                  .trim(),
        ),
      );
    } on DioException catch (error) {
      steps.add(
        AiConnectivityStep(
          name: 'Atlas BFF /health',
          ok: false,
          detail: _describeConnectivityFailure(error, bffUrl: bffUrl),
        ),
      );
      return AiConnectivityReport(bffUrl: bffUrl, steps: steps);
    }

    String token;
    try {
      final response = await client.post<Map<String, Object?>>(
        '/v1/auth/device',
      );
      final payload = response.data?['data'] as Map<String, Object?>?;
      token = payload?['token'] as String? ?? '';
      if (token.isEmpty) {
        throw Exception('空 token');
      }
      steps.add(
        AiConnectivityStep(
          name: 'Atlas BFF /v1/auth/device',
          ok: true,
          detail: 'HTTP ${response.statusCode}，成功获取设备 token',
        ),
      );
    } catch (error) {
      final detail = error is DioException
          ? _describeConnectivityFailure(error, bffUrl: bffUrl)
          : '无法获取设备 token: $error';
      steps.add(
        AiConnectivityStep(
          name: 'Atlas BFF /v1/auth/device',
          ok: false,
          detail: detail,
        ),
      );
      return AiConnectivityReport(bffUrl: bffUrl, steps: steps);
    }

    try {
      final response = await client.post<Map<String, Object?>>(
        '/v1/ai/explain',
        data: {
          'selectedText': '连通性测试',
          'context': {
            'documentId': 'connectivity_check',
            'title': 'Atlas Connectivity Check',
            'outline': '- health\n- auth\n- explain',
            'excerpt': 'This is a connectivity test for Atlas AI services.',
          },
        },
        options: Options(
          headers: {...headers, 'Authorization': 'Bearer $token'},
        ),
      );
      final data = response.data?['data'] as Map<String, Object?>?;
      final explanation = data?['explanation'] as String? ?? '';
      steps.add(
        AiConnectivityStep(
          name: 'Atlas BFF /v1/ai/explain',
          ok: true,
          detail: explanation.isEmpty
              ? 'HTTP ${response.statusCode}，请求已通但返回为空'
              : 'HTTP ${response.statusCode}，AI 返回 ${explanation.length} 字',
        ),
      );
    } on DioException catch (error) {
      steps.add(
        AiConnectivityStep(
          name: 'Atlas BFF /v1/ai/explain',
          ok: false,
          detail: _describeConnectivityFailure(error, bffUrl: bffUrl),
        ),
      );
    }

    return AiConnectivityReport(bffUrl: bffUrl, steps: steps);
  }

  Future<Dio> _createClient() async {
    final bffUrl = await _getBffUrl();
    return _clientForBaseUrl(bffUrl);
  }

  Dio _clientForBaseUrl(String baseUrl) {
    return Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: _dio.options.connectTimeout,
        receiveTimeout: _dio.options.receiveTimeout,
      ),
    );
  }

  Future<String> _getBffUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final configured = prefs.getString(_bffUrlKey)?.trim();
    if (configured != null && configured.isNotEmpty) {
      return configured;
    }
    return defaultBffUrl;
  }

  String _describeConnectivityFailure(
    DioException error, {
    required String bffUrl,
  }) {
    final baseMessage = _describeDioError(error);
    if ((error.type == DioExceptionType.connectionError ||
            error.type == DioExceptionType.connectionTimeout) &&
        bffUrl.contains('127.0.0.1')) {
      return '$baseMessage\n如果当前运行在 Android 真机，`127.0.0.1` 指向手机自身，不是你的 Mac。可使用 `adb reverse tcp:8787 tcp:8787`，或把 Atlas BFF URL 改成电脑可访问的地址。';
    }
    return baseMessage;
  }
}

class AiConnectivityReport {
  const AiConnectivityReport({required this.bffUrl, required this.steps});

  final String bffUrl;
  final List<AiConnectivityStep> steps;

  bool get ok => steps.every((step) => step.ok);

  String format() {
    final buffer = StringBuffer('Atlas BFF URL: $bffUrl\n');
    for (final step in steps) {
      buffer
        ..writeln()
        ..writeln('${step.ok ? '[OK]' : '[FAIL]'} ${step.name}')
        ..writeln(step.detail);
    }
    return buffer.toString().trimRight();
  }
}

class AiConnectivityStep {
  const AiConnectivityStep({
    required this.name,
    required this.ok,
    required this.detail,
  });

  final String name;
  final bool ok;
  final String detail;
}

Map<String, String> buildAiProviderHeaders({
  required String token,
  String? apiKey,
  String? baseUrl,
  String? modelName,
}) {
  final normalizedApiKey = _normalizeAiSettingValue(apiKey);
  final normalizedBaseUrl = _normalizeAiSettingValue(baseUrl);
  final normalizedModelName = _normalizeAiSettingValue(modelName);

  final headers = <String, String>{'Authorization': 'Bearer $token'};
  if (normalizedApiKey != null) {
    headers['x-ai-provider-api-key'] = normalizedApiKey;
  }
  if (normalizedBaseUrl != null) {
    headers['x-ai-provider-base-url'] = normalizedBaseUrl;
  }
  if (normalizedModelName != null) {
    headers['x-ai-provider-model'] = normalizedModelName;
  }

  return headers;
}

String? _normalizeAiSettingValue(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  final lowered = normalized.toLowerCase();
  const placeholderValues = {
    'xxx',
    'your-api-key',
    'your_api_key',
    'changeme',
    'change-me',
  };
  if (placeholderValues.contains(lowered)) {
    return null;
  }

  return normalized;
}
