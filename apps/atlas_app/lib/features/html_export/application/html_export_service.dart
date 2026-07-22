import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown/markdown.dart' as markdown;
import 'package:path_provider/path_provider.dart';

import '../../../domain/ai/study_models.dart';
import '../../../domain/document/document_content.dart';
import '../../../domain/document/document_summary.dart';

final htmlExportServiceProvider = Provider<HtmlExportService>((ref) {
  return const HtmlExportService();
});

class HtmlExportService {
  const HtmlExportService();

  Future<File?> readCachedHtml(String cacheKey) async {
    final file = File(
      '${(await _exportsDirectory()).path}/${_safeFileName(cacheKey)}.html',
    );
    if (!await file.exists() || await file.length() == 0) {
      return null;
    }
    return file;
  }

  Future<String?> readCachedRewrite(String cacheKey) async {
    final file = File(
      '${(await _rewriteCacheDirectory()).path}/${_safeFileName(cacheKey)}.md',
    );
    if (!await file.exists() || await file.length() == 0) {
      return null;
    }
    return file.readAsString();
  }

  Future<void> writeCachedRewrite(String cacheKey, String markdown) async {
    final file = File(
      '${(await _rewriteCacheDirectory()).path}/${_safeFileName(cacheKey)}.md',
    );
    final temporaryFile = File('${file.path}.tmp');
    try {
      await temporaryFile.writeAsString(markdown, flush: true);
      if (await file.exists()) {
        await file.delete();
      }
      await temporaryFile.rename(file.path);
    } catch (_) {
      if (await temporaryFile.exists()) {
        await temporaryFile.delete();
      }
      rethrow;
    }
  }

