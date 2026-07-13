import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../domain/document/document_content.dart';
import '../application/ai_document_workflows.dart';
import '../application/ai_models.dart';
import '../data/ai_api_client.dart';
import '../data/ai_history_repository.dart';
import '../../reader/application/reading_settings_controller.dart';
import '../../reader/presentation/reader_markdown_view.dart';

import 'study_page.dart';

class AiPanel extends ConsumerStatefulWidget {
  const AiPanel({super.key, required this.document, this.initialSelection});

  final DocumentContent document;
  final String? initialSelection;

  @override
  ConsumerState<AiPanel> createState() => _AiPanelState();
}

class _AiPanelState extends ConsumerState<AiPanel> {
  final _questionController = TextEditingController();
  AiResult? _result;
  AiHistoryEntry? _activeEntry;
  List<AiHistoryEntry> _history = const [];
  Object? _error;
  var _loading = false;
  var _isStudyMode = false;
  var _disposed = false;
  String? _loadingLabel;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    if (widget.initialSelection != null &&
        widget.initialSelection!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _explain();
      });
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _questionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isStudyMode) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: AtlasSpacing.md,
            right: AtlasSpacing.md,
            top: AtlasSpacing.md,
            bottom: MediaQuery.viewInsetsOf(context).bottom + AtlasSpacing.md,
          ),
          child: StudyView(
            document: widget.document,
            onBack: () => setState(() => _isStudyMode = false),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: AtlasSpacing.md,
          right: AtlasSpacing.md,
          top: AtlasSpacing.md,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AtlasSpacing.md,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Row(
              children: [
                Text('AI 阅读助手', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: AtlasSpacing.sm),
            Text(
              '先选一个阅读任务，也可以直接提出基于全文的问题。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AtlasSpacing.sm),
            Wrap(
              spacing: AtlasSpacing.sm,
              runSpacing: AtlasSpacing.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: _loading ? null : _summarize,
                  icon: const Icon(Icons.summarize_outlined),
                  label: const Text('总结全文'),
                ),
                OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () => setState(() => _isStudyMode = true),
                  icon: const Icon(Icons.school_outlined),
                  label: const Text('进入学习模式'),
                ),
              ],
            ),
            const SizedBox(height: AtlasSpacing.md),
            TextField(
              controller: _questionController,
              decoration: InputDecoration(
                labelText: '基于全文提问',
                suffixIcon: IconButton(
                  tooltip: '发送',
                  onPressed: _loading ? null : _ask,
                  icon: const Icon(Icons.send),
                ),
              ),
              onSubmitted: (_) => _ask(),
            ),
            const SizedBox(height: AtlasSpacing.sm),
            Wrap(
              spacing: AtlasSpacing.xs,
              runSpacing: AtlasSpacing.xs,
              children: [
                for (final suggestion in const [
                  '这篇文章的核心结论是什么？',
                  '有哪些关键概念？',
                  '作者的论证链路是什么？',
                ])
                  ActionChip(
                    label: Text(suggestion),
                    onPressed: _loading
                        ? null
                        : () {
                            _questionController.text = suggestion;
                            _ask();
                          },
                  ),
              ],
            ),
            const SizedBox(height: AtlasSpacing.md),
            if (_loading) ...[
              const LinearProgressIndicator(),
              if (_loadingLabel != null) ...[
                const SizedBox(height: AtlasSpacing.xs),
                Text(
                  _loadingLabel!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
            if (_error != null)
              Builder(
                builder: (context) {
                  final msg = _error.toString().startsWith('Exception: ')
                      ? _error.toString().substring(11)
                      : _error.toString();
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AtlasSpacing.sm),
                      child: Text(
                        msg,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  );
                },
              ),
            if (_result != null)
              _AiResultView(
                result: _result!,
                onRegenerate: (_activeEntry != null && !_loading)
                    ? () => _regenerateEntry(_activeEntry!)
                    : null,
              ),
            if (_history.isNotEmpty) ...[
              const SizedBox(height: AtlasSpacing.md),
              Text('历史', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AtlasSpacing.sm),
              ..._history.map(
                (entry) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.result.title),
                  subtitle: Text(
                    entry.prompt,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => setState(() {
                    _result = entry.result;
                    _activeEntry = entry;
                  }),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  AiDocumentContext get _context =>
      AiDocumentContext.fromDocument(widget.document);

  Future<void> _loadHistory() async {
    final history = await ref
        .read(aiHistoryRepositoryProvider)
        .listForDocument(widget.document.summary.id);
    if (mounted) {
      setState(() => _history = history);
    }
  }

  Future<void> _run({
    required AiHistoryKind kind,
    required String prompt,
    required Future<AiResult> Function() action,
    bool forceRefresh = false,
    String loadingLabel = '正在生成…',
  }) async {
    setState(() {
      _loading = true;
      _loadingLabel = loadingLabel;
      _error = null;
    });
    try {
      final historyRepository = ref.read(aiHistoryRepositoryProvider);
      AiHistoryEntry? cached;
      if (!forceRefresh) {
        cached = await historyRepository.findCached(
          documentId: widget.document.summary.id,
          kind: kind,
          prompt: prompt,
        );
      }
      final result = cached?.result ?? await action();

      // Save or update cache
      await historyRepository.save(
        documentId: widget.document.summary.id,
        kind: kind,
        prompt: prompt,
        result: result,
      );

      // Load history to get the updated entry with ID
      final newHistory = await historyRepository.listForDocument(
        widget.document.summary.id,
      );
      final entry = newHistory
          .where((e) => e.kind == kind && e.prompt == prompt)
          .firstOrNull;

      if (mounted) {
        setState(() {
          _result = result;
          _history = newHistory;
          _activeEntry = entry;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingLabel = null;
        });
      }
    }
  }

  Future<void> _explain() {
    final prompt = widget.initialSelection?.trim() ?? '';
    if (prompt.isEmpty) return Future.value();

    return _run(
      kind: AiHistoryKind.explanation,
      prompt: prompt,
      action: () => ref
          .read(aiApiClientProvider)
          .explain(context: _context, selectedText: prompt),
    );
  }

  Future<void> _summarize({bool forceRefresh = false}) {
    return _run(
      kind: AiHistoryKind.summary,
      prompt: '全文总结（分段覆盖）',
      action: () {
        final client = ref.read(aiApiClientProvider);
        return summarizeFullDocument(
          widget.document,
          summarize: client.summarize,
        );
      },
      forceRefresh: forceRefresh,
      loadingLabel: '正在分段阅读并生成全文总结…',
    );
  }

  Future<void> _regenerateEntry(AiHistoryEntry entry) async {
    if (entry.kind == AiHistoryKind.summary) {
      await _summarize(forceRefresh: true);
    } else if (entry.kind == AiHistoryKind.explanation) {
      await _run(
        kind: AiHistoryKind.explanation,
        prompt: entry.prompt,
        action: () => ref
            .read(aiApiClientProvider)
            .explain(context: _context, selectedText: entry.prompt),
        forceRefresh: true,
      );
    } else if (entry.kind == AiHistoryKind.question) {
      // Questions use askStream, regenerating is a bit complex, just populate the input
      _questionController.text = entry.prompt;
      await _ask();
    }
  }

  Future<void> _ask() async {
    final question = _questionController.text.trim();
    if (question.isEmpty) {
      return;
    }
    setState(() {
      _loading = true;
      _loadingLabel = '正在检索全文片段并组织答案…';
      _error = null;
      _result = const AiResult(title: '问答', body: '');
    });
    final buffer = StringBuffer();
    try {
      final client = ref.read(aiApiClientProvider);
      await for (final chunk in askFullDocument(
        widget.document,
        question,
        ask: (context, question) =>
            client.ask(context: context, question: question),
        askStream: (context, question) =>
            client.askStream(context: context, question: question),
      )) {
        if (_disposed) {
          break;
        }
        buffer.write(chunk);
        if (mounted) {
          setState(
            () => _result = AiResult(title: '问答', body: buffer.toString()),
          );
        }
      }
      final result = AiResult(title: '问答', body: buffer.toString());
      await ref
          .read(aiHistoryRepositoryProvider)
          .save(
            documentId: widget.document.summary.id,
            kind: AiHistoryKind.question,
            prompt: question,
            result: result,
          );
      await _loadHistory();
    } catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingLabel = null;
        });
      }
    }
  }
}

class _AiResultView extends StatelessWidget {
  const _AiResultView({required this.result, this.onRegenerate});

  final AiResult result;
  final VoidCallback? onRegenerate;

  @override
  Widget build(BuildContext context) {
    final uniquePoints = result.points
        .where((point) => !result.body.contains(point))
        .toList(growable: false);
    final markdown = [
      result.body,
      if (uniquePoints.isNotEmpty) ...[
        '',
        ...uniquePoints.map((point) => '- $point'),
      ],
    ].join('\n');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AtlasSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    result.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (onRegenerate != null)
                  IconButton(
                    tooltip: '重新生成',
                    onPressed: onRegenerate,
                    icon: const Icon(Icons.refresh, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: AtlasSpacing.sm),
            ReaderMarkdownView(
              data: markdown,
              settings: const ReadingSettings(fontSize: 15, lineHeight: 1.5),
              compact: true,
            ),
          ],
        ),
      ),
    );
  }
}
