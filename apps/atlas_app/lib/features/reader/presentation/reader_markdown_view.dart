import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart' as atom_dark;
import 'package:flutter_highlight/themes/github.dart' as github;
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../application/reading_settings_controller.dart';

class ReaderMarkdownView extends StatelessWidget {
  const ReaderMarkdownView({
    super.key,
    required this.data,
    required this.settings,
    this.compact = false,
    this.onAiExplain,
    this.useJsMermaid = true,
    this.headerKeys,
  });

  final String data;
  final ReadingSettings settings;
  final bool compact;
  final void Function(String text, Offset anchor)? onAiExplain;
  final bool useJsMermaid;
  final Map<String, List<GlobalKey>>? headerKeys;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final styleSheet = _buildStyleSheet(context, theme);

    return SmoothMarkdown(
      data: _normalizeMarkdownData(data),
      styleSheet: styleSheet,
      useEnhancedComponents: true,
      selectable: true,
      contextMenuBuilder: onAiExplain == null
          ? null
          : (context, selectableRegionState) =>
                _buildSelectionToolbar(context, selectableRegionState),
      codeBuilder: (code, language) => _ReaderCodeBlock(
        code: code,
        language: language,
        styleSheet: styleSheet,
        settings: settings,
      ),
      imageBuilder: (url, alt, title) => _buildImage(context, url, alt, title),
      plugins: ParserPluginRegistry()..register(const MermaidPlugin()),
      builderRegistry: BuilderRegistry()
        ..register('header', _AtlasHeaderBuilder(headerKeys))
        ..register('table', const _ReaderTableBuilder())
        ..register(
          'mermaid',
          _AtlasMermaidBuilder(compact: compact, useJsMermaid: useJsMermaid),
        ),
    );
  }

  Widget _buildImage(
    BuildContext context,
    String url,
    String? alt,
    String? title,
  ) {
    Widget image;
    if (url.startsWith('http://') || url.startsWith('https://')) {
      image = Image.network(url, fit: BoxFit.contain);
    } else if (url.startsWith('file://')) {
      image = Image.file(
        File(Uri.parse(url).toFilePath()),
        fit: BoxFit.contain,
      );
    } else {
      final file = File(url);
      if (file.existsSync()) {
        image = Image.file(file, fit: BoxFit.contain);
      } else {
        image = Image.network(url, fit: BoxFit.contain);
      }
    }

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => _ImageFullScreenViewer(url: url)),
        );
      },
      child: Container(
        constraints: const BoxConstraints(
          maxHeight: 500,
          minWidth: double.infinity,
        ),
        margin: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: image,
      ),
    );
  }

  String _normalizeMarkdownData(String value) {
    return value.replaceAllMapped(
      RegExp(r'(^|\n)(`{3,}|~{3,})[ \t]*mermind([ \t]*\n)'),
      (match) => '${match[1]}${match[2]}mermaid${match[3]}',
    );
  }

  Widget _buildSelectionToolbar(
    BuildContext context,
    SmoothSelectionRegionState selectableRegionState,
  ) {
    final copyButtons = selectableRegionState.contextMenuButtonItems
        .where((button) => button.type == ContextMenuButtonType.copy)
        .toList();

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: selectableRegionState.contextMenuAnchors,
      buttonItems: [
        ...copyButtons,
        ContextMenuButtonItem(
          label: 'AI 解释',
          onPressed: () {
            final innerState = selectableRegionState.innerRegionState;
            final delegate = selectableRegionState.registrar as SelectionContainerDelegate?;
            String selectedText = delegate?.getSelectedContent()?.plainText.trim() ?? '';
            
            debugPrint('Selection: SelectedContent plainText = "$selectedText"');

            if (selectedText.isEmpty || selectedText == '_') {
              // Fallback for older behavior if the delegate approach fails
              // ignore: deprecated_member_use
              final textValue = innerState?.textEditingValue;
              selectedText =
                  textValue?.selection.textInside(textValue.text).trim() ?? '';
              debugPrint('Selection: fallback textValue = "$selectedText"');
            }
            final anchor =
                selectableRegionState.contextMenuAnchors.primaryAnchor;
            innerState?.hideToolbar();
            if (selectedText.isNotEmpty) {
              onAiExplain?.call(selectedText, anchor);
            }
          },
        ),
      ],
    );
  }

  MarkdownStyleSheet _buildStyleSheet(BuildContext context, ThemeData theme) {
    final scheme = theme.colorScheme;
    final bodyStyle = settings.bodyStyle(context);
    final headingBase = GoogleFonts.notoSerifSc(
      textStyle: theme.textTheme.headlineSmall?.copyWith(
        color: scheme.onSurface,
        height: 1.28,
      ),
    );
    final isDark = theme.brightness == Brightness.dark;
    final codeForeground = isDark
        ? Colors.white.withValues(alpha: 0.92)
        : const Color(0xFF1F2933);
    final codeBackground = isDark
        ? const Color(0xFF17212B)
        : const Color(0xFFF5F1E8);

    return MarkdownStyleSheet.fromTheme(theme).copyWith(
      textStyle: bodyStyle,
      paragraphStyle: bodyStyle,
      h1Style: headingBase.copyWith(
        fontSize: compact
            ? math.max(settings.fontSize + 5, 19)
            : math.max(settings.fontSize + 12, 24),
        fontWeight: FontWeight.w700,
      ),
      h2Style: headingBase.copyWith(
        fontSize: compact
            ? math.max(settings.fontSize + 3, 17)
            : math.max(settings.fontSize + 8, 21),
        fontWeight: FontWeight.w700,
      ),
      h3Style: headingBase.copyWith(
        fontSize: compact
            ? math.max(settings.fontSize + 2, 16)
            : math.max(settings.fontSize + 5, 18),
        fontWeight: FontWeight.w600,
      ),
      h4Style: GoogleFonts.notoSansSc(
        textStyle: theme.textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      h5Style: GoogleFonts.notoSansSc(
        textStyle: theme.textTheme.titleMedium?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      h6Style: GoogleFonts.notoSansSc(
        textStyle: theme.textTheme.titleSmall?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      blockquoteStyle: GoogleFonts.notoSerifSc(
        textStyle: bodyStyle.copyWith(
          color: scheme.onSurfaceVariant,
          height: settings.lineHeight + 0.05,
        ),
      ),
      blockquoteDecoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withValues(alpha: 0.82),
        border: Border(
          left: BorderSide(
            color: scheme.primary.withValues(alpha: 0.45),
            width: 4,
          ),
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      codeBlockStyle: GoogleFonts.jetBrainsMono(
        textStyle: TextStyle(
          fontSize: settings.fontSize.clamp(8, 24),
          height: 1.72,
          color: codeForeground,
        ),
      ),
      inlineCodeStyle: GoogleFonts.jetBrainsMono(
        textStyle: bodyStyle.copyWith(
          fontSize: math.max(settings.fontSize - 1, 8),
          color: scheme.primary,
          backgroundColor: scheme.primaryContainer.withValues(alpha: 0.35),
        ),
      ),
      linkStyle: GoogleFonts.notoSansSc(
        textStyle: theme.textTheme.bodyLarge?.copyWith(
          color: scheme.primary,
          decoration: TextDecoration.underline,
          decorationColor: scheme.primary.withValues(alpha: 0.5),
        ),
      ),
      listBulletStyle: bodyStyle,
      tableHeaderStyle: GoogleFonts.notoSansSc(
        textStyle: theme.textTheme.titleSmall?.copyWith(
          fontSize: math.max(settings.fontSize - 1, 8),
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      tableCellStyle: GoogleFonts.notoSansSc(
        textStyle: bodyStyle.copyWith(
          fontSize: math.max(settings.fontSize - 1, 8),
        ),
      ),
      codeBlockDecoration: BoxDecoration(
        color: codeBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.8)),
      ),
      tableBorder: TableBorder.all(
        color: scheme.outlineVariant.withValues(alpha: 0.8),
      ),
      tableHeaderDecoration: BoxDecoration(color: scheme.surfaceContainerHigh),
      tableOddRowDecoration: BoxDecoration(
        color: settings.eyeCare
            ? const Color(0xFFFFFCF5)
            : scheme.surfaceContainerLowest,
      ),
      tableEvenRowDecoration: BoxDecoration(
        color: settings.eyeCare ? const Color(0xFFFAF5E8) : scheme.surface,
      ),
      blockSpacing: compact ? 10 : 20,
      listIndent: compact ? 18 : 28,
      blockquotePadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      codeBlockPadding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      tableCellPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
    );
  }
}

class _ReaderCodeBlock extends StatelessWidget {
  const _ReaderCodeBlock({
    required this.code,
    required this.language,
    required this.styleSheet,
    required this.settings,
  });

  final String code;
  final String? language;
  final MarkdownStyleSheet styleSheet;
  final ReadingSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final label = (language == null || language!.trim().isEmpty)
        ? 'TEXT'
        : language!.trim().toUpperCase();
    final codeStyle =
        styleSheet.codeBlockStyle ??
        GoogleFonts.jetBrainsMono(fontSize: settings.fontSize);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 14),
      decoration:
          styleSheet.codeBlockDecoration ??
          BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
          ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
              border: Border(
                bottom: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.7),
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
              child: Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Text(
                        label,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: '复制代码',
                    visualDensity: VisualDensity.compact,
                    iconSize: 18,
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: code));
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(const SnackBar(content: Text('代码已复制')));
                      }
                    },
                    icon: const Icon(Icons.copy_rounded),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: HighlightView(
              code,
              language: _normalizeLanguage(language),
              theme: isDark ? atom_dark.atomOneDarkTheme : github.githubTheme,
              padding: styleSheet.codeBlockPadding,
              textStyle: codeStyle,
            ),
          ),
        ],
      ),
    );
  }

  String _normalizeLanguage(String? value) {
    final language = value?.trim().toLowerCase();
    if (language == null ||
        language.isEmpty ||
        language == 'text' ||
        language == 'txt') {
      return 'plaintext';
    }

    final normalized = switch (language) {
      'js' => 'javascript',
      'ts' => 'typescript',
      'sh' || 'bash' || 'shell' => 'bash',
      _ => language,
    };

    const supportedLanguages = {
      'bash',
      'css',
      'dart',
      'diff',
      'go',
      'html',
      'java',
      'javascript',
      'json',
      'kotlin',
      'markdown',
      'python',
      'ruby',
      'rust',
      'scss',
      'sql',
      'swift',
      'typescript',
      'xml',
      'yaml',
    };

    return supportedLanguages.contains(normalized) ? normalized : 'plaintext';
  }
}

