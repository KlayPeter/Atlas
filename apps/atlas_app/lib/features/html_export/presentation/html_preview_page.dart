import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../app/theme/app_theme.dart';
import '../../../domain/document/document_content.dart';
import '../../ai/application/ai_models.dart';
import '../../ai/data/ai_api_client.dart';
import '../../documents/application/document_content_provider.dart';
import '../application/html_export_service.dart';

class HtmlPreviewPage extends ConsumerStatefulWidget {
  const HtmlPreviewPage({super.key, required this.exportId, required this.mode});

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

          if (_generating || controller == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_errorMessage != null) {
            return _HtmlPreviewError(message: _errorMessage!);
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
    });

    try {
      final enhance = await ref
          .read(aiApiClientProvider)
          .enhanceHtml(
            context: AiDocumentContext.fromDocument(content),
            mode: widget.mode.apiValue,
          );
      final file = await ref
          .read(htmlExportServiceProvider)
          .writeHtml(content, enhance: enhance);
      if (!mounted) {
        return;
      }
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadFile(file.path);
      setState(() {
        _filePath = file.path;
        _controller = controller;
        _generating = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _generating = false;
        _errorMessage =
            '生成失败：$error\n\n请到设置里的 AI 模型配置检查 Atlas BFF 地址、API Key、Base URL 和模型名称。';
      });
    }
  }
}

enum HtmlPreviewMode {
  summary('summary'),
  original('original');

  const HtmlPreviewMode(this.apiValue);

  final String apiValue;
}

class _HtmlPreviewError extends StatelessWidget {
  const _HtmlPreviewError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AtlasSpacing.lg),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
