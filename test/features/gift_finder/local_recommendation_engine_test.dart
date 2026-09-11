import 'package:flutter_test/flutter_test.dart';
import 'package:giftmap/features/gift_finder/data/local_recommendation_engine.dart';
import 'package:giftmap/features/gift_finder/domain/gift_category.dart';
import 'package:giftmap/features/gift_finder/domain/gift_intent.dart';
import 'package:giftmap/features/gift_finder/domain/gift_ruleset.dart';
import 'package:giftmap/features/gift_finder/domain/recommendation_result.dart';

import '../../fixtures/ruleset_fixture.dart';

GiftIntent intentOf({
  GiftSituation situation = GiftSituation.birthday,
  RelationshipType relationship = RelationshipType.friend,
  AgeBand ageBand = AgeBand.twenties,
  BudgetBand budget = BudgetBand.from30kTo50k,
  double preference = 0.5,
  List<String> avoidTags = const <String>[],
}) {
  return GiftIntent(
    situation: situation,
    relationship: relationship,
    ageBand: ageBand,
    budget: budget,
    preference: preference,
    avoidTags: avoidTags,
  );
}

void main() {
  late GiftRuleset ruleset;
  late LocalRecommendationEngine engine;

  setUp(() {
    ruleset = loadBundledRuleset();
    engine = LocalRecommendationEngine(ruleset);
  });

  test('번들 데이터는 최소 6개 카테고리를 제공한다', () {
    expect(ruleset.categories.length, greaterThanOrEqualTo(6));
  });

  test('모든 점수는 0..100 범위 안에 있다', () {
    for (final GiftSituation situation in GiftSituation.values) {
      for (final RelationshipType relationship in RelationshipType.values) {
        final GiftIntent intent = intentOf(
          situation: situation,
          relationship: relationship,
        );
        for (final GiftCategory category in ruleset.categories) {
          final int score = engine.evaluate(intent, category).score;
          expect(score, inInclusiveRange(0, 100));
        }
      }
    }
  });

  test('결과는 정확히 3개이고 카테고리가 중복되지 않는다', () {
    final RecommendationResult result = engine.recommend(intentOf());
    expect(result.items.length, 3);
    expect(
      result.items.map((GiftRecommendation i) => i.categoryId).toSet().length,
      3,
    );
  });

  test('회피 태그와 겹치는 카테고리는 추천에서 제외된다', () {
    final RecommendationResult result = engine.recommend(
      intentOf(avoidTags: <String>['scent', 'food']),
    );
    final Iterable<GiftCategory> picked = result.items.map(
      (GiftRecommendation item) => ruleset.categories.firstWhere(
        (GiftCategory c) => c.id == item.categoryId,
      ),
    );
    for (final GiftCategory category in picked) {
      expect(category.tags.contains('scent'), isFalse);
      expect(category.tags.contains('food'), isFalse);
    }
    expect(result.items.length, 3);
  });

  test('avoid 위험 규칙이 걸린 카테고리는 추천되지 않는다', () {
    // 상사 + 미용 태그(hand_care)는 avoid 규칙 대상이다.
    final RecommendationResult result = engine.recommend(
      intentOf(relationship: RelationshipType.manager),
    );
    expect(
      result.items.any((GiftRecommendation i) => i.categoryId == 'hand_care'),
      isFalse,
    );
  });

  test('위험 규칙은 점수를 낮추고 주의 문구를 남긴다', () {
    final GiftCategory fragrance = ruleset.categories.firstWhere(
      (GiftCategory c) => c.id == 'home_fragrance',
    );
    final int closeScore = engine
        .evaluate(intentOf(relationship: RelationshipType.friend), fragrance)
        .score;
    final int distantScore = engine
        .evaluate(
          intentOf(relationship: RelationshipType.acquaintance),
          fragrance,
        )
        .score;
    expect(distantScore, lessThan(closeScore));

    final RecommendationResult result = engine.recommend(
      intentOf(relationship: RelationshipType.acquaintance),
    );
    final GiftRecommendation? item = result.items
        .where((GiftRecommendation i) => i.categoryId == 'home_fragrance')
        .firstOrNull;
    if (item != null) {
      expect(item.caution, isNotEmpty);
      expect(item.riskLevel, RiskLevel.caution);
    }
  });

  test('같은 입력은 항상 같은 순서를 만든다', () {
    final List<String> first = engine
        .recommend(intentOf())
        .items
        .map((GiftRecommendation i) => i.categoryId)
        .toList();
    final List<String> second = engine
        .recommend(intentOf())
        .items
        .map((GiftRecommendation i) => i.categoryId)
        .toList();
    expect(second, first);
  });

  test('입력 조건이 달라지면 추천 순서도 달라진다', () {
    final List<String> practicalColleague = engine
        .recommend(
          intentOf(
            situation: GiftSituation.promotion,
            relationship: RelationshipType.colleague,
            preference: 0.1,
          ),
        )
        .items
        .map((GiftRecommendation i) => i.categoryId)
        .toList();
    final List<String> emotionalPartner = engine
        .recommend(
          intentOf(
            situation: GiftSituation.anniversary,
            relationship: RelationshipType.partner,
            preference: 0.9,
          ),
        )
        .items
        .map((GiftRecommendation i) => i.categoryId)
        .toList();
    expect(practicalColleague, isNot(equals(emotionalPartner)));
  });

  test('결과가 부족하면 safeDefault 카테고리로 보충한다', () {
    final RecommendationResult result = engine.recommend(
      intentOf(
        relationship: RelationshipType.manager,
        avoidTags: <String>['scent', 'experience', 'plant'],
      ),
    );
    expect(result.items.length, 3);
  });

  test('가격 근거가 없는 카테고리는 가격 필드가 모두 null이다', () {
    final GiftCategory voucher = ruleset.categories.firstWhere(
      (GiftCategory c) => c.id == 'experience_voucher',
    );
    expect(voucher.priceAvailable, isFalse);

    final RecommendationResult result = engine.recommend(
      intentOf(
        situation: GiftSituation.anniversary,
        relationship: RelationshipType.partner,
        preference: 0.9,
        budget: BudgetBand.from50kTo100k,
      ),
    );
    final GiftRecommendation? item = result.items
        .where((GiftRecommendation i) => i.categoryId == 'experience_voucher')
        .firstOrNull;
    expect(item, isNotNull);
    expect(item!.priceAvailable, isFalse);
    expect(item.marketLow, isNull);
    expect(item.marketMedian, isNull);
    expect(item.marketHigh, isNull);
  });

  test('검색어는 2~3개이고 비어 있지 않다', () {
    for (final GiftRecommendation item in engine.recommend(intentOf()).items) {
      expect(item.searchQueries.length, inInclusiveRange(2, 3));
      expect(
        item.searchQueries.every((String q) => q.trim().isNotEmpty),
        isTrue,
      );
    }
  });

  test('예산이 맞을수록 예산 적합도가 높다', () {
    final GiftCategory towel = ruleset.categories.firstWhere(
      (GiftCategory c) => c.id == 'premium_towel',
    );
    final int fit = engine.budgetFit(
      intentOf(budget: BudgetBand.from30kTo50k),
      towel,
    );
    final int misfit = engine.budgetFit(
      intentOf(budget: BudgetBand.under10k),
      towel,
    );
    expect(fit, greaterThan(misfit));
    expect(fit, inInclusiveRange(0, 15));
    expect(misfit, inInclusiveRange(0, 15));
  });
}
