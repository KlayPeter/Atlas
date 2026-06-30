import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../app/theme/app_theme.dart';

class ReaderPage extends StatelessWidget {
  const ReaderPage({super.key, required this.documentId});

  final String? documentId;

  @override
  Widget build(BuildContext context) {
    if (documentId == null || documentId!.isEmpty) {
      return const _MissingDocumentPage();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('文档 $documentId'),
        actions: [
          IconButton(
            tooltip: '搜索',
            onPressed: () {},
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: 'AI',
            onPressed: () {},
            icon: const Icon(Icons.auto_awesome_outlined),
          ),
          IconButton(
            tooltip: '阅读设置',
            onPressed: () {},
            icon: const Icon(Icons.text_fields),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AtlasSpacing.lg,
          AtlasSpacing.md,
          AtlasSpacing.lg,
          AtlasSpacing.xl,
        ),
        children: [
          Text('阅读器骨架', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AtlasSpacing.md),
          const Text(
            '这里会承载 Markdown / TXT 渲染、目录、搜索、阅读进度、选区解释和 AI 面板。'
            '当前页面只放置阶段 A 的导航和布局锚点。',
          ),
          const SizedBox(height: AtlasSpacing.lg),
          OutlinedButton.icon(
            onPressed: () => context.go(AppRoutes.htmlPreviewPath('draft')),
            icon: const Icon(Icons.web_asset_outlined),
            label: const Text('预览 HTML 导出骨架'),
          ),
        ],
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
              const Text('缺少文档 ID'),
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
