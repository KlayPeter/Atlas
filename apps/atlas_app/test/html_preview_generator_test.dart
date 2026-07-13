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
    final generator = HtmlPreviewGenerator(
      enhanceHtml:
          ({
            required AiDocumentContext context,
            String mode = 'summary',
          }) async {
            aiCalls += 1;
            throw StateError('AI must not run for original previews');
          },
      writeHtml: (document, {enhance}) async {
        writtenEnhancement = enhance;
        return File('/tmp/atlas-original.html');
      },
    );

    final file = await generator.generate(document, HtmlPreviewMode.original);

    expect(file.path, '/tmp/atlas-original.html');
    expect(aiCalls, 0);
    expect(writtenEnhancement, isNull);
  });

  test('summary preview analyzes long documents in bounded chunks', () async {
    var aiCalls = 0;
    HtmlEnhanceResult? writtenEnhancement;
    final longDocument = DocumentContent(
      summary: document.summary,
      rawText: List.generate(30000, (index) => '${index % 10}').join(),
      sections: const [],
      paragraphs: const [],
    );
    final generator = HtmlPreviewGenerator(
      enhanceHtml:
          ({
            required AiDocumentContext context,
            String mode = 'summary',
          }) async {
            aiCalls += 1;
            return HtmlEnhanceResult(
              title: 'Atlas',
              lead: '导读 $aiCalls',
              summary: '摘要 $aiCalls',
              sections: const [],
              keyConcepts: const [],
              questions: const [],
            );
          },
      writeHtml: (document, {enhance}) async {
        writtenEnhancement = enhance;
        return File('/tmp/atlas-summary.html');
      },
    );

    await generator.generate(longDocument, HtmlPreviewMode.summary);

    expect(aiCalls, 4);
    expect(writtenEnhancement?.summary, contains('第 4 部分：摘要 4'));
    expect(writtenEnhancement?.lead, contains('覆盖文档内容'));
  });

  testWidgets('preview generation errors replace the loading indicator', (
    tester,
  ) async {
    final generator = HtmlPreviewGenerator(
      enhanceHtml:
          ({required AiDocumentContext context, String mode = 'summary'}) {
            throw StateError('offline');
          },
      writeHtml: (document, {enhance}) {
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
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
