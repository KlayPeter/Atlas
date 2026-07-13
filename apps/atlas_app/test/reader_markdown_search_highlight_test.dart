import 'package:atlas_app/features/reader/application/reading_settings_controller.dart';
import 'package:atlas_app/features/reader/presentation/reader_markdown_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'markdown search highlights all matches and emphasizes the active one',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReaderMarkdownView(
              data: 'Atlas atlas ATLAS reader',
              settings: ReadingSettings(),
              searchHighlight: ReaderSearchHighlight(
                query: 'atlas',
                activeOccurrence: 1,
              ),
            ),
          ),
        ),
      );

      final colors = <Color>[];
      for (final richText in tester.widgetList<RichText>(
        find.byType(RichText),
      )) {
        _collectBackgroundColors(richText.text, colors);
      }

      expect(colors, hasLength(3));
      expect(colors.where((color) => color.a > 0.4), hasLength(1));
      expect(colors.where((color) => color.a < 0.3), hasLength(2));
    },
  );
}

void _collectBackgroundColors(InlineSpan span, List<Color> colors) {
  if (span.style?.backgroundColor case final color?) {
    colors.add(color);
  }
  if (span is TextSpan) {
    for (final child in span.children ?? const <InlineSpan>[]) {
      _collectBackgroundColors(child, colors);
    }
  }
}
