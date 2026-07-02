import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../domain/document/document_summary.dart';
import '../application/library_controller.dart';

class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documents = ref.watch(libraryControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('最近阅读'),
        actions: [
          IconButton(
            tooltip: '设置',
            onPressed: () => context.push(AppRoutes.settings),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: documents.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _LibraryError(error: error),
        data: (items) => items.isEmpty
            ? const _EmptyLibrary()
            : RefreshIndicator(
                onRefresh: () =>
                    ref.read(libraryControllerProvider.notifier).refresh(),
                child: ListView.separated(
                  padding: const EdgeInsets.all(AtlasSpacing.md),
                  itemBuilder: (context, index) {
                    final document = items[index];
                    final progress = (document.progress * 100).round();
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          document.kind == DocumentKind.markdown
                              ? Icons.article_outlined
                              : Icons.notes_outlined,
                        ),
                        title: Text(document.title),
                        subtitle: Text(
                          '${document.kind.label} · ${document.wordCount} 字 · $progress%',
                        ),
                        trailing: IconButton(
                          tooltip: '删除记录',
                          onPressed: () => ref
                              .read(libraryControllerProvider.notifier)
                              .deleteDocument(document.id),
                          icon: const Icon(Icons.delete_outline),
                        ),
                        onTap: () =>
                            context.push(AppRoutes.readerPath(document.id)),
                      ),
                    );
                  },
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: AtlasSpacing.sm),
                  itemCount: items.length,
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          final router = GoRouter.of(context);
          final document = await ref
              .read(libraryControllerProvider.notifier)
              .importDocument();
          if (document != null) {
            router.push(AppRoutes.readerPath(document.id));
          } else if (context.mounted) {
            messenger.showSnackBar(const SnackBar(content: Text('未导入文件')));
          }
        },
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
              '从系统文件选择 Markdown 或 TXT。Atlas 会复制到本地沙盒，生成目录并记录阅读进度。',
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

class _LibraryError extends ConsumerWidget {
  const _LibraryError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AtlasSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
              size: 44,
            ),
            const SizedBox(height: AtlasSpacing.md),
            Text('导入或读取失败：$error', textAlign: TextAlign.center),
            const SizedBox(height: AtlasSpacing.md),
            FilledButton.icon(
              onPressed: () =>
                  ref.read(libraryControllerProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
