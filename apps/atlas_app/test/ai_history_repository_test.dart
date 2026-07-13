import 'package:atlas_app/features/ai/application/ai_models.dart';
import 'package:atlas_app/features/ai/data/ai_history_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'saves and finds cached ai result by document kind and prompt',
    () async {
      const repository = AiHistoryRepository();
      await repository.save(
        documentId: 'doc-1',
        kind: AiHistoryKind.explanation,
        prompt: 'local-first',
        result: const AiResult(title: '解释', body: '本地优先'),
      );

      final cached = await repository.findCached(
        documentId: 'doc-1',
        kind: AiHistoryKind.explanation,
        prompt: 'local-first',
      );
      final history = await repository.listForDocument('doc-1');

      expect(cached?.result.body, '本地优先');
      expect(history, hasLength(1));
    },
  );

  test('deletes only history belonging to the removed document', () async {
    const repository = AiHistoryRepository();
    for (final id in ['doc-1', 'doc-2']) {
      await repository.save(
        documentId: id,
        kind: AiHistoryKind.summary,
        prompt: '',
        result: const AiResult(title: '总结', body: '内容'),
      );
    }

    await repository.deleteForDocument('doc-1');

    expect(await repository.listForDocument('doc-1'), isEmpty);
    expect(await repository.listForDocument('doc-2'), hasLength(1));
  });
}
