import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../domain/ai/study_models.dart';
import '../../../domain/document/document_content.dart';
import '../application/ai_models.dart';
import '../data/ai_api_client.dart';

class StudyView extends ConsumerStatefulWidget {
  const StudyView({
    super.key,
    required this.document,
    required this.onBack,
  });

  final DocumentContent document;
  final VoidCallback onBack;

  @override
  ConsumerState<StudyView> createState() => _StudyViewState();
}

class _StudyViewState extends ConsumerState<StudyView> {
  var _loading = true;
  Object? _error;
  StudyResult? _result;
  int _currentIndex = 0;
  bool _showAnswer = false;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
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
          .generateStudyQuestions(context: context);
      if (mounted) {
        setState(() {
          _result = result;
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

  void _nextQuestion() {
    if (_result == null) return;
    if (_currentIndex < _result!.questions.length - 1) {
      setState(() {
        _currentIndex++;
        _showAnswer = false;
      });
    }
  }

  void _prevQuestion() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _showAnswer = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
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
        const SizedBox(height: AtlasSpacing.md),
        _buildBody(),
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
              FilledButton(
                onPressed: _loadQuestions,
                child: const Text('重试'),
              ),
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AtlasSpacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
            child: InkWell(
              onTap: () => setState(() => _showAnswer = !_showAnswer),
              child: Padding(
                padding: const EdgeInsets.all(AtlasSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      question.question,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AtlasSpacing.md),
                    if (_showAnswer)
                      Text(
                        question.referenceAnswer,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      )
                    else
                      const Text('点击卡片查看答案',
                          style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AtlasSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _currentIndex > 0 ? _prevQuestion : null,
                child: const Text('上一题'),
              ),
              FilledButton(
                onPressed: _currentIndex < result.questions.length - 1
                    ? _nextQuestion
                    : null,
                child: const Text('下一题'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
