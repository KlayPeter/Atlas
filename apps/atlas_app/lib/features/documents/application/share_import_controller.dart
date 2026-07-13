import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../../app/routing/app_routes.dart';
import '../../library/application/library_controller.dart';
import '../data/document_repository.dart';

typedef SharedImportFile = ({File file, bool temporary});

@visibleForTesting
Future<SharedImportFile?> resolveSharedMediaFile(
  SharedMediaFile item, {
  Directory? temporaryDirectory,
}) async {
  final existingFile = File(item.path);
  if (await existingFile.exists()) {
    return (file: existingFile, temporary: false);
  }

  if (item.type == SharedMediaType.file) {
    return (file: existingFile, temporary: false);
  }
  if (item.type == SharedMediaType.text || item.type == SharedMediaType.url) {
    final tempDir = temporaryDirectory ?? await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}/atlas-shared-${DateTime.now().microsecondsSinceEpoch}.txt',
    );
    await file.writeAsString(item.path, flush: true);
    return (file: file, temporary: true);
  }
  return null;
}

final shareImportControllerProvider =
    Provider.family<ShareImportController, GoRouter>((ref, router) {
      final controller = ShareImportController(
        repository: ref.read(documentRepositoryProvider),
        router: router,
        ref: ref,
      );
      controller.start();
      ref.onDispose(controller.dispose);
      return controller;
    });

class ShareImportController {
  ShareImportController({
    required this.repository,
    required this.router,
    required this.ref,
  });

  final DocumentRepository repository;
  final GoRouter router;
  final Ref ref;
  StreamSubscription<List<SharedMediaFile>>? _subscription;
  var _started = false;

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;

    if (!_supportsShareImport) {
      return;
    }

    try {
      _subscription = ReceiveSharingIntent.instance.getMediaStream().listen(
        _handleSharedMedia,
        onError: (_) {},
      );
      
      Future.delayed(const Duration(milliseconds: 250), () async {
        final initialMedia = await ReceiveSharingIntent.instance.getInitialMedia();
        if (initialMedia.isNotEmpty) {
          await _handleSharedMedia(initialMedia);
          await ReceiveSharingIntent.instance.reset();
        }
      });
    } on MissingPluginException {
      await _subscription?.cancel();
      _subscription = null;
    }
  }

  Future<void> _handleSharedMedia(List<SharedMediaFile> files) async {
    for (final item in files) {
      final sharedFile = await resolveSharedMediaFile(item);
      if (sharedFile == null) {
        continue;
      }
      try {
        final document = await repository.importFile(sharedFile.file);
        await ref.read(libraryControllerProvider.notifier).refresh();
        router.push(AppRoutes.readerPath(document.id));
      } on DocumentImportFailure {
        continue;
      } finally {
        if (sharedFile.temporary && await sharedFile.file.exists()) {
          await sharedFile.file.delete();
        }
      }
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
  }

  bool get _supportsShareImport {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }
}
