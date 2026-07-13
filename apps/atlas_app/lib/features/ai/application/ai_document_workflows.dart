import '../../../domain/document/document_content.dart';
import 'ai_models.dart';

typedef SummarizeContext = Future<AiResult> Function(AiDocumentContext context);
typedef AskContext =
    Future<AiResult> Function(AiDocumentContext context, String question);
typedef AskContextStream =
    Stream<String> Function(AiDocumentContext context, String question);

const _maxWorkflowChunks = 4;
const _maxIntermediateLength = 2400;

Future<AiResult> summarizeFullDocument(
  DocumentContent document, {
  required SummarizeContext summarize,
}) async {
  final selection = _workflowContexts(document);
  if (selection.contexts.length == 1) {
    return summarize(selection.contexts.single);
  }

  final partials = <AiResult>[];
  for (final context in selection.contexts) {
    partials.add(await summarize(context));
  }
  final synthesisContext = AiDocumentContext.forExcerpt(
    document,
    _intermediateExcerpt('分段总结', partials.map((result) => result.body)),
  );
  final result = await summarize(synthesisContext);
  return AiResult(
    title: result.title,
    body: '> ${selection.coverageMessage}\n\n${result.body}',
    points: result.points,
  );
}

Stream<String> askFullDocument(
  DocumentContent document,
  String question, {
  required AskContext ask,
  required AskContextStream askStream,
}) async* {
  final selection = _workflowContexts(document);
  if (selection.contexts.length == 1) {
    yield* askStream(selection.contexts.single, question);
    return;
  }

  yield '> ${selection.coverageMessage}\n\n';
  final partials = <AiResult>[];
  for (final context in selection.contexts) {
    partials.add(await ask(context, question));
  }
  final synthesisContext = AiDocumentContext.forExcerpt(
    document,
    _intermediateExcerpt('各片段针对问题的分析', partials.map((result) => result.body)),
  );
  yield* askStream(synthesisContext, question);
}

({List<AiDocumentContext> contexts, String coverageMessage}) _workflowContexts(
  DocumentContent document,
) {
  final chunks = AiDocumentContext.htmlChunks(document);
  final contexts = chunks.contexts.length <= _maxWorkflowChunks
      ? chunks.contexts
      : List.generate(_maxWorkflowChunks, (index) {
          final sourceIndex =
              ((chunks.contexts.length - 1) * index / (_maxWorkflowChunks - 1))
                  .round();
          return chunks.contexts[sourceIndex];
        });
  final sampled = chunks.sampled || contexts.length < chunks.contexts.length;
  final coverage = sampled
      ? '文档较长，本次基于分布在全文的 ${contexts.length} 个代表性片段生成。'
      : '已分 ${contexts.length} 个片段覆盖全文。';
  return (contexts: contexts, coverageMessage: coverage);
}

String _intermediateExcerpt(String label, Iterable<String> values) {
  final parts = values.indexed.map((entry) {
    final body = entry.$2;
    final bounded = body.length <= _maxIntermediateLength
        ? body
        : '${body.substring(0, _maxIntermediateLength)}…';
    return '[$label ${entry.$1 + 1}]\n$bounded';
  });
  final excerpt = parts.join('\n\n');
  return excerpt.length <= AiDocumentContext.maxExcerptLength
      ? excerpt
      : excerpt.substring(0, AiDocumentContext.maxExcerptLength);
}