class _AtlasMermaidBuilder extends MarkdownWidgetBuilder {
  const _AtlasMermaidBuilder({
    required this.compact,
    required this.useJsMermaid,
  });

  final bool compact;
  final bool useJsMermaid;

  @override
  bool canBuild(MarkdownNode node) => node is MermaidDiagramNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final mermaidNode = node as MermaidDiagramNode;

    if (useJsMermaid) {
      return _MermaidJsDiagram(code: mermaidNode.code, compact: compact);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final minWidth = compact ? constraints.maxWidth : 980.0;
        final style = _style(isDark);

        return Container(
          margin: EdgeInsets.symmetric(vertical: compact ? 8 : 18),
          decoration: BoxDecoration(
            color: Color(style.backgroundColor),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFFA78BFA).withValues(alpha: 0.38),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: math.max(constraints.maxWidth, minWidth),
              ),
              child: MermaidDiagram(
                code: mermaidNode.code,
                style: style,
                enableResponsive: !compact,
              ),
            ),
          ),
        );
      },
    );
  }

  MermaidStyle _style(bool isDark) {
    if (isDark) {
      return MermaidStyle.dark().copyWith(
        defaultNodeStyle: const NodeStyle(
          fillColor: 0xFF28233D,
          strokeColor: 0xFFA78BFA,
          textColor: 0xFFF8FAFC,
        ),
        defaultEdgeStyle: const EdgeStyle(strokeColor: 0xFFE5E7EB),
        nodeSpacingX: 88,
        nodeSpacingY: 64,
        padding: 28,
      );
    }

    return const MermaidStyle(
      backgroundColor: 0xFFFFFFFF,
      defaultNodeStyle: NodeStyle(
        fillColor: 0xFFF3F0FF,
        strokeColor: 0xFFA78BFA,
        textColor: 0xFF111827,
      ),
      defaultEdgeStyle: EdgeStyle(strokeColor: 0xFF30333A),
      nodeSpacingX: 88,
      nodeSpacingY: 64,
      padding: 28,
    );
  }
}

