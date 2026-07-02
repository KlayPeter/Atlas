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
```mermaid
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
}
