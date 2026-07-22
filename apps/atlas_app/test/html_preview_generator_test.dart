import 'dart:io';

import 'package:atlas_app/domain/ai/study_models.dart';
import 'package:atlas_app/domain/document/document_content.dart';
import 'package:atlas_app/domain/document/document_summary.dart';
import 'package:atlas_app/features/ai/application/ai_models.dart';
import 'package:atlas_app/features/documents/application/document_content_provider.dart';
import 'package:atlas_app/features/html_export/application/html_preview_generator.dart';
import 'package:atlas_app/features/html_export/presentation/html_preview_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final document = DocumentContent(
    summary: DocumentSummary(
      id: 'doc-1',
      title: 'Atlas',
      kind: DocumentKind.markdown,
      importedAt: DateTime(2026),
      filePath: 'prefs:doc-1',
      hash: 'hash',
    ),
    rawText: '# Atlas\n\nLocal first.',
    sections: const [],
    paragraphs: const ['Local first.'],
  );

  test('original preview is generated without contacting AI', () async {
    var aiCalls = 0;
    HtmlEnhanceResult? writtenEnhancement;
    String? writtenCacheKey;
    final generator = HtmlPreviewGenerator(
      rewriteHtml:
          ({
            required AiDocumentContext context,
            required int chunkIndex,
            required int chunkCount,
          }) async {
            aiCalls += 1;
            throw StateError('AI must not run for original previews');
          },
      writeHtml: (document, {enhance, cacheKey}) async {
        writtenEnhancement = enhance;
        writtenCacheKey = cacheKey;
        return File('/tmp/atlas-original.html');
      },
    );

    final file = await generator.generate(document, HtmlPreviewMode.original);

    expect(file.path, '/tmp/atlas-original.html');
    expect(aiCalls, 0);
    expect(writtenEnhancement, isNull);
    expect(writtenCacheKey, 'Atlas-original-hash-v2');
  });

  test('readable preview rewrites chunks in order with two workers', () async {
    var aiCalls = 0;
    var activeCalls = 0;
    var maxActiveCalls = 0;
    final progress = <String>[];
    HtmlEnhanceResult? writtenEnhancement;
    final longDocument = DocumentContent(
      summary: document.summary,
      rawText: List.generate(30000, (index) => '${index % 10}').join(),
      sections: const [],
      paragraphs: const [],
    );
    final generator = HtmlPreviewGenerator(
      rewriteHtml:
          ({
            required AiDocumentContext context,
            required int chunkIndex,
            required int chunkCount,
          }) async {
            aiCalls += 1;
            activeCalls += 1;
            if (activeCalls > maxActiveCalls) maxActiveCalls = activeCalls;
            await Future<void>.delayed(const Duration(milliseconds: 10));
            activeCalls -= 1;
            return '易读正文 ${chunkIndex + 1}';
          },
      writeHtml: (document, {enhance, cacheKey}) async {
        writtenEnhancement = enhance;
        return File('/tmp/atlas-summary.html');
      },
    );

    await generator.generate(
      longDocument,
      HtmlPreviewMode.readable,
      onProgress: (completed, total) => progress.add('$completed/$total'),
    );

    expect(aiCalls, 4);
    expect(maxActiveCalls, 2);
    expect(progress.last, '4/4');
    expect(writtenEnhancement?.summary, isEmpty);
    expect(writtenEnhancement?.lead, isEmpty);
    expect(
      writtenEnhancement?.rewrittenMarkdown,
      '易读正文 1\n\n易读正文 2\n\n易读正文 3\n\n易读正文 4',
    );
  });

  test('documents beyond the rewrite limit do not spend AI tokens', () async {
    var aiCalls = 0;
    final longDocument = DocumentContent(
      summary: document.summary,
      rawText: List.filled(80000, 'x').join(),
      sections: const [],
      paragraphs: const [],
    );
    final generator = HtmlPreviewGenerator(
      rewriteHtml:
          ({
            required AiDocumentContext context,
            required int chunkIndex,
            required int chunkCount,
          }) async {
            aiCalls += 1;
            return '不应生成';
          },
      writeHtml: (document, {enhance, cacheKey}) async {
        return File('/tmp/atlas-too-long.html');
      },
    );

    await expectLater(
      generator.generate(longDocument, HtmlPreviewMode.readable),
      throwsA(isA<StateError>()),
    );

    expect(aiCalls, 0);
  });

  test('cached chunks resume without repeating successful AI work', () async {
    var aiCalls = 0;
    final cachedKeys = <String>[];
    HtmlEnhanceResult? writtenEnhancement;
    final longDocument = DocumentContent(
      summary: document.summary,
      rawText: List.filled(12000, 'x').join(),
      sections: const [],
      paragraphs: const [],
    );
    final generator = HtmlPreviewGenerator(
      rewriteHtml:
          ({
            required AiDocumentContext context,
            required int chunkIndex,
            required int chunkCount,
          }) async {
            aiCalls += 1;
            return '新段 ${chunkIndex + 1}';
          },
      readCachedRewrite: (cacheKey) async {
        return cacheKey.endsWith('part-0') ? '已缓存第 1 段' : null;
      },
      writeCachedRewrite: (cacheKey, markdown) async {
        cachedKeys.add(cacheKey);
      },
      writeHtml: (document, {enhance, cacheKey}) async {
        writtenEnhancement = enhance;
        return File('/tmp/atlas-resumed.html');
      },
    );

    await generator.generate(longDocument, HtmlPreviewMode.readable);

    expect(aiCalls, 1);
    expect(cachedKeys.single, endsWith('part-1'));
    expect(writtenEnhancement?.rewrittenMarkdown, '已缓存第 1 段\n\n新段 2');
  });

  test('cached preview skips AI and HTML generation', () async {
    var aiCalls = 0;
    var writeCalls = 0;
    String? requestedCacheKey;
    final generator = HtmlPreviewGenerator(
      rewriteHtml:
          ({
            required AiDocumentContext context,
            required int chunkIndex,
            required int chunkCount,
          }) async {
            aiCalls += 1;
            throw StateError('AI must not run for cached previews');
          },
      readCachedHtml: (cacheKey) async {
        requestedCacheKey = cacheKey;
        return File('/tmp/atlas-cached.html');
      },
      writeHtml: (document, {enhance, cacheKey}) async {
        writeCalls += 1;
        return File('/tmp/atlas-regenerated.html');
      },
    );

    final file = await generator.generate(document, HtmlPreviewMode.readable);

    expect(file.path, '/tmp/atlas-cached.html');
    expect(requestedCacheKey, 'Atlas-readable-hash-v2');
    expect(aiCalls, 0);
    expect(writeCalls, 0);
  });

  testWidgets('preview generation errors replace the loading indicator', (
    tester,
  ) async {
    final generator = HtmlPreviewGenerator(
      rewriteHtml:
          ({
            required AiDocumentContext context,
            required int chunkIndex,
            required int chunkCount,
          }) {
            throw StateError('offline');
          },
      writeHtml: (document, {enhance, cacheKey}) {
        throw StateError('disk full');
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          documentContentProvider.overrideWith((ref, id) async => document),
          htmlPreviewGeneratorProvider.overrideWithValue(generator),
        ],
        child: const MaterialApp(
          home: HtmlPreviewPage(
            exportId: 'doc-1',
            mode: HtmlPreviewMode.original,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('disk full'), findsOneWidget);
    expect(find.text('重新生成'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