class _MermaidJsDiagram extends StatefulWidget {
  const _MermaidJsDiagram({required this.code, required this.compact});

  final String code;
  final bool compact;

  @override
  State<_MermaidJsDiagram> createState() => _MermaidJsDiagramState();
}

class _MermaidJsDiagramState extends State<_MermaidJsDiagram> {
  late final WebViewController _controller;
  double _height = 280;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'AtlasMermaid',
        onMessageReceived: (message) {
          if (message.message == 'CLICK') {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    _MermaidFullScreenViewer(code: widget.code, isDark: isDark),
              ),
            );
            return;
          }
          final nextHeight = double.tryParse(message.message);
          if (nextHeight == null || !mounted) return;
          setState(() {
            _height = nextHeight.clamp(180, 1200);
          });
        },
      )
      ..loadHtmlString(_html(widget.code, ThemeMode.system));
  }

  @override
  void didUpdateWidget(covariant _MermaidJsDiagram oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code) {
      _controller.loadHtmlString(_html(widget.code, ThemeMode.system));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          margin: EdgeInsets.symmetric(vertical: widget.compact ? 8 : 18),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.8),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: constraints.maxWidth,
            height: _height,
            child: WebViewWidget(controller: _controller),
          ),
        );
      },
    );
  }

  String _html(String code, ThemeMode themeMode) {
    final encodedCode = base64Encode(utf8.encode(code));
    final theme = themeMode == ThemeMode.dark ? 'dark' : 'default';
    return '''
<!doctype html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <style>
    html, body {
      margin: 0;
      padding: 0;
      background: transparent;
      overflow: hidden;
      font-family: ui-sans-serif, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }
    #container {
      box-sizing: border-box;
      min-width: 100%;
      padding: 18px;
    }
    svg {
      display: block;
      max-width: 100%;
      height: auto;
    }
    .error {
      padding: 16px;
      color: #991b1b;
      background: #fef2f2;
      border: 1px solid #fecaca;
      border-radius: 10px;
      font: 13px/1.55 ui-monospace, SFMono-Regular, Menlo, monospace;
      white-space: pre-wrap;
    }
  </style>
</head>
<body>
  <div id="container"></div>
  <script type="module">
    import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@11.12.2/dist/mermaid.esm.min.mjs';

    const source = decodeURIComponent(escape(atob('$encodedCode')));
    const container = document.getElementById('container');

    container.addEventListener('click', function() {
      AtlasMermaid.postMessage('CLICK');
    });

    function reportHeight() {
      const height = Math.ceil(document.documentElement.scrollHeight || document.body.scrollHeight || 280);
      AtlasMermaid.postMessage(String(height));
    }

    try {
      mermaid.initialize({
        startOnLoad: false,
        theme: '$theme',
        securityLevel: 'loose',
        fontFamily: 'ui-sans-serif, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
        sequence: { mirrorActors: false, useMaxWidth: false },
        flowchart: { useMaxWidth: false, htmlLabels: true, curve: 'basis' }
      });
      const id = 'atlas_mermaid_' + Math.random().toString(36).slice(2);
      const result = await mermaid.render(id, source);
      container.innerHTML = result.svg;
      requestAnimationFrame(reportHeight);
      new ResizeObserver(reportHeight).observe(container);
    } catch (error) {
      container.innerHTML = '<pre class="error"></pre>';
      container.querySelector('.error').textContent = error?.message || String(error);
      reportHeight();
    }
  </script>
</body>
</html>
''';
  }
}

