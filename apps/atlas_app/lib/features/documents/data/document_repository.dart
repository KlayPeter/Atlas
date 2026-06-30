import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
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
  DocumentRepository(this._parser);

  static const _documentsKey = 'atlas.documents.v1';
  static const _offsetPrefix = 'atlas.readingOffset.';

  final DocumentParser _parser;

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

    final file = File(summary.filePath);
    if (!await file.exists()) {
      return null;
    }

    final rawText = await file.readAsString();
    final parsed = _parser.parse(rawText, summary.kind);
    final repairedSummary = summary.wordCount == parsed.wordCount
        ? summary
        : summary.copyWith(wordCount: parsed.wordCount);

    return DocumentContent(
      summary: repairedSummary,
      rawText: parsed.rawText,
      sections: parsed.sections,
      paragraphs: parsed.paragraphs,
    );
  }

  Future<DocumentSummary> importWithPicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['md', 'markdown', 'txt'],
      withData: false,
    );
    final path = result?.files.single.path;
    if (path == null) {
      throw const DocumentImportCanceled();
    }
    return importFile(File(path));
  }

  Future<DocumentSummary> importFile(File sourceFile) async {
    if (!await sourceFile.exists()) {
      throw const DocumentImportFailure('文件不存在');
    }

    final extension = sourceFile.path.split('.').last.toLowerCase();
    if (!const {'md', 'markdown', 'txt'}.contains(extension)) {
      throw const DocumentImportFailure('Atlas 目前只支持 Markdown 和 TXT');
    }

    final bytes = await sourceFile.readAsBytes();
    final hash = sha256.convert(bytes).toString();
    final existing = await _findByHash(hash);
    if (existing != null) {
      await touchDocument(existing.id);
      return existing;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final documentsDir = Directory('${appDir.path}/documents');
    if (!await documentsDir.exists()) {
      await documentsDir.create(recursive: true);
    }

    final id = const Uuid().v4();
    final kind = DocumentKindLabel.fromExtension(extension);
    final safeTitle = sourceFile.uri.pathSegments.last;
    final storedPath = '${documentsDir.path}/$id.${kind.extension}';
    await File(storedPath).writeAsBytes(bytes, flush: true);

    final rawText = utf8.decode(bytes, allowMalformed: true);
    final parsed = _parser.parse(rawText, kind);
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
      final file = File(target.filePath);
      if (await file.exists()) {
        await file.delete();
      }
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
