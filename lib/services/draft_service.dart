import 'package:hive_flutter/hive_flutter.dart';

import '../models/draft_model.dart';

/// Mirrors data/local/dao/DraftDao.kt + AppDatabase.kt, using a Hive box instead of Room so
/// drafts also persist on Flutter Web (IndexedDB-backed there, no native adapters needed since
/// we only ever store plain Maps of primitives).
class DraftService {
  static const _boxName = 'drafts';

  Future<Box> _openBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return Hive.openBox(_boxName);
    }
    return Hive.box(_boxName);
  }

  Stream<List<Draft>> watchDrafts() async* {
    final box = await _openBox();
    yield _mapBoxToDrafts(box);
    await for (final _ in box.watch()) {
      yield _mapBoxToDrafts(box);
    }
  }

  List<Draft> _mapBoxToDrafts(Box box) {
    return box.keys
        .map((key) => Draft.fromMap(key as int, Map<dynamic, dynamic>.from(box.get(key) as Map)))
        .toList()
      ..sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
  }

  Future<int> insertDraft(Draft draft) async {
    final box = await _openBox();
    return box.add(draft.toMap());
  }

  Future<void> updateDraft(Draft draft) async {
    if (draft.id == null) return;
    final box = await _openBox();
    await box.put(draft.id, draft.toMap());
  }

  Future<void> deleteDraft(Draft draft) async {
    if (draft.id == null) return;
    final box = await _openBox();
    await box.delete(draft.id);
  }

  Future<void> deleteDraftById(int id) async {
    final box = await _openBox();
    await box.delete(id);
  }
}
