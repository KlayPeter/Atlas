enum DocumentKind { markdown, text }

extension DocumentKindLabel on DocumentKind {
  String get label => switch (this) {
    DocumentKind.markdown => 'Markdown',
    DocumentKind.text => 'TXT',
  };

  String get extension => switch (this) {
    DocumentKind.markdown => 'md',
    DocumentKind.text => 'txt',
  };

  static DocumentKind fromExtension(String extension) {
    final normalized = extension.toLowerCase().replaceFirst('.', '');
    return switch (normalized) {
      'md' || 'markdown' => DocumentKind.markdown,
      _ => DocumentKind.text,
    };
  }
}

class DocumentSummary {
  const DocumentSummary({
    required this.id,
    required this.title,
    required this.kind,
    required this.importedAt,
    required this.filePath,
    required this.hash,
    this.fileSize = 0,
    this.wordCount = 0,
    this.progress = 0,
    this.lastReadAt,
  });

  final String id;
  final String title;
  final DocumentKind kind;
  final DateTime importedAt;
  final String filePath;
  final String hash;
  final int fileSize;
  final int wordCount;
  final double progress;
  final DateTime? lastReadAt;

  DocumentSummary copyWith({
    String? id,
    String? title,
    DocumentKind? kind,
    DateTime? importedAt,
    String? filePath,
    String? hash,
    int? fileSize,
    int? wordCount,
    double? progress,
    DateTime? lastReadAt,
  }) {
    return DocumentSummary(
      id: id ?? this.id,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      importedAt: importedAt ?? this.importedAt,
      filePath: filePath ?? this.filePath,
      hash: hash ?? this.hash,
      fileSize: fileSize ?? this.fileSize,
      wordCount: wordCount ?? this.wordCount,
      progress: progress ?? this.progress,
      lastReadAt: lastReadAt ?? this.lastReadAt,
    );
  }

  factory DocumentSummary.fromJson(Map<String, Object?> json) {
    return DocumentSummary(
      id: json['id'] as String,
      title: json['title'] as String,
      kind: DocumentKind.values.byName(json['kind'] as String),
      importedAt: DateTime.parse(json['importedAt'] as String),
      filePath: json['filePath'] as String,
      hash: json['hash'] as String,
      fileSize: json['fileSize'] as int? ?? 0,
      wordCount: json['wordCount'] as int? ?? 0,
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      lastReadAt: json['lastReadAt'] == null
          ? null
          : DateTime.parse(json['lastReadAt'] as String),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'title': title,
      'kind': kind.name,
      'importedAt': importedAt.toIso8601String(),
      'filePath': filePath,
      'hash': hash,
      'fileSize': fileSize,
      'wordCount': wordCount,
      'progress': progress,
      'lastReadAt': lastReadAt?.toIso8601String(),
    };
  }
}
