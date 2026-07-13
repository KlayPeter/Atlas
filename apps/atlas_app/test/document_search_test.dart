import 'package:atlas_app/features/reader/application/document_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('search counts matches and returns the first offset', () async {
    const search = DocumentSearch();

    final result = await search.search('Atlas atlas ATLAS reader', 'atlas');

    expect(result.count, 3);
    expect(result.firstOffset, 0);
  });

  test(
    'large searches use the background path and do not retain all offsets',
    () async {
      const search = DocumentSearch();
      final source = '${'x' * DocumentSearch.backgroundSearchThreshold}needle';

      final result = await search.search(source, 'needle');

      expect(result.count, 1);
      expect(result.firstOffset, DocumentSearch.backgroundSearchThreshold);
    },
  );
}
