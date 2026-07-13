import 'package:atlas_app/domain/document/document_content.dart';
import 'package:atlas_app/domain/document/document_summary.dart';
import 'package:atlas_app/features/ai/application/ai_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('long general AI context samples the beginning, middle, and end', () {
    final source = '${'A' * 5000}${'B' * 5000}${'C' * 5000}';
    final context = AiDocumentContext.fromDocument(_document(source));

    expect(context.excerpt.length, lessThanOrEqualTo(12000));
    expect(context.excerpt, contains('[文档开头]'));
    expect(context.excerpt, contains('[文档中部]'));
    expect(context.excerpt, contains('[文档结尾]'));
    expect(context.excerpt, contains('A'));
    expect(context.excerpt, contains('B'));
    expect(context.excerpt, contains('C'));
  });

  test(
    'very long HTML analysis is bounded and distributed across the source',
    () {
      final source = List.generate(100000, (index) => '${index % 10}').join();
      final chunks = AiDocumentContext.htmlChunks(_document(source));

      expect(chunks.sampled, isTrue);
      expect(chunks.contexts, hasLength(AiDocumentContext.maxHtmlChunks));
      expect(
        chunks.contexts.every(
          (context) =>
              context.excerpt.length <= AiDocumentContext.htmlChunkLength + 32,
        ),
        isTrue,
      );
      expect(chunks.contexts.first.excerpt, contains(source.substring(0, 40)));
      expect(chunks.contexts.last.excerpt, contains(source.substring(99960)));
    },
  );
}

DocumentContent _document(String source) {
  return DocumentContent(
    summary: DocumentSummary(
      id: 'doc-1',
      title: 'Atlas',
      kind: DocumentKind.markdown,
      importedAt: DateTime(2026),
      filePath: 'prefs:doc-1',
      hash: 'hash',
    ),
    rawText: source,
    sections: const [],
    paragraphs: const [],
  );
}
