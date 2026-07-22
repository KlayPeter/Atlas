import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/ai/study_models.dart';
import '../../../domain/document/document_content.dart';
import '../../ai/application/ai_models.dart';
import '../../ai/data/ai_api_client.dart';
import 'html_export_service.dart';

typedef HtmlRewriteLoader =
    Future<String> Function({
      required AiDocumentContext context,
      required int chunkIndex,
      required int chunkCount,
    });

typedef HtmlFileWriter =
    Future<File> Function(
      DocumentContent document, {
      HtmlEnhanceResult? enhance,
      String? cacheKey,
    });

typedef CachedHtmlLoader = Future<File?> Function(String cacheKey);
typedef CachedRewriteLoader = Future<String?> Function(String cacheKey);
typedef RewriteCacheWriter =
    Future<void> Function(String cacheKey, String markdown);
typedef HtmlGenerationProgress = void Function(int completed, int total);

final htmlPreviewGeneratorProvider = Provider<HtmlPreviewGenerator>((ref) {
  final exportService = ref.read(htmlExportServiceProvider);
  return HtmlPreviewGenerator(
    rewriteHtml: ref.read(aiApiClientProvider).rewriteHtml,
    readCachedHtml: exportService.readCachedHtml,
    readCachedRewrite: exportService.readCachedRewrite,
    writeCachedRewrite: exportService.writeCachedRewrite,
    writeHtml: exportService.writeHtml,
  );
});

class HtmlPreviewGenerator {
  const HtmlPreviewGenerator({
    required this.rewriteHtml,
    required this.writeHtml,
    this.readCachedHtml,
    this.readCachedRewrite,
    this.writeCachedRewrite,
  });

  static const _maxConcurrentRewrites = 2;

  final HtmlRewriteLoader rewriteHtml;
  final HtmlFileWriter writeHtml;
  final CachedHtmlLoader? readCachedHtml;
  final CachedRewriteLoader? readCachedRewrite;
  final RewriteCacheWriter? writeCachedRewrite;

  Future<File> generate(
    DocumentContent document,
    HtmlPreviewMode mode, {
    HtmlGenerationProgress? onProgress,
  }) async {
    final cacheKey = _cacheKey(document, mode);
    final cachedFile = await readCachedHtml?.call(cacheKey);
    if (cachedFile != null) {
      return cachedFile;
    }
    final enhance = mode.requiresAi
        ? await _rewriteDocument(document, cacheKey, onProgress)
        : null;
    return writeHtml(document, enhance: enhance, cacheKey: cacheKey);
  }

  String _cacheKey(DocumentContent document, HtmlPreviewMode mode) {
    const cacheVersion = 'v2';
    final safeTitle = document.summary.title
        .replaceAll(RegExp(r'[^\w\u4e00-\u9fff.-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
    final shortenedTitle = String.fromCharCodes(safeTitle.runes.take(48));
    final contentHash = document.summary.hash.isEmpty
        ? document.summary.id
        : document.summary.hash;
    return '$shortenedTitle-${mode.apiValue}-$contentHash-$cacheVersion';
  }

  Future<HtmlEnhanceResult> _rewriteDocument(
    DocumentContent document,
    String cacheKey,
    HtmlGenerationProgress? onProgress,
  ) async {
    final chunks = _rewriteChunks(document);
    if (chunks.sampled) {
      throw StateError(
        '文档过长，AI 易读版暂时最多处理 ${AiDocumentContext.maxHtmlChunks} 个分段',
      );
    }

    final total = chunks.contexts.length;
    final results = List<String?>.filled(total, null);
    var nextIndex = 0;
    var completed = 0;

    Future<void> worker() async {
      while (nextIndex < total) {
        final index = nextIndex;
        nextIndex += 1;
        final chunkCacheKey = '$cacheKey-part-$index';
        final cached = await readCachedRewrite?.call(chunkCacheKey);
        final markdown = cached?.trim().isNotEmpty == true
            ? cached!
            : await rewriteHtml(
                context: chunks.contexts[index],
                chunkIndex: index,
                chunkCount: total,
              );
        if (cached?.trim().isNotEmpty != true) {
          await writeCachedRewrite?.call(chunkCacheKey, markdown);
        }
        results[index] = markdown;
        completed += 1;
        onProgress?.call(completed, total);
      }
    }

    final workerCount = total < _maxConcurrentRewrites
        ? total
        : _maxConcurrentRewrites;
    await Future.wait(List.generate(workerCount, (_) => worker()));

    return HtmlEnhanceResult(
      title: document.summary.title,
      lead: '',
      summary: '',
      rewrittenMarkdown: results.cast<String>().join('\n\n'),
      sections: const [],
      keyConcepts: const [],
      questions: const [],
    );
  }

  AiDocumentChunks _rewriteChunks(DocumentContent document) {
    final ranges = document.renderRanges;
    if (ranges.isEmpty || ranges.length > AiDocumentContext.maxHtmlChunks) {
      return AiDocumentContext.htmlChunks(document);
    }

    return AiDocumentChunks(
      contexts: ranges
          .map(
            (range) => AiDocumentContext.forExcerpt(
              document,
              document.rawText.substring(range.start, range.end),
            ),
          )
          .toList(growable: false),
      sampled: false,
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
