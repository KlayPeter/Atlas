enum DocumentKind { markdown, text }

class DocumentSummary {
  const DocumentSummary({
    required this.id,
    required this.title,
    required this.kind,
    required this.importedAt,
    this.wordCount = 0,
    this.progress = 0,
  });

  final String id;
  final String title;
  final DocumentKind kind;
  final DateTime importedAt;
  final int wordCount;
  final double progress;
}
