import 'package:markdown/markdown.dart' as markdown;

import '../../../domain/document/document_content.dart';
import '../../../domain/document/document_summary.dart';

class DocumentParser {
  const DocumentParser();

  ParsedDocument parse(String rawText, DocumentKind kind) {
    final normalized = rawText.replaceAll('\r\n', '\n');
    final sections = switch (kind) {
      DocumentKind.markdown => _parseMarkdownSections(normalized),
      DocumentKind.text => _parseTextSections(normalized),
    };

    return ParsedDocument(
      rawText: normalized,
      wordCount: _countWords(normalized),
      sections: sections,
      paragraphs: _splitParagraphs(normalized),
      renderRanges: kind == DocumentKind.markdown
          ? _buildMarkdownRenderRanges(normalized)
          : const [],
    );
  }

  List<DocumentRange> _buildMarkdownRenderRanges(String source) {
    if (source.isEmpty) {
      return const [];
    }

    const targetLength = 12000;
    const hardLimit = targetLength * 2;
    final ranges = <DocumentRange>[];
    final lines = source.split('\n');
    var chunkStart = 0;
    var offset = 0;
    String? fenceCharacter;

    for (var index = 0; index < lines.length; index += 1) {
      final line = lines[index];
      final fence = RegExp(r'^\s*(`{3,}|~{3,})').firstMatch(line)?.group(1);
      if (fence != null) {
        final character = fence[0];
        if (fenceCharacter == null) {
          fenceCharacter = character;
        } else if (fenceCharacter == character) {
          fenceCharacter = null;
        }
      }

      offset += line.length;
      if (index < lines.length - 1) {
        offset += 1;
      }
      final length = offset - chunkStart;
      final safeBoundary =
          fenceCharacter == null &&
          (line.trim().isEmpty || length >= hardLimit);
      if (length >= targetLength && safeBoundary) {
        ranges.add(DocumentRange(start: chunkStart, end: offset));
        chunkStart = offset;
      }
    }

    if (chunkStart < source.length) {
      ranges.add(DocumentRange(start: chunkStart, end: source.length));
    }
    return ranges;
  }

  List<DocumentSection> _parseMarkdownSections(String source) {
    final sections = <DocumentSection>[];
    final lines = source.split('\n');
    var offset = 0;

    for (final line in lines) {
      final match = RegExp(r'^(#{1,6})\s+(.+?)\s*$').firstMatch(line);
      if (match != null) {
        final title = _stripInlineMarkdown(match.group(2)!);
        sections.add(
          DocumentSection(
            id: 'section-${sections.length + 1}',
            title: title,
            level: match.group(1)!.length,
            startOffset: offset,
            preview: _previewFrom(source, offset),
          ),
        );
      }
      offset += line.length + 1;
    }

    if (sections.isNotEmpty) {
      return sections;
    }

    final document = markdown.Document();
    final nodes = document.parseLines(lines);
    for (final node in nodes.whereType<markdown.Element>()) {
      if (node.tag == 'h1' || node.tag == 'h2' || node.tag == 'h3') {
        sections.add(
          DocumentSection(
            id: 'section-${sections.length + 1}',
            title: node.textContent,
            level: int.tryParse(node.tag.substring(1)) ?? 1,
            startOffset: 0,
            preview: _previewFrom(source, 0),
          ),
        );
      }
    }
    return sections;
  }

  List<DocumentSection> _parseTextSections(String source) {
    final paragraphs = _splitParagraphs(source);
    if (paragraphs.isEmpty) {
      return const [];
    }

    final sections = <DocumentSection>[];
    var offset = 0;
    for (var index = 0; index < paragraphs.length; index += 8) {
      final title = '第 ${sections.length + 1} 节';
      final paragraphOffset = source.indexOf(paragraphs[index], offset);
      final startOffset = paragraphOffset < 0 ? offset : paragraphOffset;
      sections.add(
        DocumentSection(
          id: 'section-${sections.length + 1}',
          title: title,
          level: 1,
          startOffset: startOffset,
          preview: paragraphs[index],
        ),
      );
      offset = startOffset + paragraphs[index].length;
    }
    return sections;
  }

  List<String> _splitParagraphs(String source) {
    return source
        .split(RegExp(r'\n\s*\n'))
        .expand((paragraph) => _splitLongParagraph(paragraph.trim()))
        .where((paragraph) => paragraph.isNotEmpty)
        .toList(growable: false);
  }

  Iterable<String> _splitLongParagraph(String paragraph) sync* {
    const maxLength = 520;
    if (paragraph.length <= maxLength) {
      yield paragraph;
      return;
    }

    var start = 0;
    while (start < paragraph.length) {
      final end = (start + maxLength).clamp(0, paragraph.length);
      var splitAt = paragraph.lastIndexOf(RegExp(r'[。！？.!?]\s*'), end);
      if (splitAt <= start + 120) {
        splitAt = end;
      } else {
        splitAt += 1;
      }
      yield paragraph.substring(start, splitAt).trim();
      start = splitAt;
    }
  }

  int _countWords(String source) {
    final cjkCount = RegExp(r'[\u4e00-\u9fff]').allMatches(source).length;
    final wordCount = RegExp(
      r"[A-Za-z0-9_]+(?:[-'][A-Za-z0-9_]+)?",
    ).allMatches(source).length;
    return cjkCount + wordCount;
  }

  String _previewFrom(String source, int offset) {
    final end = (offset + 160).clamp(0, source.length);
    return _stripInlineMarkdown(
      source.substring(offset, end),
    ).replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _stripInlineMarkdown(String source) {
    return source
        .replaceAll(RegExp(r'[`*_~\[\]()>#-]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
