import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
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
import '../../html_export/application/html_export_service.dart';
import '../application/reading_settings_controller.dart';

class ReaderPage extends ConsumerStatefulWidget {
  const ReaderPage({super.key, required this.documentId});

  final String? documentId;

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage> {
  final _scrollController = ScrollController();
  Timer? _progressDebounce;

  @override
  void initState() {
    super.initState();
    _restoreOffset();
    _scrollController.addListener(_scheduleProgressSave);
  }

  @override
  void dispose() {
    _progressDebounce?.cancel();
    _saveProgress();
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
        return _ReaderScaffold(
          document: content,
          scrollController: _scrollController,
          settings: readingSettings,
          onShowToc: () => _showToc(content),
          onSearch: () => _showSearch(content),
          onAi: () => _showAi(content),
          onAiExplain: (text) => _showAi(content, initialSelection: text),
          onSettings: () => _showSettings(readingSettings),
          onHtml: () =>
              context.push(AppRoutes.htmlPreviewPath(content.summary.id)),
          onShareHtml: () => _shareHtml(content),
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

  Future<void> _saveProgress() async {
    final id = widget.documentId;
    if (id == null || !_scrollController.hasClients) {
      return;
    }
    final max = _scrollController.position.maxScrollExtent;
    final offset = _scrollController.offset
        .clamp(0, math.max(0, max))
        .toDouble();
    final progress = max <= 0 ? 0.0 : offset / max;
    await ref
        .read(documentRepositoryProvider)
        .saveProgress(id, offset, progress);
  }

  Future<void> _showToc(DocumentContent document) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(AtlasSpacing.md),
              child: Text('目录', style: Theme.of(context).textTheme.titleMedium),
            ),
            if (document.sections.isEmpty)
              const ListTile(title: Text('这份文档没有标题'))
            else
              for (final section in document.sections)
                ListTile(
                  contentPadding: EdgeInsets.only(
                    left: AtlasSpacing.md + (section.level - 1) * 16,
                    right: AtlasSpacing.md,
                  ),
                  title: Text(section.title),
                  subtitle: section.preview.isEmpty
                      ? null
                      : Text(section.preview),
                  onTap: () {
                    Navigator.of(context).pop();
                    _jumpToSection(document, section);
                  },
                ),
          ],
        ),
      ),
    );
  }

  void _jumpToSection(DocumentContent document, DocumentSection section) {
    if (!_scrollController.hasClients || document.rawText.isEmpty) {
      return;
    }
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
      builder: (context) => AiPanel(document: document, initialSelection: initialSelection),
    );
  }

  Future<void> _showSettings(ReadingSettings settings) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => const _ReadingSettingsSheet(),
    );
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

class _ReaderScaffold extends StatelessWidget {
  const _ReaderScaffold({
    required this.document,
    required this.scrollController,
    required this.settings,
    required this.onShowToc,
    required this.onSearch,
    required this.onAi,
    required this.onAiExplain,
    required this.onSettings,
    required this.onHtml,
    required this.onShareHtml,
  });

  final DocumentContent document;
  final ScrollController scrollController;
  final ReadingSettings settings;
  final VoidCallback onShowToc;
  final VoidCallback onSearch;
  final VoidCallback onAi;
  final ValueChanged<String> onAiExplain;
  final VoidCallback onSettings;
  final VoidCallback onHtml;
  final VoidCallback onShareHtml;

  @override
  Widget build(BuildContext context) {
    final background = settings.eyeCare
        ? const Color(0xFFF4F0E4)
        : Theme.of(context).colorScheme.surface;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
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
      body: SelectionArea(
        contextMenuBuilder: (context, selectableRegionState) {
          final buttonItems = selectableRegionState.contextMenuButtonItems;
          final copyButton = buttonItems.where((b) => b.type == ContextMenuButtonType.copy).toList();
          
          final customButtonItems = <ContextMenuButtonItem>[
            ...copyButton,
            ContextMenuButtonItem(
              onPressed: () {
                // ignore: deprecated_member_use
                final textValue = selectableRegionState.textEditingValue;
                final selectedText = textValue.selection.textInside(textValue.text);
                selectableRegionState.hideToolbar();
                if (selectedText.trim().isNotEmpty) {
                  onAiExplain(selectedText.trim());
                }
              },
              label: 'AI 解释',
            ),
          ];

          return AdaptiveTextSelectionToolbar.buttonItems(
            anchors: selectableRegionState.contextMenuAnchors,
            buttonItems: customButtonItems,
          );
        },
        child: ListView(
          controller: scrollController,
          padding: EdgeInsets.fromLTRB(
            settings.pagePadding,
            AtlasSpacing.md,
            settings.pagePadding,
            AtlasSpacing.xl,
          ),
          children: [
            if (document.summary.kind == DocumentKind.markdown)
              MarkdownBody(
                data: document.rawText,
                selectable: false,
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                    .copyWith(
                      p: settings.bodyStyle(context),
                      listBullet: settings.bodyStyle(context),
                      blockquote: settings.bodyStyle(context),
                      codeblockDecoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
              )
            else
              ...document.paragraphs.map(
                (paragraph) => Padding(
                  padding: const EdgeInsets.only(bottom: AtlasSpacing.md),
                  child: Text(
                    paragraph,
                    style: settings.bodyStyle(context),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: onAi,
        tooltip: 'AI 助手',
        child: const Icon(Icons.auto_awesome_outlined),
      ),
    );
  }
}

class _ReadingSettingsSheet extends ConsumerWidget {
  const _ReadingSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(readingSettingsProvider);
    final settings = settingsAsync.value;
    if (settings == null) {
      return const SizedBox.shrink();
    }

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
              min: 14,
              max: 24,
              divisions: 10,
              onChanged: (value) => ref
                  .read(readingSettingsProvider.notifier)
                  .updateSettings(settings.copyWith(fontSize: value)),
            ),
            Text('行距 ${settings.lineHeight.toStringAsFixed(2)}'),
            Slider(
              value: settings.lineHeight,
              min: 1.25,
              max: 2.1,
              divisions: 17,
              onChanged: (value) => ref
                  .read(readingSettingsProvider.notifier)
                  .updateSettings(settings.copyWith(lineHeight: value)),
            ),
            Text('页边距 ${settings.pagePadding.round()}'),
            Slider(
              value: settings.pagePadding,
              min: 12,
              max: 36,
              divisions: 12,
              onChanged: (value) => ref
                  .read(readingSettingsProvider.notifier)
                  .updateSettings(settings.copyWith(pagePadding: value)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('护眼纸色'),
              value: settings.eyeCare,
              onChanged: (value) => ref
                  .read(readingSettingsProvider.notifier)
                  .updateSettings(settings.copyWith(eyeCare: value)),
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
