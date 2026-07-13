import 'package:flutter/foundation.dart';

class DocumentSearch {
  const DocumentSearch();

  static const backgroundSearchThreshold = 256 * 1024;

  Future<DocumentSearchResult> search(String source, String query) {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      return Future.value(const DocumentSearchResult(count: 0));
    }
    final request = _SearchRequest(source: source, query: normalized);
    if (source.length < backgroundSearchThreshold) {
      return Future.value(_searchDocument(request));
    }
    return compute(_searchDocument, request);
  }
}

class DocumentSearchResult {
  const DocumentSearchResult({required this.count, this.firstOffset});

  final int count;
  final int? firstOffset;
}

class _SearchRequest {
  const _SearchRequest({required this.source, required this.query});

  final String source;
  final String query;
}

DocumentSearchResult _searchDocument(_SearchRequest request) {
  final matches = RegExp(
    RegExp.escape(request.query),
    caseSensitive: false,
  ).allMatches(request.source);
  var count = 0;
  int? firstOffset;
  for (final match in matches) {
    firstOffset ??= match.start;
    count += 1;
  }
  return DocumentSearchResult(count: count, firstOffset: firstOffset);
}
