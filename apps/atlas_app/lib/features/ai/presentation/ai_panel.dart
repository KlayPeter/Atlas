import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../domain/document/document_content.dart';
import '../application/ai_models.dart';
import '../data/ai_api_client.dart';

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
  Object? _error;
  var _loading = false;

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
          ],
        ),
      ),
    );
  }

  AiDocumentContext get _context =>
      AiDocumentContext.fromDocument(widget.document);

  Future<void> _run(Future<AiResult> Function() action) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await action();
      setState(() => _result = result);
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
    return _run(
      () => ref
          .read(aiApiClientProvider)
          .explain(
            context: _context,
            selectedText: _selectionController.text.trim(),
          ),
    );
  }

  Future<void> _summarize() {
    return _run(() => ref.read(aiApiClientProvider).summarize(_context));
  }

  Future<void> _ask() {
    final question = _questionController.text.trim();
    if (question.isEmpty) {
      return Future.value();
    }
    return _run(
      () => ref
          .read(aiApiClientProvider)
          .ask(context: _context, question: question),
    );
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
