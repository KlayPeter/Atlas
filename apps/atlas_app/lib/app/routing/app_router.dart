import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/html_export/presentation/html_preview_page.dart';
import '../../features/library/presentation/library_page.dart';
import '../../features/reader/presentation/reader_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import 'app_routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.library,
    redirect: (context, state) {
      final uriString = state.uri.toString();
      if (uriString.startsWith('content://') || uriString.startsWith('file://')) {
        return AppRoutes.library;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.library,
        builder: (context, state) => const LibraryPage(),
      ),
      GoRoute(
        path: AppRoutes.reader,
        builder: (context, state) {
          final documentId = state.pathParameters['documentId'];
          return ReaderPage(documentId: documentId);
        },
      ),
      GoRoute(
        path: AppRoutes.htmlPreview,
        builder: (context, state) {
          final exportId = state.pathParameters['exportId'];
          final mode = state.extra as HtmlPreviewMode?;
          return HtmlPreviewPage(
            exportId: exportId,
            mode: mode ?? HtmlPreviewMode.summary,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsPage(),
      ),
    ],
    errorBuilder: (context, state) => UnknownRoutePage(error: state.error),
  );
});

class UnknownRoutePage extends StatelessWidget {
  const UnknownRoutePage({super.key, this.error});

  final Exception? error;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Atlas')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.explore_off_outlined,
                size: 48,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text('找不到这个页面', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                error?.toString() ?? '这个入口暂时不可用。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
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
