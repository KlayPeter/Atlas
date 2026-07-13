import 'package:atlas_app/features/reader/application/document_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('search returns every match offset for result navigation', () async {
    const search = DocumentSearch();

    final result = await search.search('Atlas atlas ATLAS reader', 'atlas');

    expect(result.count, 3);
    expect(result.query, 'atlas');
    expect(result.offsets, [0, 6, 12]);
    expect(result.firstOffset, 0);
  });

  test('large searches keep offsets from the background path', () async {
    const search = DocumentSearch();
    final source =
        '${'x' * DocumentSearch.backgroundSearchThreshold}needle needle';

    final result = await search.search(source, 'needle');

    expect(result.count, 2);
    expect(result.offsets, [
      DocumentSearch.backgroundSearchThreshold,
      DocumentSearch.backgroundSearchThreshold + 7,
    ]);
  });

  test('blank queries return an empty result', () async {
    const search = DocumentSearch();

    final result = await search.search('Atlas', '   ');

    expect(result.query, isEmpty);
    expect(result.offsets, isEmpty);
  });
}
