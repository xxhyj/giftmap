import 'package:flutter/foundation.dart';

import '../domain/id_list_storage.dart';

/// 최근 본 상품 id를 관리한다.
///
/// 가장 최근에 본 상품이 앞에 오고, 같은 상품은 중복 없이 앞으로 이동한다.
class RecentlyViewedStore extends ChangeNotifier {
  RecentlyViewedStore(this._storage, {this.maxItems = 50});

  final IdListStorage _storage;

  /// 보관 상한. 넘으면 오래된 항목부터 버린다.
  final int maxItems;

  final List<String> _ids = <String>[];
  bool _loaded = false;

  List<String> get ids => List<String>.unmodifiable(_ids);
  bool get isLoaded => _loaded;
  bool get isEmpty => _loaded && _ids.isEmpty;

  Future<void> load() async {
    _ids
      ..clear()
      ..addAll(await _storage.read(LibraryKeys.recentlyViewed));
    _trim();
    _loaded = true;
    notifyListeners();
  }

  /// 상품 상세를 열 때 호출한다.
  Future<void> markViewed(String productId) async {
    if (_ids.isNotEmpty && _ids.first == productId) return;
    _ids
      ..remove(productId)
      ..insert(0, productId);
    _trim();
    notifyListeners();
    await _storage.write(LibraryKeys.recentlyViewed, _ids);
  }

  Future<void> remove(String productId) async {
    if (!_ids.remove(productId)) return;
    notifyListeners();
    await _storage.write(LibraryKeys.recentlyViewed, _ids);
  }

  Future<void> clear() async {
    _ids.clear();
    notifyListeners();
    await _storage.write(LibraryKeys.recentlyViewed, _ids);
  }

  void _trim() {
    if (_ids.length <= maxItems) return;
    _ids.removeRange(maxItems, _ids.length);
  }
}
