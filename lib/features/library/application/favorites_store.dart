import 'package:flutter/foundation.dart';

import '../domain/id_list_storage.dart';

/// 찜한 상품 id를 관리한다. 앱 전체에서 이 하나의 상태만 본다.
class FavoritesStore extends ChangeNotifier {
  FavoritesStore(this._storage);

  final IdListStorage _storage;

  final List<String> _ids = <String>[];
  bool _loaded = false;

  /// 최근에 찜한 상품이 앞에 온다.
  List<String> get ids => List<String>.unmodifiable(_ids);
  int get count => _ids.length;
  bool get isLoaded => _loaded;
  bool get isEmpty => _loaded && _ids.isEmpty;

  bool contains(String productId) => _ids.contains(productId);

  Future<void> load() async {
    _ids
      ..clear()
      ..addAll(await _storage.read(LibraryKeys.favorites));
    _loaded = true;
    notifyListeners();
  }

  /// 찜 상태를 뒤집고 결과(찜 여부)를 돌려준다. 중복 저장하지 않는다.
  Future<bool> toggle(String productId) async {
    final bool added = !_ids.remove(productId);
    if (added) _ids.insert(0, productId);
    notifyListeners();
    await _storage.write(LibraryKeys.favorites, _ids);
    return added;
  }

  Future<void> remove(String productId) async {
    if (!_ids.remove(productId)) return;
    notifyListeners();
    await _storage.write(LibraryKeys.favorites, _ids);
  }

  Future<void> clear() async {
    _ids.clear();
    notifyListeners();
    await _storage.write(LibraryKeys.favorites, _ids);
  }
}