class _ReaderTableBuilder extends MarkdownWidgetBuilder {
  const _ReaderTableBuilder();

  @override
  bool canBuild(MarkdownNode node) => node is TableNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final tableNode = node as TableNode;
    var columnCount = tableNode.alignments.length;

    if (tableNode.headers.length > columnCount) {
      columnCount = tableNode.headers.length;
    }

    for (final row in tableNode.rows) {
      if (row.cells.length > columnCount) {
        columnCount = row.cells.length;
      }
    }

    if (columnCount == 0) {
      columnCount = 1;
    }

    final rows = <TableRow>[
      _buildRow(
        cells: tableNode.headers,
        alignments: tableNode.alignments,
        columnCount: columnCount,
        styleSheet: styleSheet,
        context: context,
        isHeader: true,
      ),
      for (var index = 0; index < tableNode.rows.length; index++)
        _buildRow(
          cells: tableNode.rows[index].cells,
          alignments: tableNode.alignments,
          columnCount: columnCount,
          styleSheet: styleSheet,
          context: context,
          isHeader: false,
          rowIndex: index,
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnWidth = math.max(
          120.0,
          math.min(240.0, constraints.maxWidth / columnCount),
        );

        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.8),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(bottom: 4),
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Table(
                  border: styleSheet.tableBorder,
                  defaultColumnWidth: FixedColumnWidth(columnWidth),
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: rows,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  TableRow _buildRow({
    required List<List<MarkdownNode>> cells,
    required List<TableAlignment?> alignments,
    required int columnCount,
    required MarkdownStyleSheet styleSheet,
    required MarkdownRenderContext context,
    required bool isHeader,
    int rowIndex = 0,
  }) {
    return TableRow(
      decoration: isHeader
          ? styleSheet.tableHeaderDecoration
          : rowIndex.isEven
          ? styleSheet.tableOddRowDecoration
          : styleSheet.tableEvenRowDecoration,
      children: [
        for (var index = 0; index < columnCount; index++)
          _buildCell(
            content: index < cells.length ? cells[index] : const [],
            alignment: index < alignments.length ? alignments[index] : null,
            styleSheet: styleSheet,
            context: context,
            isHeader: isHeader,
          ),
      ],
    );
  }

  Widget _buildCell({
    required List<MarkdownNode> content,
    required TableAlignment? alignment,
    required MarkdownStyleSheet styleSheet,
    required MarkdownRenderContext context,
    required bool isHeader,
  }) {
    final baseStyle = isHeader
        ? styleSheet.tableHeaderStyle ?? styleSheet.textStyle
        : styleSheet.tableCellStyle ?? styleSheet.textStyle;

    final inlineRenderer = context.inlineRenderer;
    final child = inlineRenderer != null
        ? inlineRenderer(content, baseStyle)
        : Text(
            content.whereType<TextNode>().map((node) => node.content).join(),
            style: baseStyle,
          );

    return Container(
      alignment: _alignmentFor(alignment),
      constraints: const BoxConstraints(minWidth: 120),
      padding: styleSheet.tableCellPadding ?? const EdgeInsets.all(8),
      child: child,
    );
  }

  Alignment _alignmentFor(TableAlignment? alignment) {
    return switch (alignment) {
      TableAlignment.center => Alignment.center,
      TableAlignment.right => Alignment.centerRight,
      _ => Alignment.centerLeft,
    };
  }
}

class _MermaidFullScreenViewer extends StatefulWidget {
  const _MermaidFullScreenViewer({required this.code, required this.isDark});
  final String code;
  final bool isDark;
  @override
  State<_MermaidFullScreenViewer> createState() =>
      _MermaidFullScreenViewerState();
}

class _MermaidFullScreenViewerState extends State<_MermaidFullScreenViewer> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..loadHtmlString(_html(widget.code, widget.isDark));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        iconTheme: IconThemeData(color: scheme.onSurface),
        elevation: 0,
      ),
      body: SafeArea(child: WebViewWidget(controller: _controller)),
    );
  }

  String _html(String code, bool isDark) {
    final encodedCode = base64Encode(utf8.encode(code));
    final theme = isDark ? 'dark' : 'default';
    return '''
<!doctype html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=5.0, user-scalable=yes" />
  <style>
    html, body {
      margin: 0;
      padding: 0;
      background: transparent;
      min-height: 100vh;
    }
    #container {
      box-sizing: border-box;
      width: 100%;
      padding: 18px;
    }
    svg {
      display: block;
      max-width: none;
      height: auto;
      margin: auto;
    }
  </style>
</head>
<body>
  <div id="container"></div>
  <script type="module">
    import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@11.12.2/dist/mermaid.esm.min.mjs';
    const source = decodeURIComponent(escape(atob('$encodedCode')));
    const container = document.getElementById('container');
    try {
      mermaid.initialize({
        startOnLoad: false,
        theme: '$theme',
        securityLevel: 'loose',
        sequence: { mirrorActors: false, useMaxWidth: false },
        flowchart: { useMaxWidth: false, htmlLabels: true, curve: 'basis' }
      });
      const id = 'atlas_mermaid_' + Math.random().toString(36).slice(2);
      const result = await mermaid.render(id, source);
      container.innerHTML = result.svg;
    } catch (error) {}
  </script>
</body>
</html>
''';
  }
}

