import 'package:flutter/foundation.dart';

class DocumentSearch {
  const DocumentSearch();

  static const backgroundSearchThreshold = 256 * 1024;

  Future<DocumentSearchResult> search(String source, String query) {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      return Future.value(const DocumentSearchResult());
    }
    final request = _SearchRequest(source: source, query: normalized);
    if (source.length < backgroundSearchThreshold) {
      return Future.value(_searchDocument(request));
    }
    return compute(_searchDocument, request);
  }
}

class DocumentSearchResult {
  const DocumentSearchResult({this.query = '', this.offsets = const []});

  final String query;
  final List<int> offsets;

  int get count => offsets.length;
  int? get firstOffset => offsets.firstOrNull;
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
  final offsets = <int>[];
  for (final match in matches) {
    offsets.add(match.start);
  }
  return DocumentSearchResult(query: request.query, offsets: offsets);
}
