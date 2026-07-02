import 'package:atlas_app/features/reader/application/reading_settings_controller.dart';
import 'package:atlas_app/features/reader/presentation/reader_markdown_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'ReaderMarkdownView renders mermaid blocks and scrollable tables',
    (tester) async {
      const markdown = '''
```mermind
sequenceDiagram
  Alice->>Bob: 你好
  Bob-->>Alice: 收到
```

| 列一 | 列二 | 列三 |
| --- | --- | --- |
| 很长的内容 | 这是一段需要横向滚动查看的表格内容 | 结尾 |
''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReaderMarkdownView(
              data: markdown,
              settings: ReadingSettings(),
              useJsMermaid: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MermaidDiagram), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SingleChildScrollView &&
              widget.scrollDirection == Axis.horizontal,
        ),
        findsWidgets,
      );
    },
  );

  testWidgets('ReaderMarkdownView keeps markdown text selectable', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderMarkdownView(
            data: '这是一段可以选择并解释的正文。',
            settings: const ReadingSettings(),
            onAiExplain: (_, _) {},
            useJsMermaid: false,
          ),
        ),
      ),
    );

    final markdown = tester.widget<SmoothMarkdown>(find.byType(SmoothMarkdown));
    expect(markdown.selectable, isTrue);
    expect(markdown.contextMenuBuilder, isNotNull);
  });

  testWidgets(
    'ReaderMarkdownView renders code blocks with a non-overlapping toolbar',
    (tester) async {
      const markdown = '''
```dart
final expected = count(expected_handled);
```
''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReaderMarkdownView(
              data: markdown,
              settings: ReadingSettings(),
              useJsMermaid: false,
            ),
          ),
        ),
      );

      expect(find.text('DART'), findsOneWidget);
      expect(find.byTooltip('复制代码'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText().contains('expected_handled'),
        ),
        findsOneWidget,
      );
    },
  );

  test('ReadingSettings defaults to a 14 point reading font', () {
    expect(const ReadingSettings().fontSize, 14);
  });
}
