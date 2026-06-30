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

  factory AiDocumentContext.fromDocument(DocumentContent document) {
    final excerptLength = document.rawText.length.clamp(0, 6000);
    return AiDocumentContext(
      documentId: document.summary.id,
      title: document.summary.title,
      outline: document.outlineText,
      excerpt: document.rawText.substring(0, excerptLength),
    );
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
