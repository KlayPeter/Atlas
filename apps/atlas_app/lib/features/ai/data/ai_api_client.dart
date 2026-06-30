import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    final token = await _deviceToken();
    final response = await _dio.post<ResponseBody>(
      '/v1/ai/ask',
      data: {'question': question, 'context': context.toJson(), 'stream': true},
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'text/event-stream',
        },
        responseType: ResponseType.stream,
      ),
    );

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

  Future<Map<String, Object?>> _post(
    String path,
    Map<String, Object?> body,
  ) async {
    final token = await _deviceToken();
    final response = await _dio.post<Map<String, Object?>>(
      path,
      data: body,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final data = response.data;
    if (data == null || data['ok'] != true) {
      throw Exception('AI 请求失败');
    }
    return data;
  }

  Future<String> _deviceToken() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_tokenKey);
    if (existing != null) {
      return existing;
    }

    final response = await _dio.post<Map<String, Object?>>('/v1/auth/device');
    final payload = response.data?['data'] as Map<String, Object?>?;
    final token = payload?['token'] as String?;
    if (token == null) {
      throw Exception('无法获取匿名设备 token');
    }
    await prefs.setString(_tokenKey, token);
    return token;
  }
}
