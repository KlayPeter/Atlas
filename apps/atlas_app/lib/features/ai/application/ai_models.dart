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
  });

  final String title;
  final String body;
  final List<String> points;
}
