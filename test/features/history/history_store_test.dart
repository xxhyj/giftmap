import 'package:flutter_test/flutter_test.dart';
import 'package:giftmap/features/gift_finder/domain/gift_intent.dart';
import 'package:giftmap/features/gift_finder/domain/recommendation_result.dart';
import 'package:giftmap/features/history/application/history_store.dart';
import 'package:giftmap/features/history/data/in_memory_history_repository.dart';
import 'package:giftmap/features/history/domain/history_entry.dart';

HistoryEntry entryOf({
  required String id,
  GiftSituation situation = GiftSituation.birthday,
}) {
  final GiftIntent intent = GiftIntent(
    situation: situation,
    relationship: RelationshipType.friend,
    ageBand: AgeBand.twenties,
    budget: BudgetBand.from30kTo50k,
    preference: 0.5,
  );
  return HistoryEntry(
    id: id,
    intent: intent,
    result: RecommendationResult(
      apiVersion: '1.0',
      intent: intent,
      items: const <GiftRecommendation>[
        GiftRecommendation(
          categoryId: 'tea_set',
          title: '티웨어·차 세트',
          fitScore: 80,
          riskLevel: RiskLevel.safe,
          reason: '무난한 선택',
          caution: '',
          searchQueries: <String>['차 선물세트'],
          highlights: <String>[],
        ),
      ],
      generatedAt: DateTime(2026, 9, 11),
      usedFallback: false,
    ),
    createdAt: DateTime(2026, 9, 11),
  );
}

void main() {
  late HistoryStore store;

  setUp(() {
    store = HistoryStore(InMemoryHistoryRepository());
  });

  test('처음에는 비어 있다', () async {
    await store.refresh();
    expect(store.isEmpty, isTrue);
  });

  test('저장하면 최신 항목이 앞에 온다', () async {
    await store.add(entryOf(id: 'a'));
    await store.add(entryOf(id: 'b'));
    expect(store.entries.map((HistoryEntry e) => e.id).toList(), <String>[
      'b',
      'a',
    ]);
  });

  test('삭제하면 목록에서 사라진다', () async {
    await store.add(entryOf(id: 'a'));
    await store.remove('a');
    expect(store.entries, isEmpty);
  });

  test('전체 삭제는 모든 항목을 비운다', () async {
    await store.add(entryOf(id: 'a'));
    await store.add(entryOf(id: 'b'));
    await store.clear();
    expect(store.entries, isEmpty);
  });

  test('상황 라벨로 필터링한다', () async {
    await store.add(entryOf(id: 'a'));
    await store.add(entryOf(id: 'b', situation: GiftSituation.housewarming));
    expect(store.filtered('집들이').length, 1);
    expect(store.filtered(null).length, 2);
  });

  test('요약 문구는 추천 개수를 반영한다', () {
    expect(entryOf(id: 'a').summary, '티웨어·차 세트');
    expect(entryOf(id: 'a').title, '20대 친구 · 생일');
  });
}
