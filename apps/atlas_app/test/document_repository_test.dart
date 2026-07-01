import 'dart:convert';

import 'package:atlas_app/domain/document/document_summary.dart';
import 'package:atlas_app/features/documents/data/document_repository.dart';
import 'package:atlas_app/features/reader/application/document_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DocumentRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = DocumentRepository(
      const DocumentParser(),
      usePreferencesForDocuments: true,
    );
  });

  test(
    'imports bytes and reads document content without file system access',
    () async {
      final document = await repository.importBytes(
        bytes: utf8.encode('# Atlas\n\nLocal-first reader.'),
        originalName: 'atlas.md',
      );

      final content = await repository.getDocument(document.id);

      expect(document.kind, DocumentKind.markdown);
      expect(document.filePath, startsWith('prefs:'));
      expect(content?.rawText, contains('Local-first reader.'));
      expect(content?.sections.single.title, 'Atlas');
    },
  );

  test('deduplicates repeated byte imports by hash', () async {
    final first = await repository.importBytes(
      bytes: utf8.encode('same text'),
      originalName: 'note.txt',
    );
    final second = await repository.importBytes(
      bytes: utf8.encode('same text'),
      originalName: 'note-copy.txt',
    );

    final documents = await repository.listDocuments();

    expect(second.id, first.id);
    expect(documents, hasLength(1));
  });

  test('deletes stored preference content with document record', () async {
    final document = await repository.importBytes(
      bytes: utf8.encode('temporary text'),
      originalName: 'temp.txt',
    );

    await repository.deleteDocument(document.id);

    expect(await repository.listDocuments(), isEmpty);
    expect(await repository.getDocument(document.id), isNull);
  });
}