  String buildHtml(DocumentContent document, {HtmlEnhanceResult? enhance}) {
    final rewrittenMarkdown = enhance?.rewrittenMarkdown.trim() ?? '';
    final usesReadableRewrite = rewrittenMarkdown.isNotEmpty;
    final rendered = usesReadableRewrite
        ? _renderMarkdown(rewrittenMarkdown)
        : document.summary.kind == DocumentKind.markdown
        ? _renderMarkdown(document.rawText)
        : _renderPlainText(document.paragraphs);

    final enhancedTitle = enhance?.title.trim();
    final title = enhancedTitle == null || enhancedTitle.isEmpty
        ? document.summary.title
        : enhancedTitle;

    var enhanceHtmlStr = '';
    final guide = enhance;
    final hasGuide =
        guide != null &&
        (guide.lead.trim().isNotEmpty ||
            guide.summary.trim().isNotEmpty ||
            guide.sections.isNotEmpty ||
            guide.keyConcepts.isNotEmpty ||
            guide.questions.isNotEmpty);
    if (hasGuide) {
      enhanceHtmlStr =
          '''
      <div class="ai-enhance">
        <h2>AI 导读</h2>
        ${guide.lead.trim().isEmpty ? '' : '<p class="lead"><strong>${htmlEscape.convert(guide.lead)}</strong></p>'}
        ${guide.summary.trim().isEmpty ? '' : '<p>${htmlEscape.convert(guide.summary)}</p>'}
        ${usesReadableRewrite ? '<p class="rewrite-note">下方正文为 AI 易读版；事实、数字与结论应与原文保持一致。需要逐字版本时请选择“原文展示”。</p>' : ''}
        ${guide.sections.where((s) => s.title.trim().isNotEmpty || s.content.trim().isNotEmpty).map((s) => '<section><h3>${htmlEscape.convert(s.title)}</h3><p>${htmlEscape.convert(s.content)}</p></section>').join('')}
        ${guide.keyConcepts.isEmpty ? '' : '<h3>核心概念</h3><ul>${guide.keyConcepts.map((k) => '<li><strong>${htmlEscape.convert(k.term)}：</strong>${htmlEscape.convert(k.definition)}</li>').join()}</ul>'}
        ${guide.questions.isEmpty ? '' : '<h3>思考题</h3><ul>${guide.questions.map((q) => '<li><strong>问题：</strong>${htmlEscape.convert(q.q)}<br><strong>参考：</strong>${htmlEscape.convert(q.a)}</li>').join()}</ul>'}
      </div>
      ''';
    } else if (usesReadableRewrite) {
      enhanceHtmlStr =
          '<p class="rewrite-note">下方正文为 AI 易读版；事实、数字与结论应与原文保持一致。需要逐字版本时请选择“原文展示”。</p>';
    }

    return '''
<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src data:; style-src 'unsafe-inline'; font-src data:; script-src 'none'; connect-src 'none'; frame-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'">
  <meta name="referrer" content="no-referrer">
  <title>${htmlEscape.convert(title)}</title>
  <style>
    :root { color-scheme: light dark; }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: ui-serif, "Noto Serif CJK SC", "Source Han Serif SC", "Songti SC", serif;
      background: #f7f5ef;
      color: #1f2623;
      font-size: 17px;
      line-height: 1.82;
      overflow-wrap: anywhere;
    }
    main { max-width: 760px; margin: 0 auto; padding: 40px 24px 72px; }
    article > *:first-child { margin-top: 0; }
    p { margin: 0.9em 0; }
    h1, h2, h3, h4, h5, h6 { line-height: 1.35; margin: 1.8em 0 0.7em; scroll-margin-top: 24px; }
    h1 { font-size: 2rem; letter-spacing: -0.02em; }
    h2 { font-size: 1.45rem; border-bottom: 1px solid #cfd8d3; padding-bottom: 0.35em; }
    h3 { font-size: 1.2rem; }
    a { color: #326b64; text-underline-offset: 0.18em; }
    pre { overflow-x: auto; padding: 16px; border-radius: 10px; background: #17201d; color: #eef8f2; line-height: 1.55; }
    code { font-family: "SFMono-Regular", Consolas, monospace; }
    :not(pre) > code { padding: 0.15em 0.35em; border-radius: 4px; background: #e5ebe7; font-size: 0.9em; }
    blockquote { margin-left: 0; padding-left: 16px; border-left: 4px solid #7aa099; color: #4b5b57; }
    table { border-collapse: collapse; display: block; overflow-x: auto; }
    th, td { border: 1px solid #cfd8d3; padding: 8px 10px; }
    img { max-width: 100%; border-radius: 8px; }
    .toc { background: #ffffffa8; border: 1px solid #d8ded9; border-radius: 8px; padding: 16px 18px; }
    .toc ol { margin-bottom: 0; }
    .toc li { margin: 4px 0; }
    .toc .level-2 { margin-left: 16px; }
    .toc .level-3, .toc .level-4, .toc .level-5, .toc .level-6 { margin-left: 28px; }
    .ai-enhance { margin: 1.5em 0; padding: 20px; border: 1px solid #cbd9d4; border-radius: 12px; background: #edf4f1; }
    .ai-enhance h2 { margin-top: 0; }
    .ai-enhance .lead { font-size: 1.05em; }
    .rewrite-note { padding: 10px 12px; border-left: 3px solid #5f8f86; background: #ffffff8a; }
    @media (max-width: 600px) { body { font-size: 16px; } main { padding: 24px 18px 48px; } }
    @media (prefers-color-scheme: dark) {
      body { background: #101614; color: #e3ebe7; }
      .toc { background: #18211e; border-color: #31413c; }
      .ai-enhance { background: #17221f; border-color: #31413c; }
      blockquote { color: #b8c9c3; }
      th, td { border-color: #34443f; }
      :not(pre) > code { background: #25312d; }
      a { color: #8fc7bd; }
    }
  </style>
</head>
<body>
  <main>
    <h1>${htmlEscape.convert(title)}</h1>
    $enhanceHtmlStr
    ${rendered.toc.isEmpty ? '' : '<nav class="toc" aria-label="文档目录"><strong>目录</strong><ol>${rendered.toc}</ol></nav>'}
    <article>${rendered.body}</article>
  </main>
</body>
</html>
''';
  }

  _RenderedDocument _renderMarkdown(String source) {
    final parser = markdown.Document(
      extensionSet: markdown.ExtensionSet.gitHubWeb,
    );
    final nodes = parser.parse(source);
    final headings = <_HtmlHeading>[];
    _prepareNodes(nodes, headings);
    final toc = headings
        .map(
          (heading) =>
              '<li class="level-${heading.level}"><a href="#${heading.id}">${htmlEscape.convert(heading.title)}</a></li>',
        )
        .join('\n');
    return _RenderedDocument(
      body: markdown.renderToHtml(nodes, enableTagfilter: true),
      toc: toc,
    );
  }

