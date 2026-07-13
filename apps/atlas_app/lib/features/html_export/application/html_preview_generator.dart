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
        ? await enhanceHtml(
            context: AiDocumentContext.fromDocument(document),
            mode: mode.apiValue,
          )
        : null;
    return writeHtml(document, enhance: enhance);
  }
}

enum HtmlPreviewMode {
  summary('summary', true),
  original('original', false);

  const HtmlPreviewMode(this.apiValue, this.requiresAi);

  final String apiValue;
  final bool requiresAi;
}
