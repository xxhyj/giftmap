import '../domain/anniversary.dart';

/// MVP 저장소. 영속화는 저장 패키지 승인 후 같은 계약으로 교체한다.
final class InMemoryAnniversaryRepository implements AnniversaryRepository {
  final List<Anniversary> _items = <Anniversary>[];

  @override
  Future<List<Anniversary>> loadAll() async =>
      List<Anniversary>.unmodifiable(_items);

  @override
  Future<void> save(Anniversary anniversary) async {
    _items
      ..removeWhere((Anniversary a) => a.id == anniversary.id)
      ..add(anniversary);
  }

  @override
  Future<void> delete(String id) async {
    _items.removeWhere((Anniversary a) => a.id == id);
  }

  @override
  Future<void> clear() async => _items.clear();
}
