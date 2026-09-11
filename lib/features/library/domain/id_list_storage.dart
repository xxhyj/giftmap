/// 상품 id 목록을 로컬에 보관하는 최소 저장 계약.
///
/// 찜과 최근 본 상품이 같은 계약을 공유한다. 네트워크를 쓰지 않는다.
abstract interface class IdListStorage {
  Future<List<String>> read(String key);

  Future<void> write(String key, List<String> ids);
}

/// 저장소 키.
abstract final class LibraryKeys {
  static const String favorites = 'giftmap.favorites.v1';
  static const String recentlyViewed = 'giftmap.recently_viewed.v1';
}
