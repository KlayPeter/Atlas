import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/ai/study_models.dart';
import '../application/ai_models.dart';

final aiApiClientProvider = Provider<AiApiClient>((ref) {
  return AiApiClient(
    Dio(
      BaseOptions(
        baseUrl: const String.fromEnvironment(
          'ATLAS_BFF_URL',
          defaultValue: 'http://127.0.0.1:8787',
        ),
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 45),
      ),
    ),
  );
});

class AiApiClient {
  AiApiClient(this._dio);

  static const _tokenKey = 'atlas.auth.deviceToken';

  final Dio _dio;

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
    final headers = await _getAiHeaders();
    Response<ResponseBody> response;
    try {
      response = await _dio.post<ResponseBody>(
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
      final headers = await _getAiHeaders();
      final response = await _dio.post<Map<String, Object?>>(
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
      response = await _dio.post<Map<String, Object?>>('/v1/auth/device');
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
