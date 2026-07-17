import 'package:atlas_app/domain/ai/study_models.dart';
import 'package:atlas_app/domain/document/document_content.dart';
import 'package:atlas_app/domain/document/document_summary.dart';
import 'package:atlas_app/features/ai/application/ai_models.dart';
import 'package:atlas_app/features/ai/data/ai_api_client.dart';
import 'package:atlas_app/features/ai/data/ai_secrets_repository.dart';
import 'package:atlas_app/features/ai/presentation/study_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/memory_secure_value_store.dart';

void main() {
  testWidgets(
    'study mode supports difficulty, written answer, reveal, and self-rating',
    (tester) async {
      final client = _FakeAiApiClient();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [aiApiClientProvider.overrideWithValue(client)],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 800,
                child: StudyView(document: _document(), onBack: () {}),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(client.difficulties, ['basic']);
      expect(find.text('Atlas 是什么？'), findsOneWidget);

      await tester.tap(find.text('进阶'));
      await tester.pumpAndSettle();
      expect(client.difficulties, ['basic', 'advanced']);

      await tester.enterText(find.byType(TextField), '一个本地优先阅读器');
      tester.testTextInput.hide();
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('对照参考答案'),
        120,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('对照参考答案'));
      await tester.pump();
      expect(find.text('本地优先的 Markdown 阅读器。'), findsOneWidget);

      await tester.tap(find.text('已掌握'));
      await tester.pump();
      await tester.tap(find.text('下一题'));
      await tester.pumpAndSettle();
      expect(find.text('Atlas 支持什么格式？'), findsOneWidget);
    },
  );
}

class _FakeAiApiClient extends AiApiClient {
  _FakeAiApiClient()
    : super(secrets: AiSecretsRepository(MemorySecureValueStore()));

  final difficulties = <String>[];

  @override
  Future<StudyResult> generateStudyQuestions({
    required AiDocumentContext context,
    String difficulty = 'basic',
  }) async {
    difficulties.add(difficulty);
    return StudyResult(
      difficulty: difficulty,
      questions: const [
        StudyQuestion(
          question: 'Atlas 是什么？',
          referenceAnswer: '本地优先的 Markdown 阅读器。',
        ),
        StudyQuestion(
          question: 'Atlas 支持什么格式？',
          referenceAnswer: 'Markdown 和 TXT。',
        ),
      ],
    );
  }
}

DocumentContent _document() {
  return DocumentContent(
    summary: DocumentSummary(
      id: 'doc-1',
      title: 'Atlas',
      kind: DocumentKind.markdown,
      importedAt: DateTime(2026),
      filePath: 'prefs:doc-1',
      hash: 'hash',
    ),
    rawText: '# Atlas\n\nAtlas 是本地优先阅读器。',
    sections: const [],
    paragraphs: const [],
  );
}
