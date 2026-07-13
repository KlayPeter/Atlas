import 'package:atlas_app/domain/ai/study_models.dart';
import 'package:atlas_app/domain/document/document_content.dart';
import 'package:atlas_app/domain/document/document_summary.dart';
import 'package:atlas_app/features/html_export/application/html_export_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = HtmlExportService();

  test('creates linked heading anchors and a restrictive content policy', () {
    final html = service.buildHtml(
      _document('# 第一章\n\n正文\n\n## Details\n\nMore.'),
    );

    expect(html, contains('href="#section-1"'));
    expect(html, contains('id="section-1"'));
    expect(html, contains('href="#section-2"'));
    expect(html, contains("script-src 'none'"));
    expect(html, contains('aria-label="文档目录"'));
  });

  test('escapes raw html and removes dangerous link and image sources', () {
    final html = service.buildHtml(
      _document(
        '<script>alert(1)</script>\n\n'
        '[unsafe](javascript:alert(1))\n\n'
        '![local](file:///etc/passwd)\n\n'
        '![remote](https://images.example/cover.png)',
      ),
    );

    expect(html, isNot(contains('<script>alert(1)</script>')));
    expect(html, isNot(contains('javascript:')));
    expect(html, isNot(contains('file:///etc/passwd')));
    expect(html, isNot(contains('src="https://images.example/cover.png"')));
    expect(html, contains("img-src data:"));
    expect(html, contains('referrerpolicy="no-referrer"'));
    expect(html, contains('loading="lazy"'));
  });

  test('escapes every AI-provided field', () {
    final html = service.buildHtml(
      _document('Original.'),
      enhance: const HtmlEnhanceResult(
        title: '<img src=x onerror=alert(1)>',
        lead: '<script>lead</script>',
        summary: '<b>summary</b>',
        sections: [
          HtmlEnhanceSection(
            title: '<h1>x</h1>',
            content: '<iframe>x</iframe>',
          ),
        ],
        keyConcepts: [],
        questions: [],
      ),
    );

    expect(html, isNot(contains('<script>lead</script>')));
    expect(html, isNot(contains('<iframe>x</iframe>')));
    expect(html, contains('&lt;script&gt;lead&lt;&#47;script&gt;'));
    expect(html, contains('&lt;iframe&gt;x&lt;&#47;iframe&gt;'));
  });

  test('readable export replaces the body with safely rendered rewrite', () {
    final html = service.buildHtml(
      _document('# Dense title\n\nA difficult original paragraph.'),
      enhance: const HtmlEnhanceResult(
        title: 'Easy Atlas',
        lead: '导读',
        summary: '摘要',
        rewrittenMarkdown: '# 易读标题\n\n这是拆分并解释后的正文。',
        sections: [],
        keyConcepts: [],
        questions: [],
      ),
    );

    expect(html, contains('这是拆分并解释后的正文。'));
    expect(html, isNot(contains('A difficult original paragraph.')));
    expect(html, contains('AI 易读版'));
  });
}

DocumentContent _document(String markdown) {
  return DocumentContent(
    summary: DocumentSummary(
      id: 'doc-1',
      title: 'Atlas',
      kind: DocumentKind.markdown,
      importedAt: DateTime(2026),
      filePath: 'prefs:doc-1',
      hash: 'hash',
    ),
    rawText: markdown,
    sections: const [],
    paragraphs: const [],
  );
}
