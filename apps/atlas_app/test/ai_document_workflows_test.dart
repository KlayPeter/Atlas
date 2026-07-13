import 'package:atlas_app/domain/document/document_content.dart';
import 'package:atlas_app/domain/document/document_summary.dart';
import 'package:atlas_app/features/ai/application/ai_document_workflows.dart';
import 'package:atlas_app/features/ai/application/ai_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'summary covers a bounded set of long-document chunks and discloses sampling',
    () async {
      final contexts = <AiDocumentContext>[];

      final result = await summarizeFullDocument(
        _document('Atlas. ' * 20000),
        summarize: (context) async {
          contexts.add(context);
          return AiResult(title: '总结', body: 'summary ${contexts.length}');
        },
      );

      expect(contexts, hasLength(5));
      expect(contexts.last.excerpt, contains('[分段总结 1]'));
      expect(result.body, startsWith('> 文档较长，本次基于分布在全文的 4 个代表性片段生成。'));
    },
  );

  test(
    'question workflow synthesizes chunk answers before streaming the final answer',
    () async {
      var partialCalls = 0;
      AiDocumentContext? finalContext;

      final chunks = await askFullDocument(
        _document('Atlas. ' * 3000),
        'Atlas 是什么？',
        ask: (context, question) async {
          partialCalls += 1;
          return AiResult(title: '问答', body: '片段 $partialCalls 的依据');
        },
        askStream: (context, question) {
          finalContext = context;
          return Stream.fromIterable(const ['综合', '答案']);
        },
      ).toList();

      expect(partialCalls, 3);
      expect(finalContext!.excerpt, contains('[各片段针对问题的分析 1]'));
      expect(chunks.join(), contains('已分 3 个片段覆盖全文'));
      expect(chunks.join(), endsWith('综合答案'));
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
