import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../app/theme/app_theme.dart';
import '../application/library_controller.dart';

class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documents = ref.watch(libraryControllerProvider).recentDocuments();

    return Scaffold(
      appBar: AppBar(
        title: const Text('最近阅读'),
        actions: [
          IconButton(
            tooltip: '设置',
            onPressed: () => context.go(AppRoutes.settings),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: documents.isEmpty
          ? const _EmptyLibrary()
          : ListView.separated(
              padding: const EdgeInsets.all(AtlasSpacing.md),
              itemBuilder: (context, index) {
                final document = documents[index];
                return Card(
                  child: ListTile(
                    title: Text(document.title),
                    subtitle: Text('${document.wordCount} 字'),
                    onTap: () => context.go(AppRoutes.readerPath(document.id)),
                  ),
                );
              },
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AtlasSpacing.sm),
              itemCount: documents.length,
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.file_open_outlined),
        label: const Text('打开文件'),
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AtlasSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 56,
              color: colorScheme.primary,
            ),
            const SizedBox(height: AtlasSpacing.md),
            Text(
              '把 Markdown 和 TXT 放进更舒服的阅读环境',
              textAlign: TextAlign.center,
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: AtlasSpacing.sm),
            Text(
              '阶段 A 先完成应用骨架。下一阶段会接入文件选择、最近阅读和本地解析。',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
