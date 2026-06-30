import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/document/document_content.dart';
import '../data/document_repository.dart';

final documentContentProvider = FutureProvider.family<DocumentContent?, String>(
  (ref, documentId) {
    return ref.read(documentRepositoryProvider).getDocument(documentId);
  },
);
