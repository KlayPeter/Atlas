import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/ai/study_models.dart';
import '../../../domain/document/document_content.dart';
import '../../ai/application/ai_models.dart';
import '../../ai/data/ai_api_client.dart';
import 'html_export_service.dart';

typedef HtmlEnhanceLoader =
    Future<HtmlEnhanceResult> Function({
      required AiDocumentContext context,
      String mode,
    });

typedef HtmlFileWriter =
    Future<File> Function(
      DocumentContent document, {
      HtmlEnhanceResult? enhance,
    });

final htmlPreviewGeneratorProvider = Provider<HtmlPreviewGenerator>((ref) {
  return HtmlPreviewGenerator(
    enhanceHtml: ref.read(aiApiClientProvider).enhanceHtml,
    writeHtml: ref.read(htmlExportServiceProvider).writeHtml,
  );
});

class HtmlPreviewGenerator {
  const HtmlPreviewGenerator({
    required this.enhanceHtml,
    required this.writeHtml,
  });

  final HtmlEnhanceLoader enhanceHtml;
  final HtmlFileWriter writeHtml;

  Future<File> generate(DocumentContent document, HtmlPreviewMode mode) async {
    final enhance = mode.requiresAi
        ? await _enhanceDocument(document, mode)
        : null;
    return writeHtml(document, enhance: enhance);
  }

  Future<HtmlEnhanceResult> _enhanceDocument(
    DocumentContent document,
    HtmlPreviewMode mode,
  ) async {
    final chunks = AiDocumentContext.htmlChunks(document);
    final results = <HtmlEnhanceResult>[];
    for (final context in chunks.contexts) {
      results.add(await enhanceHtml(context: context, mode: mode.apiValue));
    }
    if (results.length == 1) {
      return results.single;
    }
    return _mergeEnhancements(results, sampled: chunks.sampled);
  }

  HtmlEnhanceResult _mergeEnhancements(
    List<HtmlEnhanceResult> results, {
    required bool sampled,
  }) {
    final concepts = <String, HtmlEnhanceKeyConcept>{};
    for (final result in results) {
      for (final concept in result.keyConcepts) {
        concepts.putIfAbsent(concept.term.trim().toLowerCase(), () => concept);
      }
    }

    final coverage = sampled
        ? '本文较长，以下导读基于分布于全文的 ${results.length} 个代表性片段。'
        : '以下导读已分 ${results.length} 个片段覆盖文档内容。';
    final summaries = <String>[coverage];
    for (var index = 0; index < results.length; index += 1) {
      summaries.add('第 ${index + 1} 部分：${results[index].summary}');
    }

    return HtmlEnhanceResult(
      title: results.first.title,
      lead: '$coverage ${results.first.lead}',
      summary: summaries.join('\n'),
      rewrittenMarkdown: sampled
          ? ''
          : results
                .map((result) => result.rewrittenMarkdown.trim())
                .where((value) => value.isNotEmpty)
                .join('\n\n'),
      sections: results.expand((result) => result.sections).take(20).toList(),
      keyConcepts: concepts.values.take(20).toList(),
      questions: results.expand((result) => result.questions).take(10).toList(),
    );
  }
}

enum HtmlPreviewMode {
  readable('readable', true),
  original('original', false);

  const HtmlPreviewMode(this.apiValue, this.requiresAi);

  final String apiValue;
  final bool requiresAi;
}