class _ImageFullScreenViewer extends StatelessWidget {
  const _ImageFullScreenViewer({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (url.startsWith('http://') || url.startsWith('https://')) {
      image = Image.network(url);
    } else if (url.startsWith('file://')) {
      image = Image.file(File(Uri.parse(url).toFilePath()));
    } else {
      final file = File(url);
      if (file.existsSync()) {
        image = Image.file(file);
      } else {
        image = Image.network(url);
      }
    }

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        iconTheme: IconThemeData(color: scheme.onSurface),
        elevation: 0,
      ),
      body: InteractiveViewer(
        minScale: 0.5,
        maxScale: 5.0,
        child: Center(child: image),
      ),
    );
  }
}

class _AtlasHeaderBuilder extends MarkdownWidgetBuilder {
  _AtlasHeaderBuilder(this.headerKeys);
  final Map<String, List<GlobalKey>>? headerKeys;
  final _delegate = const EnhancedHeaderBuilder();

  @override
  bool canBuild(MarkdownNode node) => _delegate.canBuild(node);

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final headerNode = node as HeaderNode;
    final widget = _delegate.build(node, styleSheet, context);
    if (headerKeys == null) return widget;

    // Remove inline markdown syntax from the header node's content,
    // to match how DocumentSection.title is generated.
    final title = headerNode.content
        .replaceAll(RegExp(r'[`*_~\[\]()>#-]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final keyString = '${headerNode.level}:$title';

    // Create a new GlobalKey for this header
    final headerKey = GlobalKey();

    // Add it to the map
    if (!headerKeys!.containsKey(keyString)) {
      headerKeys![keyString] = [];
    }
    headerKeys![keyString]!.add(headerKey);

    return Container(key: headerKey, child: widget);
  }
}
