import 'dart:io';

import 'package:atlas_app/features/documents/application/share_import_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('atlas-share-test-');
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test(
    'opens an existing Markdown path even when Android labels it text',
    () async {
      final markdown = File('${tempDirectory.path}/meeting.md');
      await markdown.writeAsString('# Meeting notes');

      final result = await resolveSharedMediaFile(
        SharedMediaFile(
          path: markdown.path,
          type: SharedMediaType.text,
          mimeType: 'text/markdown',
        ),
        temporaryDirectory: tempDirectory,
      );

      expect(result, isNotNull);
      expect(result!.file.path, markdown.path);
      expect(result.temporary, isFalse);
      expect(await result.file.readAsString(), '# Meeting notes');
    },
  );

  test('keeps genuinely shared text as a temporary text document', () async {
    const sharedText = 'Plain text shared into Atlas';

    final result = await resolveSharedMediaFile(
      SharedMediaFile(path: sharedText, type: SharedMediaType.text),
      temporaryDirectory: tempDirectory,
    );

    expect(result, isNotNull);
    expect(result!.temporary, isTrue);
    expect(result.file.path, endsWith('.txt'));
    expect(await result.file.readAsString(), sharedText);
  });
}
