import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/ai/study_models.dart';
import '../application/ai_models.dart';
import 'ai_secrets_repository.dart';
import 'bff_endpoint_policy.dart';

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
    secrets: ref.read(aiSecretsRepositoryProvider),
  );
});

class AiApiClient {
  AiApiClient(
    this._dio, {
    required this.defaultBffUrl,
    required AiSecretsRepository secrets,
  }) : _secrets = secrets;

  static const _bffUrlKey = 'ai_settings_bff_url';

  final Dio _dio;
  final String defaultBffUrl;
  final AiSecretsRepository _secrets;

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
    Response<ResponseBody> response;
    try {
      response = await _postAskStream(context: context, question: question);
    } on DioException catch (e) {
      if (!_isInvalidDeviceTokenError(e)) {
        throw Exception(_describeDioError(e));
      }
      try {
        response = await _postAskStream(
          context: context,
          question: question,
          refreshDeviceToken: true,
        );
      } on DioException catch (retryError) {
        throw Exception(_describeDioError(retryError));
      }
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
      return await _postOnce(path, body);
    } on DioException catch (e) {
      if (_isInvalidDeviceTokenError(e)) {
        try {
          return await _postOnce(path, body, refreshDeviceToken: true);
        } on DioException catch (retryError) {
          throw Exception(_describeDioError(retryError));
        }
      }
      throw Exception(_describeDioError(e));
    }
  }

  Future<Map<String, Object?>> _postOnce(
    String path,
    Map<String, Object?> body, {
    bool refreshDeviceToken = false,
  }) async {
    final client = await _createClient();
    final headers = await _getAiHeaders(refreshDeviceToken: refreshDeviceToken);
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
  }

  Future<Response<ResponseBody>> _postAskStream({
    required AiDocumentContext context,
    required String question,
    bool refreshDeviceToken = false,
  }) async {
    final client = await _createClient();
    final headers = await _getAiHeaders(refreshDeviceToken: refreshDeviceToken);
    return client.post<ResponseBody>(
      '/v1/ai/ask',
      data: {'question': question, 'context': context.toJson(), 'stream': true},
      options: Options(
        headers: {...headers, 'Accept': 'text/event-stream'},
        responseType: ResponseType.stream,
      ),
    );
  }

  Future<Map<String, String>> _getAiHeaders({
    bool refreshDeviceToken = false,
  }) async {
    final token = await _deviceToken(refresh: refreshDeviceToken);
    final prefs = await SharedPreferences.getInstance();

    final apiKey = await _secrets.readProviderApiKey();
    final baseUrl = prefs.getString('ai_settings_base_url');
    final modelName = prefs.getString('ai_settings_model_name');

    return buildAiProviderHeaders(
      token: token,
      apiKey: apiKey,
      baseUrl: baseUrl,
      modelName: modelName,
    );
  }

  Future<String> _deviceToken({bool refresh = false}) async {
    final existing = refresh ? null : await _secrets.readDeviceToken();
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    if (refresh) {
      await _secrets.deleteDeviceToken();
    }

    Response<Map<String, Object?>> response;
    try {
      final client = await _createClient();
      final accessToken = await _secrets.readBffAccessToken();
      response = await client.post<Map<String, Object?>>(
        '/v1/auth/device',
        options: Options(
          headers: accessToken == null || accessToken.isEmpty
              ? null
              : {'x-atlas-access-token': accessToken},
        ),
      );
    } on DioException catch (e) {
      throw Exception(_describeDioError(e));
    }

    final payload = response.data?['data'] as Map<String, Object?>?;
    final token = payload?['token'] as String?;
    if (token == null) {
      throw Exception('无法获取匿名设备 token');
    }
    await _secrets.writeDeviceToken(token);
    return token;
  }

  bool _isInvalidDeviceTokenError(DioException error) {
    if (error.response?.statusCode != 401) {
      return false;
    }

    final responseData = error.response?.data;
    if (responseData is! Map) {
      return false;
    }
    final errorBody = responseData['error'];
    if (errorBody is! Map) {
      return false;
    }

    final code = errorBody['code'];
    final message = errorBody['message'];
    return code == 'UNAUTHORIZED' &&
        message is String &&
        message.toLowerCase().contains('device token');
  }

  String _describeDioError(DioException error) {
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return 'AI 连接不可用，请到设置里的 AI 模型配置检查 Atlas BFF 地址、API Key、Base URL 和模型名称。';
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
      return validateBffUrl(configured);
    }
    return validateBffUrl(defaultBffUrl);
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
  if (normalizedApiKey != null) {
    if (normalizedBaseUrl != null) {
      headers['x-ai-provider-base-url'] = normalizedBaseUrl;
    }
    if (normalizedModelName != null) {
      headers['x-ai-provider-model'] = normalizedModelName;
    }
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
