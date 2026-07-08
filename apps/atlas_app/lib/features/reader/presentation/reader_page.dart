import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/routing/app_routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../domain/document/document_content.dart';
import '../../../domain/document/document_summary.dart';
import '../../../domain/ai/study_models.dart';
import '../../ai/application/ai_models.dart';
import '../../ai/data/ai_api_client.dart';
import '../../ai/presentation/ai_panel.dart';
import '../../documents/application/document_content_provider.dart';
import '../../documents/data/document_repository.dart';
import '../../library/application/library_controller.dart';
import '../../html_export/application/html_export_service.dart';
import '../../html_export/presentation/html_preview_page.dart';
import '../application/reading_settings_controller.dart';
import 'reader_markdown_view.dart';

class ReaderPage extends ConsumerStatefulWidget {
  const ReaderPage({super.key, required this.documentId});

  final String? documentId;

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage> {
  final _scrollController = ScrollController();
  Timer? _progressDebounce;
  OverlayEntry? _inlineExplanationOverlay;
  final ValueNotifier<bool> _isExplanationVisible = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _restoreOffset();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_isExplanationVisible.value) {
      _hideInlineExplanation();
    }
    _scheduleProgressSave();
  }

  @override
  void dispose() {
    _progressDebounce?.cancel();
    if (_inlineExplanationOverlay != null) {
      _inlineExplanationOverlay?.remove();
      _inlineExplanationOverlay?.dispose();
    }
    _isExplanationVisible.dispose();
    unawaited(_saveProgress(refreshLibrary: true));
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final documentId = widget.documentId;
    if (documentId == null || documentId.isEmpty) {
      return const _MissingDocumentPage();
    }

    final document = ref.watch(documentContentProvider(documentId));
    final settings = ref.watch(readingSettingsProvider);

    return document.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => _ReaderError(error: error),
      data: (content) {
        if (content == null) {
          return const _MissingDocumentPage();
        }
        final readingSettings =
            settings.asData?.value ?? const ReadingSettings();
        
        return ValueListenableBuilder<bool>(
          valueListenable: _isExplanationVisible,
          builder: (context, isVisible, child) {
            return PopScope(
              canPop: !isVisible,
              onPopInvokedWithResult: (didPop, _) {
                if (didPop) {
                  return;
                }
                if (_isExplanationVisible.value) {
                  _hideInlineExplanation();
                }
              },
              child: child!,
            );
          },
          child: _ReaderScaffold(
            document: content,
            scrollController: _scrollController,
            settings: readingSettings,
            onBack: _handleBack,
            onShowToc: () => _showToc(content),
            onSearch: () => _showSearch(content),
            onAi: () => _showAi(content),
            onAiExplain: (text, anchor) =>
                _showInlineExplanation(content, text, anchor),
            onSettings: () => _showSettings(readingSettings),
            onHtml: () => _previewHtml(content),
            onShareHtml: () => _shareHtml(content),
            headerKeys: _headerKeys,
          ),
        );
      },
    );
  }

  Future<void> _restoreOffset() async {
    final id = widget.documentId;
    if (id == null) {
      return;
    }
    final offset = await ref
        .read(documentRepositoryProvider)
        .getSavedOffset(id);
    if (!mounted || offset <= 0) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(
          offset.clamp(0, _scrollController.position.maxScrollExtent),
        );
      }
    });
  }

  void _scheduleProgressSave() {
    _progressDebounce?.cancel();
    _progressDebounce = Timer(const Duration(milliseconds: 500), _saveProgress);
  }

  Future<void> _saveProgress({bool refreshLibrary = false}) async {
    final id = widget.documentId;
    if (id == null || !_scrollController.hasClients) {
      return;
    }
    final max = _scrollController.position.maxScrollExtent;
    final offset = _scrollController.offset
        .clamp(0, math.max(0, max))
        .toDouble();
    final progress = max <= 0 ? 0.0 : offset / max;

    final repo = ref.read(documentRepositoryProvider);
    final libNotifier = ref.read(libraryControllerProvider.notifier);

    await repo.saveProgress(id, offset, progress);
    if (refreshLibrary) {
      libNotifier.refresh();
    }
  }

  Future<void> _showToc(DocumentContent document) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.64,
        minChildSize: 0.32,
        maxChildSize: 0.9,
        builder: (context, sheetController) => _TocSheet(
          document: document,
          scrollController: sheetController,
          onSectionSelected: (section) {
            Navigator.of(context).pop();
            _jumpToSection(document, section);
          },
        ),
      ),
    );
  }

  final Map<String, List<GlobalKey>> _headerKeys = {};

  void _jumpToSection(DocumentContent document, DocumentSection section) {
    if (!_scrollController.hasClients || document.rawText.isEmpty) {
      return;
    }

    final keyString = '${section.level}:${section.title}';
    final keys = _headerKeys[keyString];

    if (keys != null && keys.isNotEmpty) {
      // Find the best matching key based on order (rough approximation)
      // For exact matching, we would need the actual index, but since DocumentSection
      // doesn't have an index, we just pick the first one for now, or we can find
      // the closest offset.
      final targetKey =
          keys.first; // usually the first one works for most documents
      final context = targetKey.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          alignment: 0.05, // scroll a bit down from top
        );
        return;
      }
    }

    // Fallback to ratio-based jump if key is not found
    final ratio = section.startOffset / document.rawText.length;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent * ratio,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  Future<void> _showSearch(DocumentContent document) async {
    final queryController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) {
        var results = <int>[];
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('文档内搜索'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: queryController,
                  autofocus: true,
                  decoration: const InputDecoration(hintText: '关键词'),
                  onChanged: (value) {
                    setState(() {
                      results = _findMatches(document.rawText, value);
                    });
                  },
                ),
                const SizedBox(height: AtlasSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('找到 ${results.length} 处'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('关闭'),
              ),
              FilledButton(
                onPressed: results.isEmpty
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        final ratio = results.first / document.rawText.length;
                        _scrollController.animateTo(
                          _scrollController.position.maxScrollExtent * ratio,
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOut,
                        );
                      },
                child: const Text('跳转首个'),
              ),
            ],
          ),
        );
      },
    );
    queryController.dispose();
  }

  List<int> _findMatches(String source, String query) {
    if (query.trim().isEmpty) {
      return const [];
    }
    return RegExp(
      RegExp.escape(query),
      caseSensitive: false,
    ).allMatches(source).map((match) => match.start).toList(growable: false);
  }

  Future<void> _showAi(DocumentContent document, {String? initialSelection}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) =>
          AiPanel(document: document, initialSelection: initialSelection),
    );
  }

  void _showInlineExplanation(
    DocumentContent document,
    String selectedText,
    Offset anchor,
  ) {
    _inlineExplanationOverlay?.remove();
    final result = ref
        .read(aiApiClientProvider)
        .explain(
          context: AiDocumentContext.fromDocument(document),
          selectedText: selectedText,
        );

    _inlineExplanationOverlay = OverlayEntry(
      builder: (context) => _InlineExplanationOverlay(
        anchor: anchor,
        selectedText: selectedText,
        result: result,
        onClose: _hideInlineExplanation,
      ),
    );
    Overlay.of(context).insert(_inlineExplanationOverlay!);
    _isExplanationVisible.value = true;
  }

  void _hideInlineExplanation() {
    if (_inlineExplanationOverlay == null) return;
    _inlineExplanationOverlay?.remove();
    _inlineExplanationOverlay?.dispose();
    _inlineExplanationOverlay = null;
    _isExplanationVisible.value = false;
  }

  void _handleBack() {
    if (_inlineExplanationOverlay != null) {
      _hideInlineExplanation();
      return;
    }
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.library);
  }

  Future<void> _showSettings(ReadingSettings settings) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => const _ReadingSettingsSheet(),
    );
  }

  Future<void> _previewHtml(DocumentContent document) async {
    final mode = await showDialog<HtmlPreviewMode>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('HTML 预览'),
        content: const Text('请选择你要预览的模式：'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(HtmlPreviewMode.original),
            child: const Text('原文展示'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(HtmlPreviewMode.summary),
            child: const Text('总结全文'),
          ),
        ],
      ),
    );

    if (mode == null || !mounted) return;

    context.push(AppRoutes.htmlPreviewPath(document.summary.id), extra: mode);
  }

  Future<void> _shareHtml(DocumentContent document) async {
    final wantEnhance = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('生成 HTML'),
        content: const Text('是否在 HTML 中包含 AI 生成的导读、摘要和思考题？这可能需要几秒钟。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('仅导出原文'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('AI 强化导出'),
          ),
        ],
      ),
    );

    if (wantEnhance == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('正在生成 HTML...')));

    try {
      HtmlEnhanceResult? enhance;
      if (wantEnhance) {
        final aiClient = ref.read(aiApiClientProvider);
        enhance = await aiClient.enhanceHtml(
          context: AiDocumentContext.fromDocument(document),
        );
      }

      final file = await ref
          .read(htmlExportServiceProvider)
          .writeHtml(document, enhance: enhance);

      if (!mounted) return;
      await Share.shareXFiles([
        XFile(file.path),
      ], subject: document.summary.title);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('导出失败: $e')));
    }
  }
}

