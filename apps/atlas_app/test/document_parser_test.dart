import 'package:atlas_app/domain/document/document_summary.dart';
import 'package:atlas_app/features/reader/application/document_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = DocumentParser();

  test('parses markdown headings for table of contents', () {
    final parsed = parser.parse(
      '# Atlas\n\n正文\n\n## Reader\n\n- item\n\n```dart\nvoid main() {}\n```',
      DocumentKind.markdown,
    );

    expect(parsed.sections.map((section) => section.title), [
      'Atlas',
      'Reader',
    ]);
    expect(parsed.wordCount, greaterThan(0));
  });

  test('splits long txt paragraphs into readable chunks', () {
    final parsed = parser.parse('${'很长的句子。' * 90}\n\n第二段。', DocumentKind.text);

    expect(parsed.paragraphs.length, greaterThan(2));
    expect(parsed.sections, isNotEmpty);
  });
}