  _RenderedDocument _renderPlainText(List<String> paragraphs) {
    final body = paragraphs
        .map((paragraph) => '<p>${htmlEscape.convert(paragraph)}</p>')
        .join('\n');
    return _RenderedDocument(body: body, toc: '');
  }

  void _prepareNodes(List<markdown.Node> nodes, List<_HtmlHeading> headings) {
    for (final node in nodes) {
      if (node is! markdown.Element) {
        continue;
      }

      final level = node.tag.length == 2 && node.tag.startsWith('h')
          ? int.tryParse(node.tag.substring(1))
          : null;
      if (level != null && level >= 1 && level <= 6) {
        final id = 'section-${headings.length + 1}';
        node.generatedId = id;
        headings.add(
          _HtmlHeading(id: id, title: node.textContent, level: level),
        );
      } else if (node.tag == 'a') {
        _prepareLink(node);
      } else if (node.tag == 'img') {
        _prepareImage(node);
      }

      final children = node.children;
      if (children != null) {
        _prepareNodes(children, headings);
      }
    }
  }

  void _prepareLink(markdown.Element element) {
    final href = element.attributes['href']?.trim() ?? '';
    final normalized = href.toLowerCase();
    final safe =
        normalized.startsWith('https://') ||
        normalized.startsWith('http://') ||
        normalized.startsWith('mailto:') ||
        href.startsWith('#');
    if (!safe) {
      element.attributes.remove('href');
      element.attributes.remove('title');
      return;
    }
    if (normalized.startsWith('https://') || normalized.startsWith('http://')) {
      element.attributes['target'] = '_blank';
      element.attributes['rel'] = 'noopener noreferrer';
    }
  }

  void _prepareImage(markdown.Element element) {
    final source = element.attributes['src']?.trim() ?? '';
    final safeDataImage = RegExp(
      r'^data:image/(?:png|jpe?g|gif|webp);base64,',
      caseSensitive: false,
    ).hasMatch(source);
    if (!safeDataImage) {
      element.attributes.remove('src');
    }
    element.attributes['loading'] = 'lazy';
    element.attributes['decoding'] = 'async';
    element.attributes['referrerpolicy'] = 'no-referrer';
  }

  Future<File> writeHtml(
    DocumentContent document, {
    HtmlEnhanceResult? enhance,
    String? cacheKey,
  }) async {
    final exportsDir = await _exportsDirectory();
    final safeTitle = (enhance?.title ?? document.summary.title)
        .replaceAll(RegExp(r'[^\w\u4e00-\u9fff.-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
    final fileName = cacheKey == null
        ? '${document.summary.id}-$safeTitle'
        : _safeFileName(cacheKey);
    final file = File('${exportsDir.path}/$fileName.html');
    final temporaryFile = File('${file.path}.tmp');
    try {
      await temporaryFile.writeAsString(
        buildHtml(document, enhance: enhance),
        flush: true,
      );
      if (await file.exists()) {
        await file.delete();
      }
      return temporaryFile.rename(file.path);
    } catch (_) {
      if (await temporaryFile.exists()) {
        await temporaryFile.delete();
      }
      rethrow;
    }
  }

  Future<Directory> _exportsDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final exportsDir = Directory('${dir.path}/exports');
    if (!await exportsDir.exists()) {
      await exportsDir.create(recursive: true);
    }
    return exportsDir;
  }

  Future<Directory> _rewriteCacheDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${dir.path}/html_preview_chunks');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  String _safeFileName(String value) {
    final sanitized = value
        .replaceAll(RegExp(r'[^\w\u4e00-\u9fff.-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
    return sanitized.isEmpty ? 'atlas-html' : sanitized;
  }
}

class _RenderedDocument {
  const _RenderedDocument({required this.body, required this.toc});

  final String body;
  final String toc;
}

class _HtmlHeading {
  const _HtmlHeading({
    required this.id,
    required this.title,
    required this.level,
  });

  final String id;
  final String title;
  final int level;
}
