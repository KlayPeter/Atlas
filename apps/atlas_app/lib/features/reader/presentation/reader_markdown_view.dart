import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart' as atom_dark;
import 'package:flutter_highlight/themes/github.dart' as github;
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';

import '../application/reading_settings_controller.dart';

TextStyle _readerSerif(TextStyle? style) {
  return (style ?? const TextStyle()).copyWith(
    fontFamily: 'Noto Serif CJK SC',
    fontFamilyFallback: const ['Songti SC', 'STSong', 'serif'],
  );
}

TextStyle _readerSans(TextStyle? style) {
  return (style ?? const TextStyle()).copyWith(
    fontFamily: 'Noto Sans CJK SC',
    fontFamilyFallback: const ['PingFang SC', 'Microsoft YaHei', 'sans-serif'],
  );
}

TextStyle _readerMono(TextStyle? style) {
  return (style ?? const TextStyle()).copyWith(
    fontFamily: 'SFMono-Regular',
    fontFamilyFallback: const ['Menlo', 'Consolas', 'monospace'],
  );
}

class ReaderSearchHighlight {
  const ReaderSearchHighlight({required this.query, this.activeOccurrence});

  final String query;
  final int? activeOccurrence;
}

class ReaderMarkdownView extends StatelessWidget {
  const ReaderMarkdownView({
    super.key,
    required this.data,
    required this.settings,
    this.compact = false,
    this.onAiExplain,
    this.onAiTranslate,
    this.headerKeys,
    this.searchHighlight,
  });

  final String data;
  final ReadingSettings settings;
  final bool compact;
  final void Function(String text, Offset anchor)? onAiExplain;
  final void Function(String text, Offset anchor)? onAiTranslate;
  final Map<String, List<GlobalKey>>? headerKeys;
  final ReaderSearchHighlight? searchHighlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final styleSheet = _buildStyleSheet(context, theme);

    final searchCounter = _SearchOccurrenceCounter();
    final plugins = ParserPluginRegistry()..register(const MermaidPlugin());
    final highlight = searchHighlight;
    if (highlight != null && highlight.query.isNotEmpty) {
      final firstCharacter = highlight.query[0];
      final triggerCharacters = {
        firstCharacter,
        firstCharacter.toLowerCase(),
        firstCharacter.toUpperCase(),
      };
      for (final trigger in triggerCharacters) {
        plugins.register(
          _SearchMatchPlugin(
            query: highlight.query,
            triggerCharacter: trigger,
            counter: searchCounter,
          ),
        );
      }
    }

