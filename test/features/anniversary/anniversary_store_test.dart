import 'package:flutter_test/flutter_test.dart';
import 'package:giftmap/features/anniversary/application/anniversary_store.dart';
import 'package:giftmap/features/anniversary/data/in_memory_anniversary_repository.dart';
import 'package:giftmap/features/anniversary/domain/anniversary.dart';
import 'package:giftmap/features/gift_finder/domain/gift_intent.dart';

Anniversary anniversaryOf({
  required String id,
  required DateTime date,
  String name = '민지',
}) {
  return Anniversary(
    id: id,
    displayName: name,
    relationship: RelationshipType.friend,
    situation: GiftSituation.birthday,
    date: date,
  );
}

void main() {
  late AnniversaryStore store;
  final DateTime now = DateTime(2026, 9, 11);

  setUp(() {
    store = AnniversaryStore(InMemoryAnniversaryRepository());
  });

  test('처음에는 비어 있다', () async {
    await store.refresh();
    expect(store.isEmpty, isTrue);
  });

  test('추가하면 목록에 남는다', () async {
    await store.add(anniversaryOf(id: 'a', date: DateTime(2026, 9, 18)));
    expect(store.sorted(now).length, 1);
    expect(store.isEmpty, isFalse);
  });

  test('가까운 기념일이 먼저 정렬된다', () async {
    await store.add(
      anniversaryOf(id: 'far', date: DateTime(2026, 12, 25), name: '부모님'),
    );
    await store.add(anniversaryOf(id: 'near', date: DateTime(2026, 9, 18)));

    expect(store.sorted(now).map((Anniversary a) => a.id).toList(), <String>[
      'near',
      'far',
    ]);
  });

  test('D-day는 지난 날짜를 내년으로 계산한다', () {
    final Anniversary passed = anniversaryOf(
      id: 'p',
      date: DateTime(2026, 9, 1),
    );
    expect(passed.daysUntil(now), greaterThan(300));
    expect(
      anniversaryOf(id: 't', date: DateTime(2026, 9, 11)).dDayLabel(now),
      'D-DAY',
    );
    expect(
      anniversaryOf(id: 'w', date: DateTime(2026, 9, 18)).dDayLabel(now),
      'D-7',
    );
  });

  test('삭제하면 목록에서 사라진다', () async {
    await store.add(anniversaryOf(id: 'a', date: DateTime(2026, 9, 18)));
    await store.remove('a');
    expect(store.isEmpty, isTrue);
  });

  test('전체 삭제는 모든 기념일을 비운다', () async {
    await store.add(anniversaryOf(id: 'a', date: DateTime(2026, 9, 18)));
    await store.add(anniversaryOf(id: 'b', date: DateTime(2026, 10, 2)));
    await store.clear();
    expect(store.isEmpty, isTrue);
  });
}
