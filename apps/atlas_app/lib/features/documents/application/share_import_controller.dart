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
      final initialMedia = await ReceiveSharingIntent.instance
          .getInitialMedia();
      await _handleSharedMedia(initialMedia);
      await ReceiveSharingIntent.instance.reset();
    } on MissingPluginException {
      await _subscription?.cancel();
      _subscription = null;
    }
  }

  Future<void> _handleSharedMedia(List<SharedMediaFile> files) async {
    for (final item in files) {
      final sharedFile = await _fileFromSharedMedia(item);
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

  Future<({File file, bool temporary})?> _fileFromSharedMedia(
    SharedMediaFile item,
  ) async {
    if (item.type == SharedMediaType.file) {
      return (file: File(item.path), temporary: false);
    }
    if (item.type == SharedMediaType.text || item.type == SharedMediaType.url) {
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/atlas-shared-${DateTime.now().microsecondsSinceEpoch}.txt',
      );
      await file.writeAsString(item.path, flush: true);
      return (file: file, temporary: true);
    }
    return null;
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
