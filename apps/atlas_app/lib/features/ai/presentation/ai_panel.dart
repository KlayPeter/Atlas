import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../domain/document/document_content.dart';
import '../application/ai_models.dart';
import '../data/ai_api_client.dart';
import '../data/ai_history_repository.dart';

class AiPanel extends ConsumerStatefulWidget {
  const AiPanel({super.key, required this.document});

  final DocumentContent document;

  @override
  ConsumerState<AiPanel> createState() => _AiPanelState();
}

class _AiPanelState extends ConsumerState<AiPanel> {
  final _selectionController = TextEditingController();
  final _questionController = TextEditingController();
  AiResult? _result;
  List<AiHistoryEntry> _history = const [];
  Object? _error;
  var _loading = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _selectionController.dispose();
    _questionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            TextField(
              controller: _selectionController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '选中文本 / 段落',
                hintText: '粘贴需要解释的词、句子或段落',
              ),
            ),
            const SizedBox(height: AtlasSpacing.sm),
              Wrap(
              spacing: AtlasSpacing.sm,
              runSpacing: AtlasSpacing.sm,
              children: [
                FilledButton.icon(
                  onPressed: _loading ? null : _explain,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('解释'),
                ),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _summarize,
                  icon: const Icon(Icons.summarize_outlined),
                  label: const Text('总结全文'),
                ),
                OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          context.push(
                            AppRoutes.studyPath(widget.document.summary.id),
                            extra: widget.document,
                          );
                        },
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
            const SizedBox(height: AtlasSpacing.md),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Text(
                'AI 暂时不可用：$_error',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_result != null) _AiResultView(result: _result!),
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
                  onTap: () => setState(() => _result = entry.result),
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
  }) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final historyRepository = ref.read(aiHistoryRepositoryProvider);
      final cached = await historyRepository.findCached(
        documentId: widget.document.summary.id,
        kind: kind,
        prompt: prompt,
      );
      final result = cached?.result ?? await action();
      if (cached == null) {
        await historyRepository.save(
          documentId: widget.document.summary.id,
          kind: kind,
          prompt: prompt,
          result: result,
        );
      }
      setState(() => _result = result);
      await _loadHistory();
    } catch (error) {
      setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _explain() {
    final selectedText = _selectionController.text.trim();
    if (selectedText.isEmpty) {
      _selectionController.text = widget.document.paragraphs.firstOrNull ?? '';
    }
    final prompt = _selectionController.text.trim();
    return _run(
      kind: AiHistoryKind.explanation,
      prompt: prompt,
      action: () => ref
          .read(aiApiClientProvider)
          .explain(context: _context, selectedText: prompt),
    );
  }

  Future<void> _summarize() {
    return _run(
      kind: AiHistoryKind.summary,
      prompt: '全文总结',
      action: () => ref.read(aiApiClientProvider).summarize(_context),
    );
  }

  Future<void> _ask() async {
    final question = _questionController.text.trim();
    if (question.isEmpty) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _result = const AiResult(title: '问答', body: '');
    });
    final buffer = StringBuffer();
    try {
      await for (final chunk
          in ref
              .read(aiApiClientProvider)
              .askStream(context: _context, question: question)) {
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
      setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
}

class _AiResultView extends StatelessWidget {
  const _AiResultView({required this.result});

  final AiResult result;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AtlasSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(result.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AtlasSpacing.sm),
            Text(result.body),
            if (result.points.isNotEmpty) ...[
              const SizedBox(height: AtlasSpacing.sm),
              ...result.points.map((point) => Text('• $point')),
            ],
          ],
        ),
      ),
    );
  }
}
