import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/document/document_summary.dart';
import '../../documents/data/document_repository.dart';

final libraryControllerProvider =
    AsyncNotifierProvider<LibraryController, List<DocumentSummary>>(
      LibraryController.new,
    );

class LibraryController extends AsyncNotifier<List<DocumentSummary>> {
  DocumentRepository get _repository => ref.read(documentRepositoryProvider);

  @override
  Future<List<DocumentSummary>> build() {
    return _repository.listDocuments();
  }

  Future<DocumentSummary?> importDocument() async {
    try {
      state = const AsyncLoading();
      final document = await _repository.importWithPicker();
      state = AsyncData(await _repository.listDocuments());
      return document;
    } on DocumentImportCanceled {
      state = AsyncData(await _repository.listDocuments());
      return null;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return null;
    }
  }

  Future<void> deleteDocument(String id) async {
    final previous = state.asData?.value ?? const [];
    state = AsyncData(previous.where((document) => document.id != id).toList());
    try {
      await _repository.deleteDocument(id);
      state = AsyncData(await _repository.listDocuments());
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> refresh() async {
    state = AsyncData(await _repository.listDocuments());
  }
}
