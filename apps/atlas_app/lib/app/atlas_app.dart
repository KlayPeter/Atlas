import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/documents/application/share_import_controller.dart';
import 'routing/app_router.dart';
import 'theme/app_theme.dart';

class AtlasApp extends ConsumerWidget {
  const AtlasApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return _ShareImportBootstrap(
      router: router,
      child: MaterialApp.router(
        title: 'Atlas',
        debugShowCheckedModeBanner: false,
        theme: AtlasTheme.light(),
        darkTheme: AtlasTheme.dark(),
        themeMode: themeMode,
        routerConfig: router,
      ),
    );
  }
}

class _ShareImportBootstrap extends ConsumerWidget {
  const _ShareImportBootstrap({required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(shareImportControllerProvider(router));
    return child;
  }
}
