import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown/markdown.dart' as markdown;
import 'package:path_provider/path_provider.dart';

import '../../../domain/document/document_content.dart';
import '../../../domain/document/document_summary.dart';

final htmlExportServiceProvider = Provider<HtmlExportService>((ref) {
  return const HtmlExportService();
});

class HtmlExportService {
  const HtmlExportService();

  String buildHtml(DocumentContent document) {
    final body = document.summary.kind == DocumentKind.markdown
        ? markdown.markdownToHtml(
            document.rawText,
            extensionSet: markdown.ExtensionSet.gitHubWeb,
          )
        : document.paragraphs
              .map((paragraph) => '<p>${htmlEscape.convert(paragraph)}</p>')
              .join('\n');
    final toc = document.sections
        .map(
          (section) =>
              '<li class="level-${section.level}">${htmlEscape.convert(section.title)}</li>',
        )
        .join('\n');

    return '''
<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${htmlEscape.convert(document.summary.title)}</title>
  <style>
    :root { color-scheme: light dark; }
    body {
      margin: 0;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background: #f7f5ef;
      color: #1f2623;
      line-height: 1.72;
    }
    main { max-width: 820px; margin: 0 auto; padding: 32px 20px 56px; }
    h1, h2, h3, h4, h5, h6 { line-height: 1.25; margin-top: 1.7em; }
    pre { overflow-x: auto; padding: 16px; border-radius: 8px; background: #17201d; color: #eef8f2; }
    code { font-family: "SFMono-Regular", Consolas, monospace; }
    blockquote { margin-left: 0; padding-left: 16px; border-left: 4px solid #7aa099; color: #4b5b57; }
    table { border-collapse: collapse; display: block; overflow-x: auto; }
    th, td { border: 1px solid #cfd8d3; padding: 8px 10px; }
    img { max-width: 100%; border-radius: 8px; }
    .toc { background: #ffffffa8; border: 1px solid #d8ded9; border-radius: 8px; padding: 16px 18px; }
    .toc li { margin: 4px 0; }
    .toc .level-2 { margin-left: 16px; }
    .toc .level-3, .toc .level-4, .toc .level-5, .toc .level-6 { margin-left: 28px; }
    @media (prefers-color-scheme: dark) {
      body { background: #101614; color: #e3ebe7; }
      .toc { background: #18211e; border-color: #31413c; }
      blockquote { color: #b8c9c3; }
      th, td { border-color: #34443f; }
    }
  </style>
</head>
<body>
  <main>
    <h1>${htmlEscape.convert(document.summary.title)}</h1>
    ${toc.isEmpty ? '' : '<nav class="toc"><strong>目录</strong><ol>$toc</ol></nav>'}
    <article>$body</article>
  </main>
</body>
</html>
''';
  }

  Future<File> writeHtml(DocumentContent document) async {
    final dir = await getApplicationDocumentsDirectory();
    final exportsDir = Directory('${dir.path}/exports');
    if (!await exportsDir.exists()) {
      await exportsDir.create(recursive: true);
    }
    final safeTitle = document.summary.title
        .replaceAll(RegExp(r'[^\w\u4e00-\u9fff.-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
    final file = File(
      '${exportsDir.path}/${document.summary.id}-$safeTitle.html',
    );
    return file.writeAsString(buildHtml(document), flush: true);
  }
}