    return SmoothMarkdown(
      data: _normalizeMarkdownData(data),
      styleSheet: styleSheet,
      useEnhancedComponents: true,
      selectable: true,
      contextMenuBuilder: onAiExplain == null && onAiTranslate == null
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
      plugins: plugins,
      builderRegistry: BuilderRegistry()
        ..register('header', _AtlasHeaderBuilder(headerKeys))
        ..register('table', const _ReaderTableBuilder())
        ..register('mermaid', _AtlasMermaidBuilder(compact: compact))
        ..register(
          'atlas_search_match',
          _SearchMatchBuilder(
            activeOccurrence: searchHighlight?.activeOccurrence,
            activeColor: theme.colorScheme.primaryContainer.withValues(
              alpha: 0.46,
            ),
            matchColor: theme.colorScheme.tertiaryContainer.withValues(
              alpha: 0.2,
            ),
          ),
        ),
    );
  }

  Widget _buildImage(
    BuildContext context,
    String url,
    String? alt,
    String? title,
  ) {
    if (url.toLowerCase().startsWith('https://')) {
      return _ReaderRemoteImage(url: url, alt: alt);
    }
    return _UnavailableMarkdownImage(
      message: url.toLowerCase().startsWith('http://')
          ? '为保护隐私，Atlas 不加载非 HTTPS 图片'
          : '本地相对图片尚未随文档导入',
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
        .map(
          (button) => ContextMenuButtonItem(
            label: button.label ?? '复制',
            type: ContextMenuButtonType.copy,
            onPressed: () {
              final innerState = selectableRegionState.innerRegionState;
              final delegate =
                  selectableRegionState.registrar
                      as SelectionContainerDelegate?;
              final selectedText =
                  delegate?.getSelectedContent()?.plainText.trim() ?? '';
              if (selectedText.isNotEmpty && selectedText != '_') {
                Clipboard.setData(ClipboardData(text: selectedText));
              }
              innerState?.hideToolbar();
            },
          ),
        )
        .toList();

    void runSelectionAction(void Function(String text, Offset anchor)? action) {
      final innerState = selectableRegionState.innerRegionState;
      final delegate =
          selectableRegionState.registrar as SelectionContainerDelegate?;
      String selectedText =
          delegate?.getSelectedContent()?.plainText.trim() ?? '';
      if (selectedText.isEmpty || selectedText == '_') {
        // ignore: deprecated_member_use
        final textValue = innerState?.textEditingValue;
        selectedText =
            textValue?.selection.textInside(textValue.text).trim() ?? '';
      }
      final anchor = selectableRegionState.contextMenuAnchors.primaryAnchor;
      innerState?.hideToolbar();
      if (selectedText.isNotEmpty) {
        action?.call(selectedText, anchor);
      }
    }

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: selectableRegionState.contextMenuAnchors,
      buttonItems: [
        ...copyButtons,
        ContextMenuButtonItem(
          label: 'AI 解释',
          onPressed: () => runSelectionAction(onAiExplain),
        ),
        ContextMenuButtonItem(
          label: '翻译',
          onPressed: () => runSelectionAction(onAiTranslate),
        ),
      ],
    );
  }

  MarkdownStyleSheet _buildStyleSheet(BuildContext context, ThemeData theme) {
    final scheme = theme.colorScheme;
    final bodyStyle = settings.bodyStyle(context);
    final headingBase = _readerSerif(
      theme.textTheme.headlineSmall?.copyWith(
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
      h4Style: _readerSans(
        theme.textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      h5Style: _readerSans(
        theme.textTheme.titleMedium?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      h6Style: _readerSans(
        theme.textTheme.titleSmall?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      blockquoteStyle: _readerSerif(
        bodyStyle.copyWith(
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
      codeBlockStyle: _readerMono(
        TextStyle(
          fontSize: settings.fontSize.clamp(8, 24),
          height: 1.72,
          color: codeForeground,
        ),
      ),
      inlineCodeStyle: _readerMono(
        bodyStyle.copyWith(
          fontSize: math.max(settings.fontSize - 1, 8),
          color: scheme.primary,
          backgroundColor: scheme.primaryContainer.withValues(alpha: 0.35),
        ),
      ),
      linkStyle: _readerSans(
        theme.textTheme.bodyLarge?.copyWith(
          color: scheme.primary,
          decoration: TextDecoration.underline,
          decorationColor: scheme.primary.withValues(alpha: 0.5),
        ),
      ),
      listBulletStyle: bodyStyle,
      tableHeaderStyle: _readerSans(
        theme.textTheme.titleSmall?.copyWith(
          fontSize: math.max(settings.fontSize - 1, 8),
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      tableCellStyle: _readerSans(
        bodyStyle.copyWith(fontSize: math.max(settings.fontSize - 1, 8)),
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

class _SearchOccurrenceCounter {
  var value = 0;
}

class _SearchMatchNode extends MarkdownNode {
  const _SearchMatchNode({required this.text, required this.occurrence});

  final String text;
  final int occurrence;

  @override
  String get type => 'atlas_search_match';

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'text': text,
    'occurrence': occurrence,
  };

  @override
  _SearchMatchNode copyWith({String? text, int? occurrence}) {
    return _SearchMatchNode(
      text: text ?? this.text,
      occurrence: occurrence ?? this.occurrence,
    );
  }
}

class _SearchMatchPlugin extends InlineParserPlugin {
  const _SearchMatchPlugin({
    required this.query,
    required this.triggerCharacter,
    required this.counter,
  });

  final String query;

  @override
  final String triggerCharacter;

  final _SearchOccurrenceCounter counter;

  @override
  String get id => 'atlas-search-match-${triggerCharacter.codeUnits.join('-')}';

  @override
  String get name => 'Atlas search match';

  @override
  int get priority => 100;

  @override
  bool canParse(String text, int index) {
    if (index + query.length > text.length) {
      return false;
    }
    return text.substring(index, index + query.length).toLowerCase() ==
        query.toLowerCase();
  }

  @override
  InlineParseResult? parse(String text, int startIndex) {
    if (!canParse(text, startIndex)) {
      return null;
    }
    final occurrence = counter.value;
    counter.value += 1;
    return InlineParseResult(
      node: _SearchMatchNode(
        text: text.substring(startIndex, startIndex + query.length),
        occurrence: occurrence,
      ),
      consumed: query.length,
    );
  }
}

class _SearchMatchBuilder extends MarkdownWidgetBuilder {
  const _SearchMatchBuilder({
    required this.activeOccurrence,
    required this.activeColor,
    required this.matchColor,
  });

  final int? activeOccurrence;
  final Color activeColor;
  final Color matchColor;

  @override
  bool canBuild(MarkdownNode node) => node is _SearchMatchNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final match = node as _SearchMatchNode;
    final isActive = match.occurrence == activeOccurrence;
    return Text.rich(
      TextSpan(
        text: match.text,
        style: TextStyle(backgroundColor: isActive ? activeColor : matchColor),
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
        _readerMono(TextStyle(fontSize: settings.fontSize));

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
                        style: _readerMono(
                          TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: scheme.onPrimaryContainer,
                          ),
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
  const _AtlasMermaidBuilder({required this.compact});

  final bool compact;

  @override
  bool canBuild(MarkdownNode node) => node is MermaidDiagramNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final mermaidNode = node as MermaidDiagramNode;

    return LayoutBuilder(
      builder: (context, constraints) {
        final theme = Theme.of(context);
        final minWidth = compact ? constraints.maxWidth : 980.0;
        final style = _style(theme.colorScheme);

        return Semantics(
          button: true,
          label: '点击放大 Mermaid 图表',
          child: Tooltip(
            message: '点击放大 Mermaid 图表',
            child: InkWell(
              key: const ValueKey('mermaid-diagram-preview'),
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => _MermaidFullscreenViewer(
                    code: mermaidNode.code,
                    style: style,
                  ),
                ),
              ),
              child: Container(
                margin: EdgeInsets.symmetric(vertical: compact ? 8 : 18),
                decoration: BoxDecoration(
                  color: Color(style.backgroundColor),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    SingleChildScrollView(
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
                    PositionedDirectional(
                      top: 8,
                      end: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.76),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(7),
                          child: Icon(
                            Icons.open_in_full_rounded,
                            size: 17,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  MermaidStyle _style(ColorScheme scheme) {
    return MermaidStyle(
      backgroundColor: scheme.surfaceContainerLowest.toARGB32(),
      defaultNodeStyle: NodeStyle(
        fillColor: scheme.primaryContainer.toARGB32(),
        strokeColor: scheme.primary.toARGB32(),
        textColor: scheme.onPrimaryContainer.toARGB32(),
      ),
      defaultEdgeStyle: EdgeStyle(
        strokeColor: scheme.onSurfaceVariant.toARGB32(),
      ),
      nodeSpacingX: 88,
      nodeSpacingY: 64,
      padding: 28,
      fontFamily: _diagramFontFamily(),
      themeMode: scheme.brightness == Brightness.dark
          ? MermaidThemeMode.dark
          : MermaidThemeMode.light,
    );
  }

  String _diagramFontFamily() => switch (defaultTargetPlatform) {
    TargetPlatform.android => 'sans-serif',
    TargetPlatform.iOS || TargetPlatform.macOS => 'PingFang SC',
    TargetPlatform.windows => 'Microsoft YaHei',
    TargetPlatform.linux => 'Noto Sans CJK SC',
    TargetPlatform.fuchsia => 'sans-serif',
  };
}

class _MermaidFullscreenViewer extends StatefulWidget {
  const _MermaidFullscreenViewer({required this.code, required this.style});

  final String code;
  final MermaidStyle style;

  @override
  State<_MermaidFullscreenViewer> createState() =>
      _MermaidFullscreenViewerState();
}

class _MermaidFullscreenViewerState extends State<_MermaidFullscreenViewer> {
  static const _diagramWidth = 1200.0;
  final _transformationController = TransformationController();
  var _initialScale = 1.0;
  var _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    _initialScale = (MediaQuery.sizeOf(context).width / _diagramWidth).clamp(
      0.35,
      1.0,
    );
    _resetZoom();
    _initialized = true;
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.diagonal3Values(
      _initialScale,
      _initialScale,
      1,
    );
  }

  void _toggleZoom() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    if (currentScale > _initialScale * 1.3) {
      _resetZoom();
      return;
    }
    _transformationController.value = Matrix4.diagonal3Values(1.8, 1.8, 1);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mermaid 图表'),
        actions: [
          IconButton(
            tooltip: '重置缩放',
            onPressed: _resetZoom,
            icon: const Icon(Icons.center_focus_strong_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: _toggleZoom,
          child: ColoredBox(
            color: scheme.surface,
            child: InteractiveViewer(
              transformationController: _transformationController,
              constrained: false,
              minScale: 0.25,
              maxScale: 6,
              boundaryMargin: const EdgeInsets.all(240),
              child: SizedBox(
                width: _diagramWidth,
                child: MermaidDiagram(
                  code: widget.code,
                  style: widget.style,
                  enableResponsive: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
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

class _ReaderRemoteImage extends StatefulWidget {
  const _ReaderRemoteImage({required this.url, this.alt});

  final String url;
  final String? alt;

  @override
  State<_ReaderRemoteImage> createState() => _ReaderRemoteImageState();
}

class _ReaderRemoteImageState extends State<_ReaderRemoteImage> {
  var _allowed = true;

  @override
  Widget build(BuildContext context) {
    if (!_allowed) {
      final host = Uri.tryParse(widget.url)?.host ?? '远程站点';
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            const Icon(Icons.image_outlined),
            const SizedBox(height: 8),
            Text(widget.alt?.trim().isNotEmpty == true ? widget.alt! : '远程图片'),
            const SizedBox(height: 4),
            Text(
              '图片来自 $host，加载后该站点会看到你的网络请求。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => setState(() => _allowed = true),
              child: const Text('加载这张图片'),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final cacheWidth = (width * MediaQuery.devicePixelRatioOf(context))
            .round()
            .clamp(1, 4096);
        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _ImageFullScreenViewer(url: widget.url),
              ),
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
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.network(
              widget.url,
              fit: BoxFit.contain,
              cacheWidth: cacheWidth,
              filterQuality: FilterQuality.medium,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const SizedBox(
                      height: 180,
                      child: Center(child: CircularProgressIndicator()),
                    ),
              errorBuilder: (context, error, stackTrace) => const SizedBox(
                height: 120,
                child: Center(child: Text('图片加载失败')),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _UnavailableMarkdownImage extends StatelessWidget {
  const _UnavailableMarkdownImage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.broken_image_outlined),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _ImageFullScreenViewer extends StatelessWidget {
  const _ImageFullScreenViewer({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    final image = Image.network(
      url,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) => const Text('图片加载失败'),
    );

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
