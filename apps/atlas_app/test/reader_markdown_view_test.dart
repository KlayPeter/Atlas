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
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MermaidDiagram), findsOneWidget);
      final diagram = tester.widget<MermaidDiagram>(
        find.byType(MermaidDiagram),
      );
      expect(diagram.style?.fontFamily, isNotEmpty);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SingleChildScrollView &&
              widget.scrollDirection == Axis.horizontal,
        ),
        findsWidgets,
      );

      await tester.tap(find.byKey(const ValueKey('mermaid-diagram-preview')));
      await tester.pumpAndSettle();

      expect(find.text('Mermaid 图表'), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.byTooltip('重置缩放'), findsOneWidget);
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
          ),
        ),
      ),
    );

    final markdown = tester.widget<SmoothMarkdown>(find.byType(SmoothMarkdown));
    expect(markdown.selectable, isTrue);
    expect(markdown.contextMenuBuilder, isNotNull);
  });

  testWidgets('remote images require explicit consent before loading', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReaderMarkdownView(
            data: '![cover](https://images.example/cover.png)',
            settings: ReadingSettings(),
          ),
        ),
      ),
    );

    expect(find.byType(Image), findsNothing);
    expect(find.text('加载这张图片'), findsOneWidget);

    await tester.tap(find.text('加载这张图片'));
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('unsafe local and HTTP image sources stay blocked', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReaderMarkdownView(
            data:
                '![local](file:///etc/passwd)\n\n![http](http://example.com/a.png)',
            settings: ReadingSettings(),
          ),
        ),
      ),
    );

    expect(find.byType(Image), findsNothing);
    expect(find.textContaining('本地相对图片'), findsOneWidget);
    expect(find.textContaining('非 HTTPS'), findsOneWidget);
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