class _TocSheet extends StatelessWidget {
  const _TocSheet({
    required this.document,
    required this.scrollController,
    required this.onSectionSelected,
  });

  final DocumentContent document;
  final ScrollController scrollController;
  final ValueChanged<DocumentSection> onSectionSelected;

  @override
  Widget build(BuildContext context) {
    final sections = document.sections;

    return SafeArea(
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.only(bottom: AtlasSpacing.md),
        itemCount: sections.isEmpty ? 2 : sections.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                AtlasSpacing.md,
                AtlasSpacing.sm,
                AtlasSpacing.md,
                AtlasSpacing.xs,
              ),
              child: Text('目录', style: Theme.of(context).textTheme.titleMedium),
            );
          }

          if (sections.isEmpty) {
            return const ListTile(title: Text('这份文档没有标题'));
          }

          final section = sections[index - 1];
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.only(
              left: AtlasSpacing.md + (section.level - 1) * 16,
              right: AtlasSpacing.md,
            ),
            title: Text(
              section.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => onSectionSelected(section),
          );
        },
      ),
    );
  }
}

class _ReaderScaffold extends StatelessWidget {
  const _ReaderScaffold({
    required this.document,
    required this.scrollController,
    required this.settings,
    required this.onBack,
    required this.onShowToc,
    required this.onSearch,
    required this.onAi,
    required this.onAiExplain,
    required this.onSettings,
    required this.onHtml,
    required this.onShareHtml,
    required this.headerKeys,
  });

