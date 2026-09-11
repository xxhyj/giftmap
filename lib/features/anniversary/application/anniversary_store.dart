import 'package:flutter/foundation.dart';

import '../domain/anniversary.dart';

class AnniversaryStore extends ChangeNotifier {
  AnniversaryStore(this._repository);

  final AnniversaryRepository _repository;

  List<Anniversary> _items = const <Anniversary>[];
  bool _loading = false;

  bool get isLoading => _loading;
  bool get isEmpty => !_loading && _items.isEmpty;

  /// 가까운 기념일이 먼저 오도록 정렬한 목록.
  List<Anniversary> sorted(DateTime now) {
    final List<Anniversary> copy = List<Anniversary>.of(_items);
    copy.sort((Anniversary a, Anniversary b) {
      final int byDays = a.daysUntil(now).compareTo(b.daysUntil(now));
      return byDays != 0 ? byDays : a.displayName.compareTo(b.displayName);
    });
    return copy;
  }

  Future<void> refresh() async {
    _loading = true;
    notifyListeners();
    _items = await _repository.loadAll();
    _loading = false;
    notifyListeners();
  }

  Future<void> add(Anniversary anniversary) async {
    await _repository.save(anniversary);
    _items = await _repository.loadAll();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    await _repository.delete(id);
    _items = await _repository.loadAll();
    notifyListeners();
  }

  Future<void> clear() async {
    await _repository.clear();
    _items = await _repository.loadAll();
    notifyListeners();
  }
}
