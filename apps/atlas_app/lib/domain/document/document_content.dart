import 'document_summary.dart';

class DocumentSection {
  const DocumentSection({
    required this.id,
    required this.title,
    required this.level,
    required this.startOffset,
    required this.preview,
  });

  final String id;
  final String title;
  final int level;
  final int startOffset;
  final String preview;

  factory DocumentSection.fromJson(Map<String, Object?> json) {
    return DocumentSection(
      id: json['id'] as String,
      title: json['title'] as String,
      level: json['level'] as int,
      startOffset: json['startOffset'] as int,
      preview: json['preview'] as String? ?? '',
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'title': title,
      'level': level,
      'startOffset': startOffset,
      'preview': preview,
    };
  }
}

class ParsedDocument {
  const ParsedDocument({
    required this.rawText,
    required this.wordCount,
    required this.sections,
    required this.paragraphs,
  });

  final String rawText;
  final int wordCount;
  final List<DocumentSection> sections;
  final List<String> paragraphs;
}

class DocumentContent {
  const DocumentContent({
    required this.summary,
    required this.rawText,
    required this.sections,
    required this.paragraphs,
  });

  final DocumentSummary summary;
  final String rawText;
  final List<DocumentSection> sections;
  final List<String> paragraphs;

  String get outlineText {
    if (sections.isEmpty) {
      return '无标题文档';
    }
    return sections
        .map((section) => '${'  ' * (section.level - 1)}- ${section.title}')
        .join('\n');
  }
}
