import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/document/document_content.dart';
import '../../../domain/document/document_summary.dart';
import '../../reader/application/document_parser.dart';

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return DocumentRepository(const DocumentParser());
});

class DocumentRepository {
  DocumentRepository(this._parser, {bool usePreferencesForDocuments = false})
    : _usePreferencesForDocuments = usePreferencesForDocuments;

  static const _documentsKey = 'atlas.documents.v1';
  static const _offsetPrefix = 'atlas.readingOffset.';
  static const _contentPrefix = 'atlas.documentContent.';
  static const maxImportBytes = 50 * 1024 * 1024;
  static const backgroundParseThreshold = 256 * 1024;

  final DocumentParser _parser;
  final bool _usePreferencesForDocuments;

  Future<List<DocumentSummary>> listDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    final rawDocuments = prefs.getStringList(_documentsKey) ?? const [];
    final documents =
        rawDocuments
            .map((raw) => DocumentSummary.fromJson(jsonDecode(raw)))
            .toList()
          ..sort((a, b) {
            final aReadAt = a.lastReadAt ?? a.importedAt;
            final bReadAt = b.lastReadAt ?? b.importedAt;
            return bReadAt.compareTo(aReadAt);
          });
    return documents;
  }

  Future<DocumentContent?> getDocument(String id) async {
    final documents = await listDocuments();
    final summary = documents
        .where((document) => document.id == id)
        .firstOrNull;
    if (summary == null) {
      return null;
    }

    final rawText = await _readDocumentText(summary);
    if (rawText == null) {
      return null;
    }
    final parsed = await _parse(rawText, summary.kind);
    final repairedSummary = summary.wordCount == parsed.wordCount
        ? summary
        : summary.copyWith(wordCount: parsed.wordCount);

    return DocumentContent(
      summary: repairedSummary,
      rawText: parsed.rawText,
      sections: parsed.sections,
      paragraphs: parsed.paragraphs,
      renderRanges: parsed.renderRanges,
    );
  }

  Future<DocumentSummary> importWithPicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['md', 'markdown', 'txt'],
      withData: kIsWeb,
    );
    final pickedFile = result?.files.single;
    if (pickedFile == null) {
      throw const DocumentImportCanceled();
    }

    final path = pickedFile.path;
    if (!kIsWeb && path != null) {
      return importFile(File(path));
    }

    final bytes = pickedFile.bytes;
    if (bytes == null) {
      throw const DocumentImportFailure('无法读取所选文件内容');
    }
    return importBytes(bytes: bytes, originalName: pickedFile.name);
  }

  Future<DocumentSummary> importFile(File sourceFile) async {
    if (!await sourceFile.exists()) {
      throw const DocumentImportFailure('文件不存在');
    }

    final extension = sourceFile.path.split('.').last.toLowerCase();
    if (!const {'md', 'markdown', 'txt'}.contains(extension)) {
      throw const DocumentImportFailure('Atlas 目前只支持 Markdown 和 TXT');
    }

    final fileSize = await sourceFile.length();
    _validateImportSize(fileSize);

    final bytes = await sourceFile.readAsBytes();
    return importBytes(
      bytes: bytes,
      originalName: sourceFile.uri.pathSegments.last,
    );
  }

  Future<DocumentSummary> importBytes({
    required List<int> bytes,
    required String originalName,
  }) async {
    final extension = originalName.split('.').last.toLowerCase();
    if (!const {'md', 'markdown', 'txt'}.contains(extension)) {
      throw const DocumentImportFailure('Atlas 目前只支持 Markdown 和 TXT');
    }
    _validateImportSize(bytes.length);

    final hash = sha256.convert(bytes).toString();
    final existing = await _findByHash(hash);
    if (existing != null) {
      await touchDocument(existing.id);
      return existing;
    }

    final id = const Uuid().v4();
    final kind = DocumentKindLabel.fromExtension(extension);
    final safeTitle = originalName;
    final rawText = utf8.decode(bytes, allowMalformed: true);
    final storedPath = await _storeDocumentBytes(
      id: id,
      kind: kind,
      bytes: bytes,
      rawText: rawText,
    );

    final parsed = await _parse(rawText, kind);
    final now = DateTime.now();
    final summary = DocumentSummary(
      id: id,
      title: safeTitle,
      kind: kind,
      importedAt: now,
      lastReadAt: now,
      filePath: storedPath,
      hash: hash,
      fileSize: bytes.length,
      wordCount: parsed.wordCount,
    );

    final documents = await listDocuments();
    await _saveDocuments([summary, ...documents]);
    return summary;
  }

  Future<void> deleteDocument(String id) async {
    final documents = await listDocuments();
    final target = documents.where((document) => document.id == id).firstOrNull;
    if (target != null) {
      await _deleteStoredDocument(target);
    }
    await _saveDocuments(
      documents.where((document) => document.id != id).toList(),
    );
  }

  Future<void> saveProgress(String id, double offset, double progress) async {
    final documents = await listDocuments();
    final updated = documents
        .map(
          (document) => document.id == id
              ? document.copyWith(
                  progress: progress.clamp(0, 1),
                  lastReadAt: DateTime.now(),
                )
              : document,
        )
        .toList();
    await _saveDocuments(updated);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('$_offsetPrefix$id', offset);
  }

  Future<double> getSavedOffset(String id) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('$_offsetPrefix$id') ?? 0;
  }

  Future<void> touchDocument(String id) async {
    final documents = await listDocuments();
    final updated = documents
        .map(
          (document) => document.id == id
              ? document.copyWith(lastReadAt: DateTime.now())
              : document,
        )
        .toList();
    await _saveDocuments(updated);
  }

  Future<DocumentSummary?> _findByHash(String hash) async {
    final documents = await listDocuments();
    return documents.where((document) => document.hash == hash).firstOrNull;
  }

  Future<void> _saveDocuments(List<DocumentSummary> documents) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = documents
        .map((document) => jsonEncode(document.toJson()))
        .toList(growable: false);
    await prefs.setStringList(_documentsKey, payload);
  }

  Future<String?> _readDocumentText(DocumentSummary summary) async {
    if (summary.filePath.startsWith('prefs:')) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('$_contentPrefix${summary.id}');
    }

    if (kIsWeb) {
      return null;
    }

    final file = File(summary.filePath);
    if (!await file.exists()) {
      return null;
    }
    return file.readAsString();
  }

  Future<String> _storeDocumentBytes({
    required String id,
    required DocumentKind kind,
    required List<int> bytes,
    required String rawText,
  }) async {
    if (kIsWeb || _usePreferencesForDocuments) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_contentPrefix$id', rawText);
      return 'prefs:$id';
    }

    final appDir = await getApplicationDocumentsDirectory();
    final documentsDir = Directory('${appDir.path}/documents');
    if (!await documentsDir.exists()) {
      await documentsDir.create(recursive: true);
    }
    final storedPath = '${documentsDir.path}/$id.${kind.extension}';
    await File(storedPath).writeAsBytes(bytes, flush: true);
    return storedPath;
  }

  Future<ParsedDocument> _parse(String rawText, DocumentKind kind) {
    if (rawText.length < backgroundParseThreshold) {
      return Future.value(_parser.parse(rawText, kind));
    }
    return compute(
      _parseDocumentInBackground,
      _ParseDocumentRequest(rawText: rawText, kind: kind),
    );
  }

  void _validateImportSize(int size) {
    if (size > maxImportBytes) {
      throw const DocumentImportFailure('文件超过 50 MB，请拆分后再导入');
    }
  }

  Future<void> _deleteStoredDocument(DocumentSummary document) async {
    if (document.filePath.startsWith('prefs:')) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_contentPrefix${document.id}');
      return;
    }

    if (kIsWeb) {
      return;
    }

    final file = File(document.filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}

class _ParseDocumentRequest {
  const _ParseDocumentRequest({required this.rawText, required this.kind});

  final String rawText;
  final DocumentKind kind;
}

ParsedDocument _parseDocumentInBackground(_ParseDocumentRequest request) {
  return const DocumentParser().parse(request.rawText, request.kind);
}

class DocumentImportCanceled implements Exception {
  const DocumentImportCanceled();
}

class DocumentImportFailure implements Exception {
  const DocumentImportFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
