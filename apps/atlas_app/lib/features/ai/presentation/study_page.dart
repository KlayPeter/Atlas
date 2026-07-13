import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../domain/ai/study_models.dart';
import '../../../domain/document/document_content.dart';
import '../../reader/application/reading_settings_controller.dart';
import '../../reader/presentation/reader_markdown_view.dart';
import '../application/ai_models.dart';
import '../data/ai_api_client.dart';

class StudyView extends ConsumerStatefulWidget {
  const StudyView({super.key, required this.document, required this.onBack});

  final DocumentContent document;
  final VoidCallback onBack;

  @override
  ConsumerState<StudyView> createState() => _StudyViewState();
}

class _StudyViewState extends ConsumerState<StudyView> {
  final _answerController = TextEditingController();
  var _loading = true;
  Object? _error;
  StudyResult? _result;
  var _currentIndex = 0;
  var _showAnswer = false;
  var _difficulty = 'basic';
  final Map<int, String> _answers = {};
  final Map<int, int> _confidence = {};

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final context = AiDocumentContext.fromDocument(widget.document);
      final result = await ref
          .read(aiApiClientProvider)
          .generateStudyQuestions(context: context, difficulty: _difficulty);
      if (mounted) {
        setState(() {
          _result = result;
          _currentIndex = 0;
          _showAnswer = false;
          _answers.clear();
          _confidence.clear();
          _answerController.clear();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  void _goToQuestion(int index) {
    _answers[_currentIndex] = _answerController.text.trim();
    setState(() {
      _currentIndex = index;
      _answerController.text = _answers[index] ?? '';
      _showAnswer = _confidence.containsKey(index);
    });
  }

  void _changeDifficulty(String difficulty) {
    if (difficulty == _difficulty || _loading) return;
    setState(() => _difficulty = difficulty);
    _loadQuestions();
  }

  Future<void> _finishStudy() async {
    final mastered = _confidence.values.where((value) => value == 2).length;
    final reviewing = _confidence.values.where((value) => value == 1).length;
    final unfamiliar = _confidence.values.where((value) => value == 0).length;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('本轮学习完成'),
        content: Text(
          '已掌握 $mastered 题 · 基本掌握 $reviewing 题 · 需要复习 $unfamiliar 题',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('完成'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: widget.onBack,
              tooltip: '返回',
            ),
            Text('学习模式', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            IconButton(
              tooltip: '关闭',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: AtlasSpacing.sm),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'basic', label: Text('基础')),
            ButtonSegment(value: 'advanced', label: Text('进阶')),
            ButtonSegment(value: 'challenge', label: Text('挑战')),
          ],
          selected: {_difficulty},
          onSelectionChanged: _loading
              ? null
              : (selection) => _changeDifficulty(selection.single),
        ),
        const SizedBox(height: AtlasSpacing.md),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(AtlasSpacing.xl),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: AtlasSpacing.md),
              Text('正在基于当前文档生成题目...'),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      final msg = _error.toString().startsWith('Exception: ')
          ? _error.toString().substring(11)
          : _error.toString();

      return Padding(
        padding: const EdgeInsets.all(AtlasSpacing.lg),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '生成题目失败\n$msg',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: AtlasSpacing.md),
              FilledButton(onPressed: _loadQuestions, child: const Text('重试')),
            ],
          ),
        ),
      );
    }

    final result = _result;
    if (result == null || result.questions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AtlasSpacing.xl),
        child: Center(child: Text('没有生成任何题目，请尝试其他文档。')),
      );
    }

    final question = result.questions[_currentIndex];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AtlasSpacing.sm),
      children: [
        LinearProgressIndicator(
          value: (_currentIndex + 1) / result.questions.length,
        ),
        const SizedBox(height: AtlasSpacing.md),
        Text(
          '题目 ${_currentIndex + 1} / ${result.questions.length}',
          style: Theme.of(context).textTheme.labelLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AtlasSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AtlasSpacing.lg),
            child: Text(
              question.question,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        const SizedBox(height: AtlasSpacing.sm),
        TextField(
          controller: _answerController,
          enabled: !_showAnswer,
          onChanged: (_) => setState(() {}),
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: '先写下你的回答',
            hintText: '答案只保留在本轮学习中',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: AtlasSpacing.sm),
        if (!_showAnswer)
          FilledButton.tonalIcon(
            onPressed: () {
              _answers[_currentIndex] = _answerController.text.trim();
              setState(() => _showAnswer = true);
            },
            icon: const Icon(Icons.visibility_outlined),
            label: Text(
              _answerController.text.trim().isEmpty ? '直接查看参考答案' : '对照参考答案',
            ),
          ),
        if (_showAnswer) ...[
          Text('参考答案', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AtlasSpacing.xs),
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(AtlasSpacing.md),
              child: ReaderMarkdownView(
                data: question.referenceAnswer,
                settings: const ReadingSettings(fontSize: 15, lineHeight: 1.5),
                compact: true,
              ),
            ),
          ),
          const SizedBox(height: AtlasSpacing.sm),
          Text('对照后，你掌握得怎么样？', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AtlasSpacing.xs),
          Wrap(
            spacing: AtlasSpacing.xs,
            children: [
              for (final entry in const [(0, '需要复习'), (1, '基本掌握'), (2, '已掌握')])
                ChoiceChip(
                  label: Text(entry.$2),
                  selected: _confidence[_currentIndex] == entry.$1,
                  onSelected: (_) => setState(() {
                    _confidence[_currentIndex] = entry.$1;
                  }),
                ),
            ],
          ),
        ],
        const SizedBox(height: AtlasSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _currentIndex > 0
                  ? () => _goToQuestion(_currentIndex - 1)
                  : null,
              child: const Text('上一题'),
            ),
            FilledButton(
              onPressed: !_showAnswer || !_confidence.containsKey(_currentIndex)
                  ? null
                  : _currentIndex < result.questions.length - 1
                  ? () => _goToQuestion(_currentIndex + 1)
                  : _finishStudy,
              child: Text(
                _currentIndex < result.questions.length - 1 ? '下一题' : '完成学习',
              ),
            ),
          ],
        ),
        const SizedBox(height: AtlasSpacing.md),
      ],
    );
  }
}
