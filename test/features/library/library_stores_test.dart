import 'package:flutter_test/flutter_test.dart';
import 'package:giftmap/features/library/application/favorites_store.dart';
import 'package:giftmap/features/library/application/recently_viewed_store.dart';
import 'package:giftmap/features/library/data/in_memory_id_list_storage.dart';
import 'package:giftmap/features/library/domain/id_list_storage.dart';

void main() {
  group('찜', () {
    late IdListStorage storage;
    late FavoritesStore store;

    setUp(() async {
      storage = InMemoryIdListStorage();
      store = FavoritesStore(storage);
      await store.load();
    });

    test('처음에는 비어 있다', () {
      expect(store.isEmpty, isTrue);
      expect(store.count, 0);
    });

    test('추가하면 contains가 true가 된다', () async {
      await store.toggle('perfume_01');
      expect(store.contains('perfume_01'), isTrue);
      expect(store.count, 1);
    });

    test('같은 상품을 두 번 눌러도 중복 저장되지 않는다', () async {
      await store.toggle('perfume_01');
      await store.toggle('perfume_01');
      expect(store.contains('perfume_01'), isFalse);
      expect(store.ids.where((String id) => id == 'perfume_01').length, 0);

      await store.toggle('perfume_01');
      await store.toggle('perfume_01');
      await store.toggle('perfume_01');
      expect(store.ids.where((String id) => id == 'perfume_01').length, 1);
    });

    test('삭제하면 목록에서 사라진다', () async {
      await store.toggle('perfume_01');
      await store.remove('perfume_01');
      expect(store.isEmpty, isTrue);
    });

    test('최근에 찜한 상품이 앞에 온다', () async {
      await store.toggle('a');
      await store.toggle('b');
      expect(store.ids, <String>['b', 'a']);
    });

    test('저장소에 남아 앱을 다시 켜도 유지된다', () async {
      await store.toggle('perfume_01');
      final FavoritesStore reopened = FavoritesStore(storage);
      await reopened.load();
      expect(reopened.contains('perfume_01'), isTrue);
    });

    test('전체 삭제는 목록을 비운다', () async {
      await store.toggle('a');
      await store.clear();
      expect(store.isEmpty, isTrue);
    });
  });

  group('최근 본 상품', () {
    late IdListStorage storage;
    late RecentlyViewedStore store;

    setUp(() async {
      storage = InMemoryIdListStorage();
      store = RecentlyViewedStore(storage, maxItems: 5);
      await store.load();
    });

    test('상세를 열면 목록에 추가된다', () async {
      await store.markViewed('a');
      expect(store.ids, <String>['a']);
    });

    test('최신순으로 정렬되고 중복이 생기지 않는다', () async {
      await store.markViewed('a');
      await store.markViewed('b');
      await store.markViewed('a');
      expect(store.ids, <String>['a', 'b']);
    });

    test('최대 개수를 넘으면 오래된 항목부터 버린다', () async {
      for (final String id in <String>['a', 'b', 'c', 'd', 'e', 'f']) {
        await store.markViewed(id);
      }
      expect(store.ids.length, 5);
      expect(store.ids.contains('a'), isFalse);
      expect(store.ids.first, 'f');
    });

    test('저장소에 남아 앱을 다시 켜도 유지된다', () async {
      await store.markViewed('a');
      final RecentlyViewedStore reopened = RecentlyViewedStore(storage);
      await reopened.load();
      expect(reopened.ids, <String>['a']);
    });

    test('개별 삭제와 전체 삭제가 동작한다', () async {
      await store.markViewed('a');
      await store.markViewed('b');
      await store.remove('a');
      expect(store.ids, <String>['b']);
      await store.clear();
      expect(store.isEmpty, isTrue);
    });
  });
}