  final DocumentContent document;
  final ScrollController scrollController;
  final ReadingSettings settings;
  final VoidCallback onBack;
  final VoidCallback onShowToc;
  final VoidCallback onSearch;
  final VoidCallback onAi;
  final void Function(String text, Offset anchor) onAiExplain;
  final VoidCallback onSettings;
  final VoidCallback onHtml;
  final VoidCallback onShareHtml;
  final Map<String, List<GlobalKey>> headerKeys;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = settings.eyeCare
        ? const Color(0xFFF4F0E4)
        : theme.colorScheme.surface;
    final paperColor = settings.eyeCare
        ? const Color(0xFFFFFCF4)
        : theme.colorScheme.surfaceContainerLowest;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        leading: IconButton(
          tooltip: '返回',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        scrolledUnderElevation: 0,
        title: Text(document.summary.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: '目录',
            onPressed: onShowToc,
            icon: const Icon(Icons.format_list_bulleted),
          ),
          IconButton(
            tooltip: '搜索',
            onPressed: onSearch,
            icon: const Icon(Icons.search),
          ),
          PopupMenuButton<String>(
            tooltip: '更多',
            onSelected: (value) {
              switch (value) {
                case 'settings':
                  onSettings();
                case 'html':
                  onHtml();
                case 'share':
                  onShareHtml();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'settings', child: Text('阅读设置')),
              PopupMenuItem(value: 'html', child: Text('预览 HTML')),
              PopupMenuItem(value: 'share', child: Text('分享 HTML')),
            ],
          ),
        ],
      ),
      body: document.summary.kind == DocumentKind.markdown
          ? _buildMarkdownBody(paperColor)
          : _buildPlainTextBody(paperColor),
      floatingActionButton: FloatingActionButton(
        onPressed: onAi,
        tooltip: 'AI 助手',
        child: const Icon(Icons.auto_awesome_outlined),
      ),
    );
  }

  EdgeInsets _readerPadding() {
    return EdgeInsets.fromLTRB(
      math.min(settings.pagePadding, AtlasSpacing.md),
      AtlasSpacing.sm,
      math.min(settings.pagePadding, AtlasSpacing.md),
      AtlasSpacing.xl,
    );
  }

  Widget _buildMarkdownBody(Color paperColor) {
    return ListView(
      controller: scrollController,
      padding: _readerPadding(),
      cacheExtent: 900,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        RepaintBoundary(
          child: DecoratedBox(
            decoration: BoxDecoration(color: paperColor),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 28),
              child: ReaderMarkdownView(
                data: document.rawText,
                settings: settings,
                onAiExplain: onAiExplain,
                headerKeys: headerKeys,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlainTextBody(Color paperColor) {
    final bodyStyle = settings.bodyStyle;
    return ListView.builder(
      controller: scrollController,
      padding: _readerPadding(),
      cacheExtent: 1200,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: document.paragraphs.length,
      itemBuilder: (context, index) {
        return RepaintBoundary(
          child: DecoratedBox(
            decoration: BoxDecoration(color: paperColor),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                8,
                index == 0 ? 12 : 0,
                8,
                index == document.paragraphs.length - 1 ? 28 : AtlasSpacing.md,
              ),
              child: SelectionArea(
                contextMenuBuilder: (context, selectableRegionState) =>
                    _buildPlainTextSelectionToolbar(
                      context,
                      selectableRegionState,
                    ),
                child: Text(
                  document.paragraphs[index],
                  style: bodyStyle(context),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlainTextSelectionToolbar(
    BuildContext context,
    SelectableRegionState selectableRegionState,
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
            // ignore: deprecated_member_use
            final textValue = selectableRegionState.textEditingValue;
            final selectedText = textValue.selection
                .textInside(textValue.text)
                .trim();
            final anchor =
                selectableRegionState.contextMenuAnchors.primaryAnchor;
            selectableRegionState.hideToolbar();
            if (selectedText.isNotEmpty) {
              onAiExplain(selectedText, anchor);
            }
          },
        ),
      ],
    );
  }
}

class _InlineExplanationOverlay extends StatelessWidget {
  const _InlineExplanationOverlay({
    required this.anchor,
    required this.selectedText,
    required this.result,
    required this.onClose,
  });

  final Offset anchor;
  final String selectedText;
  final Future<AiResult> result;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = math.min(380.0, size.width - 24);
    final height = math.min(360.0, size.height - 48);
    final left = (anchor.dx - width / 2).clamp(12.0, size.width - width - 12);
    final preferBelow = anchor.dy + height + 16 < size.height;
    final top = preferBelow
        ? anchor.dy + 12
        : (anchor.dy - height - 12).clamp(12.0, size.height - height - 12);

    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          width: width,
          child: Material(
            elevation: 14,
            borderRadius: BorderRadius.circular(10),
            color: Theme.of(context).colorScheme.surface,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: height),
              child: Padding(
                padding: const EdgeInsets.all(AtlasSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'AI 解释',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        IconButton(
                          tooltip: '关闭',
                          onPressed: onClose,
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ],
                    ),
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: AtlasSpacing.xs),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AtlasSpacing.sm,
                        vertical: AtlasSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        selectedText,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: AtlasSpacing.sm),
                    Flexible(
                      child: FutureBuilder<AiResult>(
                        future: result,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: AtlasSpacing.md,
                              ),
                              child: LinearProgressIndicator(),
                            );
                          }
                          if (snapshot.hasError) {
                            final message = snapshot.error
                                .toString()
                                .replaceFirst('Exception: ', '');
                            return DecoratedBox(
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(AtlasSpacing.sm),
                                child: Text(
                                  '$message\n\n请到设置里的 AI 模型配置检查 Atlas BFF 地址、API Key、Base URL 和模型名称。',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                            );
                          }

                          return SingleChildScrollView(
                            child: ReaderMarkdownView(
                              data: snapshot.requireData.body,
                              settings: const ReadingSettings(
                                fontSize: 14,
                                lineHeight: 1.45,
                              ),
                              compact: true,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReadingSettingsSheet extends ConsumerStatefulWidget {
  const _ReadingSettingsSheet();

  @override
  ConsumerState<_ReadingSettingsSheet> createState() =>
      _ReadingSettingsSheetState();
}

class _ReadingSettingsSheetState extends ConsumerState<_ReadingSettingsSheet> {
  ReadingSettings? _localSettings;

  @override
  void initState() {
    super.initState();
    _localSettings = ref.read(readingSettingsProvider).value;
  }

  @override
  Widget build(BuildContext context) {
    if (_localSettings == null) {
      return const SizedBox.shrink();
    }
    final settings = _localSettings!;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AtlasSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('阅读设置', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AtlasSpacing.md),
            Text('字号 ${settings.fontSize.round()}'),
            Slider(
              value: settings.fontSize,
              min: 8,
              max: 24,
              divisions: 16,
              onChanged: (value) {
                setState(
                  () => _localSettings = settings.copyWith(fontSize: value),
                );
              },
              onChangeEnd: (value) {
                ref
                    .read(readingSettingsProvider.notifier)
                    .updateSettings(settings.copyWith(fontSize: value));
              },
            ),
            Text('行距 ${settings.lineHeight.toStringAsFixed(2)}'),
            Slider(
              value: settings.lineHeight,
              min: 1.25,
              max: 2.1,
              divisions: 17,
              onChanged: (value) {
                setState(
                  () => _localSettings = settings.copyWith(lineHeight: value),
                );
              },
              onChangeEnd: (value) {
                ref
                    .read(readingSettingsProvider.notifier)
                    .updateSettings(settings.copyWith(lineHeight: value));
              },
            ),
            Text('页边距 ${settings.pagePadding.round()}'),
            Slider(
              value: settings.pagePadding,
              min: 12,
              max: 36,
              divisions: 12,
              onChanged: (value) {
                setState(
                  () => _localSettings = settings.copyWith(pagePadding: value),
                );
              },
              onChangeEnd: (value) {
                ref
                    .read(readingSettingsProvider.notifier)
                    .updateSettings(settings.copyWith(pagePadding: value));
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('护眼纸色'),
              value: settings.eyeCare,
              onChanged: (value) {
                setState(
                  () => _localSettings = settings.copyWith(eyeCare: value),
                );
                ref
                    .read(readingSettingsProvider.notifier)
                    .updateSettings(settings.copyWith(eyeCare: value));
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ReaderError extends StatelessWidget {
  const _ReaderError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('阅读器')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AtlasSpacing.lg),
          child: Text('读取文档失败：$error', textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

class _MissingDocumentPage extends StatelessWidget {
  const _MissingDocumentPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('阅读器')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AtlasSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.description_outlined, size: 48),
              const SizedBox(height: AtlasSpacing.md),
              const Text('找不到这份文档'),
              const SizedBox(height: AtlasSpacing.md),
              FilledButton(
                onPressed: () => context.go(AppRoutes.library),
                child: const Text('回到最近阅读'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
