import '../../../domain/document/document_content.dart';

class AiDocumentContext {
  const AiDocumentContext({
    required this.documentId,
    required this.title,
    required this.outline,
    required this.excerpt,
  });

  final String documentId;
  final String title;
  final String outline;
  final String excerpt;

  static const maxExcerptLength = 12000;
  static const htmlChunkLength = 9000;
  static const maxHtmlChunks = 8;

  factory AiDocumentContext.fromDocument(DocumentContent document) {
    return AiDocumentContext(
      documentId: document.summary.id,
      title: document.summary.title,
      outline: document.outlineText,
      excerpt: _representativeExcerpt(document.rawText),
    );
  }

  factory AiDocumentContext.forExcerpt(
    DocumentContent document,
    String excerpt,
  ) {
    return AiDocumentContext(
      documentId: document.summary.id,
      title: document.summary.title,
      outline: document.outlineText,
      excerpt: excerpt,
    );
  }

  static AiDocumentChunks htmlChunks(DocumentContent document) {
    final source = document.rawText;
    if (source.length <= htmlChunkLength) {
      return AiDocumentChunks(
        contexts: [AiDocumentContext.forExcerpt(document, source)],
        sampled: false,
      );
    }

    final fullCoverageLimit = htmlChunkLength * maxHtmlChunks;
    final excerpts = <String>[];
    if (source.length <= fullCoverageLimit) {
      for (var start = 0; start < source.length; start += htmlChunkLength) {
        final end = (start + htmlChunkLength).clamp(0, source.length);
        excerpts.add(source.substring(start, end));
      }
    } else {
      final lastStart = source.length - htmlChunkLength;
      for (var index = 0; index < maxHtmlChunks; index += 1) {
        final start = (lastStart * index / (maxHtmlChunks - 1)).round();
        excerpts.add(source.substring(start, start + htmlChunkLength));
      }
    }

    final contexts = <AiDocumentContext>[];
    for (var index = 0; index < excerpts.length; index += 1) {
      contexts.add(
        AiDocumentContext.forExcerpt(
          document,
          '[文档片段 ${index + 1}/${excerpts.length}]\n${excerpts[index]}',
        ),
      );
    }
    return AiDocumentChunks(
      contexts: contexts,
      sampled: source.length > fullCoverageLimit,
    );
  }

  static String _representativeExcerpt(String source) {
    if (source.length <= maxExcerptLength) {
      return source;
    }
    const markerBudget = 120;
    final partLength = (maxExcerptLength - markerBudget) ~/ 3;
    final middleStart = (source.length - partLength) ~/ 2;
    return [
      '[文档开头]',
      source.substring(0, partLength),
      '[文档中部]',
      source.substring(middleStart, middleStart + partLength),
      '[文档结尾]',
      source.substring(source.length - partLength),
    ].join('\n');
  }

  Map<String, Object?> toJson() {
    return {
      'documentId': documentId,
      'title': title,
      'outline': outline,
      'excerpt': excerpt,
    };
  }
}

class AiDocumentChunks {
  const AiDocumentChunks({required this.contexts, required this.sampled});

  final List<AiDocumentContext> contexts;
  final bool sampled;
}

class AiResult {
  const AiResult({
    required this.title,
    required this.body,
    this.points = const [],
    this.createdAt,
  });

  final String title;
  final String body;
  final List<String> points;
  final DateTime? createdAt;

  factory AiResult.fromJson(Map<String, Object?> json) {
    return AiResult(
      title: json['title'] as String? ?? 'AI',
      body: json['body'] as String? ?? '',
      points: (json['points'] as List?)?.cast<String>() ?? const [],
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'title': title,
      'body': body,
      'points': points,
      'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
    };
  }
}

enum AiHistoryKind { explanation, summary, question }

class AiHistoryEntry {
  const AiHistoryEntry({
    required this.id,
    required this.documentId,
    required this.kind,
    required this.prompt,
    required this.result,
    required this.createdAt,
  });

  final String id;
  final String documentId;
  final AiHistoryKind kind;
  final String prompt;
  final AiResult result;
  final DateTime createdAt;

  factory AiHistoryEntry.fromJson(Map<String, Object?> json) {
    return AiHistoryEntry(
      id: json['id'] as String,
      documentId: json['documentId'] as String,
      kind: AiHistoryKind.values.byName(json['kind'] as String),
      prompt: json['prompt'] as String? ?? '',
      result: AiResult.fromJson(json['result'] as Map<String, Object?>),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'documentId': documentId,
      'kind': kind.name,
      'prompt': prompt,
      'result': result.toJson(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
