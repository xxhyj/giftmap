import 'package:flutter_test/flutter_test.dart';
import 'package:giftmap/features/gift_finder/data/local_recommendation_engine.dart';
import 'package:giftmap/features/gift_finder/data/product_recommendation_engine.dart';
import 'package:giftmap/features/gift_finder/domain/gift_intent.dart';
import 'package:giftmap/features/gift_finder/domain/gift_ruleset.dart';
import 'package:giftmap/features/products/domain/product.dart';
import 'package:giftmap/features/products/domain/product_catalog.dart';

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
  late ProductRecommendationEngine engine;
  late ProductCatalog catalog;
  late GiftRuleset ruleset;

  setUp(() {
    catalog = loadBundledCatalog();
    ruleset = loadBundledRuleset();
    engine = ProductRecommendationEngine(catalog: catalog, ruleset: ruleset);
  });

  test('추천 결과는 상품 단위이며 충분한 개수를 돌려준다', () {
    final List<ProductPick> picks = engine.recommend(intentOf());
    expect(picks.length, greaterThanOrEqualTo(8));
    expect(
      picks.map((ProductPick p) => p.product.id).toSet().length,
      picks.length,
    );
  });

  test('같은 입력은 항상 같은 순서를 만든다', () {
    final List<String> first = engine
        .recommend(intentOf())
        .map((ProductPick p) => p.product.id)
        .toList();
    final List<String> second = engine
        .recommend(intentOf())
        .map((ProductPick p) => p.product.id)
        .toList();
    expect(second, first);
  });

  test('모든 점수는 0..100 범위 안에 있다', () {
    for (final GiftSituation situation in GiftSituation.values) {
      for (final ProductPick pick in engine.recommend(
        intentOf(situation: situation),
      )) {
        expect(pick.score, inInclusiveRange(0, 100));
      }
    }
  });

  test('회피 태그와 겹치는 상품은 제외된다', () {
    final List<ProductPick> picks = engine.recommend(
      intentOf(avoidTags: <String>['scent', 'food']),
    );
    for (final ProductPick pick in picks) {
      expect(pick.product.tags.contains('scent'), isFalse);
      expect(pick.product.tags.contains('food'), isFalse);
    }
  });

  test('위험 규칙이 avoid인 조합은 추천되지 않는다', () {
    // 상사 + 미용 태그는 avoid 규칙 대상이다.
    final List<ProductPick> picks = engine.recommend(
      intentOf(relationship: RelationshipType.manager),
    );
    expect(
      picks.any((ProductPick p) => p.product.tags.contains('beauty')),
      isFalse,
    );
  });

  test('예산을 크게 넘는 상품은 예산 점수를 거의 받지 못한다', () {
    final Product expensive = catalog.products.reduce(
      (Product a, Product b) => a.sortPrice >= b.sortPrice ? a : b,
    );
    final int fitInBudget = engine.budgetFit(
      intentOf(budget: BudgetBand.from50kTo100k),
      expensive,
    );
    final int fitOverBudget = engine.budgetFit(
      intentOf(budget: BudgetBand.under10k),
      expensive,
    );
    expect(fitOverBudget, lessThan(fitInBudget));
    expect(fitOverBudget, inInclusiveRange(0, 25));
  });

  test('상황이 맞는 상품이 더 높은 점수를 받는다', () {
    final Product housewarming = catalog.products.firstWhere(
      (Product p) =>
          p.occasions.contains(GiftSituation.housewarming) &&
          !p.occasions.contains(GiftSituation.promotion),
    );
    final ProductPick? matched = engine.evaluate(
      intentOf(situation: GiftSituation.housewarming),
      housewarming,
    );
    final ProductPick? unmatched = engine.evaluate(
      intentOf(situation: GiftSituation.promotion),
      housewarming,
    );
    expect(matched!.score, greaterThan(unmatched!.score));
  });

  test('받는 사람이 맞는 상품이 더 높은 점수를 받는다', () {
    final Product forPartner = catalog.products.firstWhere(
      (Product p) =>
          p.recipientTypes.contains(RelationshipType.partner) &&
          !p.recipientTypes.contains(RelationshipType.colleague),
    );
    final ProductPick? matched = engine.evaluate(
      intentOf(relationship: RelationshipType.partner),
      forPartner,
    );
    final ProductPick? unmatched = engine.evaluate(
      intentOf(relationship: RelationshipType.colleague),
      forPartner,
    );
    expect(matched!.score, greaterThan(unmatched!.score));
  });

  test('카테고리 추천 방향이 상품 순서에 반영된다', () {
    final LocalRecommendationEngine categoryEngine = LocalRecommendationEngine(
      ruleset,
    );
    final GiftIntent intent = intentOf(
      situation: GiftSituation.housewarming,
      relationship: RelationshipType.family,
    );
    final List<ProductPick> withDirections = engine.recommend(
      intent,
      directions: categoryEngine.recommend(intent).items,
    );
    expect(withDirections, isNotEmpty);
    expect(withDirections.first.score, greaterThan(0));
  });

  test('상품이 없으면 빈 목록을 돌려준다', () {
    final ProductRecommendationEngine empty = ProductRecommendationEngine(
      catalog: ProductCatalog(
        products: const <Product>[],
        version: 'empty',
        disclaimer: '데모',
      ),
      ruleset: ruleset,
    );
    expect(empty.recommend(intentOf()), isEmpty);
  });

  test('조건이 좁아도 최소한의 상품을 보충한다', () {
    final List<ProductPick> picks = engine.recommend(
      intentOf(
        situation: GiftSituation.birth,
        relationship: RelationshipType.manager,
        budget: BudgetBand.under10k,
      ),
      limit: 6,
    );
    expect(picks.length, greaterThanOrEqualTo(3));
  });

  test('추천 이유와 배지는 비어 있지 않다', () {
    for (final ProductPick pick in engine.recommend(intentOf())) {
      expect(pick.badge.trim(), isNotEmpty);
      expect(pick.reason.trim(), isNotEmpty);
    }
  });
}
