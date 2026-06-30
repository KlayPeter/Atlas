import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/document/document_summary.dart';

final libraryControllerProvider = Provider<LibraryController>((ref) {
  return const LibraryController();
});

class LibraryController {
  const LibraryController();

  List<DocumentSummary> recentDocuments() {
    return const [];
  }
}
