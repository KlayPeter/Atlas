import 'dart:convert';
import 'dart:io';

import 'package:atlas_app/features/ai/data/ai_api_client.dart';
import 'package:atlas_app/features/ai/data/ai_secrets_repository.dart';
import 'package:atlas_app/features/ai/application/ai_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/memory_secure_value_store.dart';

void main() {
  test('defaultAtlasBffUrl has a stable local fallback', () {
    expect(defaultAtlasBffUrl, 'http://127.0.0.1:8787');
  });

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

  test(
    'refreshes device token once when BFF rejects the cached token',
    () async {
      SharedPreferences.setMockInitialValues({});
      final secureStore = MemorySecureValueStore()
        ..values['atlas.secure.deviceToken'] = 'stale-token'
        ..values['atlas.secure.bffAccessToken'] = 'enrollment-secret';
      final secrets = AiSecretsRepository(secureStore);

      final authHeaders = <String?>[];
      String? enrollmentHeader;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        if (request.uri.path == '/v1/auth/device') {
          enrollmentHeader = request.headers.value('x-atlas-access-token');
          _writeJson(request.response, {
            'ok': true,
            'data': {
              'token': 'fresh-token',
              'expiresAt': '2026-08-07T00:00:00.000Z',
            },
          });
          return;
        }

        if (request.uri.path == '/v1/ai/study/questions') {
          await utf8.decoder.bind(request).join();
          final auth = request.headers.value(HttpHeaders.authorizationHeader);
          authHeaders.add(auth);

          if (auth == 'Bearer stale-token') {
            request.response.statusCode = HttpStatus.unauthorized;
            _writeJson(request.response, {
              'ok': false,
              'error': {
                'code': 'UNAUTHORIZED',
                'message': 'Missing or invalid device token',
              },
            });
            return;
          }

          _writeJson(request.response, {
            'ok': true,
            'data': {
              'difficulty': 'basic',
              'questions': [
                {
                  'question': 'What is Atlas?',
                  'referenceAnswer': 'A local-first reader.',
                },
              ],
            },
          });
          return;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final client = AiApiClient(
        Dio(),
        defaultBffUrl: baseUrl,
        secrets: secrets,
      );

      final result = await client.generateStudyQuestions(
        context: const AiDocumentContext(
          documentId: 'doc-1',
          title: 'Atlas',
          outline: 'Intro',
          excerpt: 'Atlas reads local files.',
        ),
      );

      expect(authHeaders, ['Bearer stale-token', 'Bearer fresh-token']);
      expect(enrollmentHeader, 'enrollment-secret');
      expect(await secrets.readDeviceToken(), 'fresh-token');
      expect(result.questions.single.question, 'What is Atlas?');
    },
  );
}

void _writeJson(HttpResponse response, Map<String, Object?> body) {
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(body));
  response.close();
}
