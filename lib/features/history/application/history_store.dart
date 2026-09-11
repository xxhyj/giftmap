import 'package:flutter/foundation.dart';

import '../domain/history_entry.dart';

/// 기록 목록 화면과 홈 미리보기가 함께 구독하는 상태 보관소.
class HistoryStore extends ChangeNotifier {
  HistoryStore(this._repository);

  final HistoryRepository _repository;

  List<HistoryEntry> _entries = const <HistoryEntry>[];
  bool _loading = false;

  List<HistoryEntry> get entries => _entries;
  bool get isLoading => _loading;
  bool get isEmpty => !_loading && _entries.isEmpty;

  Future<void> refresh() async {
    _loading = true;
    notifyListeners();
    _entries = await _repository.loadAll();
    _loading = false;
    notifyListeners();
  }

  Future<void> add(HistoryEntry entry) async {
    await _repository.save(entry);
    _entries = await _repository.loadAll();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    await _repository.delete(id);
    _entries = await _repository.loadAll();
    notifyListeners();
  }

  Future<void> clear() async {
    await _repository.clear();
    _entries = await _repository.loadAll();
    notifyListeners();
  }

  /// 상황 라벨로 거른 목록. 필터 칩이 사용한다.
  List<HistoryEntry> filtered(String? situationLabel) {
    if (situationLabel == null) return _entries;
    return _entries
        .where((HistoryEntry e) => e.intent.situation.label == situationLabel)
        .toList(growable: false);
  }
}
