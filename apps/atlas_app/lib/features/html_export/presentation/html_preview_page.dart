import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../app/theme/app_theme.dart';
import '../../../domain/document/document_content.dart';
import '../../documents/application/document_content_provider.dart';
import '../application/html_export_service.dart';

class HtmlPreviewPage extends ConsumerStatefulWidget {
  const HtmlPreviewPage({super.key, required this.exportId});

  final String? exportId;

  @override
  ConsumerState<HtmlPreviewPage> createState() => _HtmlPreviewPageState();
}

class _HtmlPreviewPageState extends ConsumerState<HtmlPreviewPage> {
  WebViewController? _controller;
  String? _filePath;

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
                : () => SharePlus.instance.share(
                    ShareParams(files: [XFile(_filePath!)]),
                  ),
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
          _ensureController(content);
          final controller = _controller;
          if (controller == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return WebViewWidget(controller: controller);
        },
      ),
    );
  }

  Future<void> _ensureController(DocumentContent content) async {
    if (_controller != null) {
      return;
    }
    final file = await ref.read(htmlExportServiceProvider).writeHtml(content);
    if (!mounted) {
      return;
    }
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled)
      ..loadFile(file.path);
    setState(() {
      _filePath = file.path;
      _controller = controller;
    });
  }
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
