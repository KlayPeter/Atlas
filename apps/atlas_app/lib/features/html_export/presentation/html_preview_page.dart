import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../app/theme/app_theme.dart';
import '../../../domain/document/document_content.dart';
import '../../documents/application/document_content_provider.dart';
import '../application/html_preview_generator.dart';

export '../application/html_preview_generator.dart' show HtmlPreviewMode;

class HtmlPreviewPage extends ConsumerStatefulWidget {
  const HtmlPreviewPage({
    super.key,
    required this.exportId,
    required this.mode,
  });

  final String? exportId;
  final HtmlPreviewMode mode;

  @override
  ConsumerState<HtmlPreviewPage> createState() => _HtmlPreviewPageState();
}

class _HtmlPreviewPageState extends ConsumerState<HtmlPreviewPage> {
  WebViewController? _controller;
  String? _filePath;
  bool _generating = true;
  bool _hasStartedGeneration = false;
  String? _errorMessage;
  String? _progressMessage;

  @override
  Widget build(BuildContext context) {
    final exportId = widget.exportId;
    if (exportId == null || exportId.isEmpty) {
      return const _HtmlPreviewError(message: '缺少导出 ID');
    }

    final document = ref.watch(documentContentProvider(exportId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('HTML 预览'),
        actions: [
          IconButton(
            tooltip: '分享 HTML',
            onPressed: _filePath == null
                ? null
                : () => Share.shareXFiles([XFile(_filePath!)]),
            icon: const Icon(Icons.ios_share),
          ),
        ],
      ),
      body: document.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _HtmlPreviewError(message: '生成失败：$error'),
        data: (content) {
          if (content == null) {
            return const _HtmlPreviewError(message: '找不到文档');
          }
          final controller = _controller;

          if (!_hasStartedGeneration) {
            _hasStartedGeneration = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _generatePreview(content);
            });
          }

          if (_errorMessage != null) {
            return _HtmlPreviewError(
              message: _errorMessage!,
              onRetry: () => _generatePreview(content),
            );
          }
          if (_generating || controller == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  if (_progressMessage != null) ...[
                    const SizedBox(height: AtlasSpacing.md),
                    Text(_progressMessage!),
                  ],
                ],
              ),
            );
          }
          return WebViewWidget(controller: controller);
        },
      ),
    );
  }

  Future<void> _generatePreview(DocumentContent content) async {
    setState(() {
      _generating = true;
      _errorMessage = null;
      _controller = null;
      _filePath = null;
      _progressMessage = widget.mode.requiresAi ? '正在准备 AI 易读版…' : null;
    });

    try {
      final file = await ref
          .read(htmlPreviewGeneratorProvider)
          .generate(
            content,
            widget.mode,
            onProgress: (completed, total) {
              if (!mounted) return;
              setState(() {
                _progressMessage = '正在改写 $completed/$total 段…';
              });
            },
          );
      if (!mounted) {
        return;
      }
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.disabled)
        ..loadFile(file.path);
      setState(() {
        _filePath = file.path;
        _controller = controller;
        _generating = false;
        _progressMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _generating = false;
        _progressMessage = null;
        _errorMessage = widget.mode.requiresAi
            ? '生成失败：$error\n\n请检查模型配置和网络连接，或点击重新生成。'
            : '生成失败：$error';
      });
    }
  }
}

class _HtmlPreviewError extends StatelessWidget {
  const _HtmlPreviewError({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AtlasSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: AtlasSpacing.md),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('重新生成'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
