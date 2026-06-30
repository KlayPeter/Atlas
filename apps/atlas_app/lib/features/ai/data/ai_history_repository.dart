import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../application/ai_models.dart';

final aiHistoryRepositoryProvider = Provider<AiHistoryRepository>((ref) {
  return const AiHistoryRepository();
});

class AiHistoryRepository {
  const AiHistoryRepository();

  static const _historyKey = 'atlas.ai.history.v1';

  Future<List<AiHistoryEntry>> listForDocument(String documentId) async {
    final entries = await _readAll();
    return entries.where((entry) => entry.documentId == documentId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<AiHistoryEntry?> findCached({
    required String documentId,
    required AiHistoryKind kind,
    required String prompt,
  }) async {
    final entries = await listForDocument(documentId);
    return entries
        .where(
          (entry) => entry.kind == kind && entry.prompt.trim() == prompt.trim(),
        )
        .firstOrNull;
  }

  Future<AiHistoryEntry> save({
    required String documentId,
    required AiHistoryKind kind,
    required String prompt,
    required AiResult result,
  }) async {
    final now = DateTime.now();
    final entry = AiHistoryEntry(
      id: const Uuid().v4(),
      documentId: documentId,
      kind: kind,
      prompt: prompt.trim(),
      result: AiResult(
        title: result.title,
        body: result.body,
        points: result.points,
        createdAt: now,
      ),
      createdAt: now,
    );
    final entries = await _readAll();
    final deduped = entries.where(
      (item) =>
          !(item.documentId == documentId &&
              item.kind == kind &&
              item.prompt.trim() == prompt.trim()),
    );
    await _writeAll([entry, ...deduped].take(80).toList());
    return entry;
  }

  Future<List<AiHistoryEntry>> _readAll() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_historyKey) ?? const [])
        .map((raw) => AiHistoryEntry.fromJson(jsonDecode(raw)))
        .toList();
  }

  Future<void> _writeAll(List<AiHistoryEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _historyKey,
      entries.map((entry) => jsonEncode(entry.toJson())).toList(),
    );
  }
}
