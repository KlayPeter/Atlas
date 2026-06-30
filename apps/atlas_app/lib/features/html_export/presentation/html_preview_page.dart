import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';

class HtmlPreviewPage extends StatelessWidget {
  const HtmlPreviewPage({super.key, required this.exportId});

  final String? exportId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HTML 预览')),
      body: Padding(
        padding: const EdgeInsets.all(AtlasSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('导出任务', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AtlasSpacing.sm),
            Text(exportId ?? '未指定'),
            const SizedBox(height: AtlasSpacing.lg),
            const Text('阶段 D 会在这里接入 WebView、HTML 模板、保存与分享。'),
          ],
        ),
      ),
    );
  }
}
