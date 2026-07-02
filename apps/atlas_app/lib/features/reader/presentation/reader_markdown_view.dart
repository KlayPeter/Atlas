import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:google_fonts/google_fonts.dart';

import '../application/reading_settings_controller.dart';

class ReaderMarkdownView extends StatelessWidget {
  const ReaderMarkdownView({
    super.key,
    required this.data,
    required this.settings,
  });

  final String data;
  final ReadingSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SmoothMarkdown(
      data: data,
      styleSheet: _buildStyleSheet(context, theme),
      useEnhancedComponents: true,
      plugins: ParserPluginRegistry()..register(const MermaidPlugin()),
      builderRegistry: BuilderRegistry()
        ..register('table', const _ReaderTableBuilder())
        ..register(
          'mermaid',
          EnhancedMermaidBuilder(
            defaultTheme: theme.brightness == Brightness.dark
                ? MermaidThemeMode.dark
                : MermaidThemeMode.light,
            showSourceToggle: true,
          ),
        ),
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
        fontSize: math.max(settings.fontSize + 18, 30),
        fontWeight: FontWeight.w700,
        letterSpacing: -0.45,
      ),
      h2Style: headingBase.copyWith(
        fontSize: math.max(settings.fontSize + 12, 25),
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      h3Style: headingBase.copyWith(
        fontSize: math.max(settings.fontSize + 8, 22),
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
        color: scheme.surfaceContainerLow.withValues(
          alpha: settings.eyeCare ? 0.88 : 1,
        ),
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
          fontSize: math.max(settings.fontSize - 2, 13),
          height: 1.72,
          color: codeForeground,
        ),
      ),
      inlineCodeStyle: GoogleFonts.jetBrainsMono(
        textStyle: bodyStyle.copyWith(
          fontSize: math.max(settings.fontSize - 2, 13),
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
          fontSize: settings.fontSize - 1,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      tableCellStyle: GoogleFonts.notoSansSc(
        textStyle: bodyStyle.copyWith(fontSize: settings.fontSize - 0.5),
      ),
      codeBlockDecoration: BoxDecoration(
        color: codeBackground,
        borderRadius: BorderRadius.circular(20),
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
      blockSpacing: 22,
      listIndent: 28,
      blockquotePadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 16,
      ),
      codeBlockPadding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      tableCellPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
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
      builder: (context, constraints) => ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.8),
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 4),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Table(
                border: styleSheet.tableBorder,
                defaultColumnWidth: const IntrinsicColumnWidth(),
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: rows,
              ),
            ),
          ),
        ),
      ),
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
