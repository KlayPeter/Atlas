import 'dart:convert';
import 'dart:io';

import 'package:atlas_app/features/ai/application/ai_models.dart';
import 'package:atlas_app/features/ai/data/ai_api_client.dart';
import 'package:atlas_app/features/ai/data/ai_secrets_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/memory_secure_value_store.dart';

void main() {
  test(
    'translation calls the configured OpenAI-compatible endpoint directly',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      Map<String, dynamic>? body;
      String? authorization;

      server.listen((request) async {
        expect(request.uri.path, '/v1/chat/completions');
        authorization = request.headers.value(HttpHeaders.authorizationHeader);
        body = jsonDecode(await utf8.decoder.bind(request).join());
        _writeJson(request.response, {
          'choices': [
            {
              'message': {'content': 'Local-first reader'},
            },
          ],
        });
      });

      SharedPreferences.setMockInitialValues({
        'ai_settings_base_url':
            'http://${server.address.host}:${server.port}/v1',
        'ai_settings_model_name': 'test-model',
      });
      final secrets = AiSecretsRepository(
        MemorySecureValueStore()
          ..values['atlas.secure.aiProviderApiKey'] = 'sk-user',
      );
      final client = AiApiClient(secrets: secrets);

      final result = await client.translate(
        context: const AiDocumentContext(
          documentId: 'doc-1',
          title: 'Atlas',
          outline: '',
          excerpt: 'Atlas 是本地优先阅读器。',
        ),
        selectedText: '本地优先阅读器',
      );

      expect(authorization, 'Bearer sk-user');
      expect(body?['model'], 'test-model');
      expect(body?['messages'][0]['content'], contains('用户选中：本地优先阅读器'));
      expect(result.body, 'Local-first reader');
    },
  );

  test('study mode asks the provider for a JSON object', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    Map<String, dynamic>? body;

    server.listen((request) async {
      body = jsonDecode(await utf8.decoder.bind(request).join());
      _writeJson(request.response, {
        'choices': [
          {
            'message': {
              'content': jsonEncode({
                'questions': [
                  {'question': 'Atlas 是什么？', 'referenceAnswer': '一个阅读器。'},
                ],
              }),
            },
          },
        ],
      });
    });

    SharedPreferences.setMockInitialValues({
      'ai_settings_base_url': 'http://${server.address.host}:${server.port}',
      'ai_settings_model_name': 'test-model',
    });
    final client = AiApiClient(
      secrets: AiSecretsRepository(
        MemorySecureValueStore()
          ..values['atlas.secure.aiProviderApiKey'] = 'sk-user',
      ),
    );

    final result = await client.generateStudyQuestions(
      context: const AiDocumentContext(
        documentId: 'doc-1',
        title: 'Atlas',
        outline: '',
        excerpt: 'Atlas 是本地优先阅读器。',
      ),
    );

    expect(body?['response_format'], {'type': 'json_object'});
    expect(result.questions.single.question, 'Atlas 是什么？');
  });

  test('question streaming yields each OpenAI-compatible SSE fragment', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    String? authorization;
    Map<String, dynamic>? body;

    server.listen((request) async {
      expect(request.uri.path, '/v1/chat/completions');
      authorization = request.headers.value(HttpHeaders.authorizationHeader);
      body = jsonDecode(await utf8.decoder.bind(request).join());
      request.response.headers.contentType =
          ContentType('text', 'event-stream', charset: 'utf-8');
      request.response.write(
        'data: {"choices":[{"delta":{"content":"Atlas "}}]}\n\n'
        'data: {"choices":[{"delta":{"content":"可以直接连模型。"}}]}\n\n'
        'data: [DONE]\n\n',
      );
      await request.response.close();
    });

    SharedPreferences.setMockInitialValues({
      'ai_settings_base_url': 'http://${server.address.host}:${server.port}/v1',
      'ai_settings_model_name': 'test-model',
    });
    final client = AiApiClient(
      secrets: AiSecretsRepository(
        MemorySecureValueStore()
          ..values['atlas.secure.aiProviderApiKey'] = 'sk-user',
      ),
    );

    final fragments = <String>[];
    await for (final fragment in client.askStream(
      context: const AiDocumentContext(
        documentId: 'doc-1',
        title: 'Atlas',
        outline: '',
        excerpt: 'Atlas 是本地优先阅读器。',
      ),
      question: '如何使用 AI？',
    )) {
      fragments.add(fragment);
    }

    expect(authorization, 'Bearer sk-user');
    expect(body?['stream'], isTrue);
    expect(body?['messages'][0]['content'], contains('问题：如何使用 AI？'));
    expect(fragments.join(), 'Atlas 可以直接连模型。');
  });

  test('missing model settings explains how to continue', () async {
    SharedPreferences.setMockInitialValues({});
    final client = AiApiClient(
      secrets: AiSecretsRepository(MemorySecureValueStore()),
    );

    await expectLater(
      client.summarize(
        const AiDocumentContext(
          documentId: 'doc-1',
          title: 'Atlas',
          outline: '',
          excerpt: 'Atlas 是本地优先阅读器。',
        ),
      ),
      throwsA(isA<FormatException>()),
    );
  });
}

void _writeJson(HttpResponse response, Map<String, Object?> body) {
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(body));
  response.close();
}
