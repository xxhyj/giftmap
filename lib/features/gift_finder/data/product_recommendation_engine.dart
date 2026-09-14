import 'dart:math' as math;

import '../../products/domain/product.dart';
import '../../products/domain/product_catalog.dart';
import '../domain/gift_intent.dart';
import '../domain/gift_ruleset.dart';
import '../domain/recommendation_result.dart';
import '../domain/risk_rule.dart';

/// 추천된 상품 한 건과 그 이유.
class ProductPick {
  const ProductPick({
    required this.product,
    required this.score,
    required this.riskLevel,
    required this.badge,
    required this.reason,
  });

  final Product product;

  /// 0..100.
  final int score;
  final RiskLevel riskLevel;

  /// 카드에 붙는 짧은 배지 문구.
  final String badge;

  /// 상세 화면에서 보여줄 추천 이유.
  final String reason;
}

/// 사용자 조건에 맞는 상품을 점수화해 정렬하는 결정론적 엔진.
///
/// 카테고리 단위 추천(`LocalRecommendationEngine`)이 정한 "추천 방향"을
/// 보너스로 반영하고, 최종 결과는 상품 단위로 돌려준다.
/// 같은 입력에는 항상 같은 순서를 만든다(동점은 상품 id 오름차순).
class ProductRecommendationEngine {
  const ProductRecommendationEngine({
    required ProductCatalog Function() catalog,
    required this.ruleset,
  }) : // 이름 있는 매개변수는 private 이름을 쓸 수 없어 초기화 목록으로 대입한다.
       // ignore: prefer_initializing_formals
       _catalog = catalog;

  /// 카탈로그는 상품을 이어 받으며 늘어난다. 고정해 두면 나중에 받은 상품이
  /// 추천 후보에서 빠지므로, 부를 때마다 지금 것을 읽는다.
  final ProductCatalog Function() _catalog;

  ProductCatalog get catalog => _catalog();
  final GiftRuleset ruleset;

  /// 카테고리 추천(선물 방향) → 상품 카테고리 연결.
  static const Map<String, List<String>> directionMap = <String, List<String>>{
    'home_fragrance': <String>['candle', 'perfume'],
    'tea_set': <String>['tea_coffee', 'dessert'],
    'desk_accessory': <String>['desk', 'stationery'],
    'premium_towel': <String>['homewear', 'living'],
    'hand_care': <String>['hand_care', 'body_care', 'beauty'],
    'mobile_accessory': <String>['tumbler', 'desk', 'living'],
    'experience_voucher': <String>['hobby'],
    'plant_gift': <String>['hobby', 'living'],
  };

  /// 태그로 추정하는 상품의 실용↔감성 성향. 0.0 실용적 ~ 1.0 감성적.
  static const Map<String, double> _tagPreference = <String, double>{
    'practical': 0.1,
    'office': 0.15,
    'digital': 0.2,
    'home': 0.45,
    'food': 0.5,
    'beauty': 0.6,
    'scent': 0.75,
    'plant': 0.75,
    'hobby': 0.8,
    'strongTaste': 0.85,
    'sizing': 0.5,
  };

  /// 조건에 맞는 상품을 점수 순으로 돌려준다.
  ///
  /// [directions]는 카테고리 추천 결과이며, 비어 있어도 동작한다.
  List<ProductPick> recommend(
    GiftIntent intent, {
    List<GiftRecommendation> directions = const <GiftRecommendation>[],
    int limit = 20,
  }) {
    final Map<String, int> bonuses = _directionBonuses(directions);

    final List<ProductPick> picks = <ProductPick>[];
    // 품절이 확인된 상품은 추천하지 않는다.
    for (final Product product in catalog.sellable) {
      final ProductPick? pick = evaluate(
        intent,
        product,
        directionBonus: bonuses[product.category] ?? 0,
      );
      if (pick != null) picks.add(pick);
    }

    picks.sort((ProductPick a, ProductPick b) {
      final int byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.product.id.compareTo(b.product.id);
    });

    if (picks.length >= 3) return _spread(picks, limit);

    // 조건이 지나치게 좁아 결과가 부족하면 예산만 맞춘 안전한 상품으로 보충한다.
    return _withFallback(intent, picks, limit);
  }

  /// 같은 분류·브랜드가 앞자리를 채우지 않게 벌려 놓는다.
  ///
  /// 점수만으로 자르면 책처럼 상품 수가 많은 분류가 3~5칸을 다 가져가
  /// 비슷한 선물만 늘어놓게 된다. 분류는 2개, 브랜드는 1개까지만 앞세우고
  /// 밀려난 상품은 뒤에 그대로 둔다(점수 순서는 그대로다).
  static List<ProductPick> _spread(List<ProductPick> picks, int limit) {
    final Map<String, int> byCategory = <String, int>{};
    final Map<String, int> byBrand = <String, int>{};
    final List<ProductPick> front = <ProductPick>[];
    final List<ProductPick> rest = <ProductPick>[];

    for (final ProductPick pick in picks) {
      final String category = pick.product.category;
      final String brand = (pick.product.brandName ?? '').toLowerCase();
      final int categoryUsed = byCategory[category] ?? 0;
      final int brandUsed = brand.isEmpty ? 0 : (byBrand[brand] ?? 0);
      if (categoryUsed >= 2 || brandUsed >= 1) {
        rest.add(pick);
        continue;
      }
      byCategory[category] = categoryUsed + 1;
      if (brand.isNotEmpty) byBrand[brand] = brandUsed + 1;
      front.add(pick);
    }

    return <ProductPick>[...front, ...rest].take(limit).toList(growable: false);
  }

  /// 상품 한 건의 점수. 제외 대상이면 null을 돌려준다.
  ///
  /// base 30 / 상황 0..25 / 관계 0..20 / 예산 0..25 / 취향 0..10 /
  /// 연령 0..5 / 방향 보너스 0..12 / 위험 패널티 0..-50 → 0..100
  ProductPick? evaluate(
    GiftIntent intent,
    Product product, {
    int directionBonus = 0,
  }) {
    if (product.tags.any(intent.avoidTags.contains)) return null;

    final List<RiskRule> matched = ruleset.rules
        .where((RiskRule rule) => rule.matchesTags(intent, product.tags))
        .toList(growable: false);
    final RiskLevel riskLevel = _riskLevel(matched);
    if (riskLevel == RiskLevel.avoid) return null;

    final bool occasionMatch = product.occasions.contains(intent.situation);
    final bool recipientMatch = product.recipientTypes.contains(
      intent.relationship,
    );
    final int budgetPoints = budgetFit(intent, product);
    final double productPreference = preferenceOf(product);
    final int preferencePoints =
        (10 * (1 - (intent.preference - productPreference).abs())).round();
    final bool ageMatch =
        intent.ageBand == AgeBand.unspecified ||
        product.ageRange.isEmpty ||
        product.ageRange.contains(intent.ageBand);

    var score = 30;
    score += occasionMatch ? 25 : 0;
    score += recipientMatch ? 20 : 0;
    score += budgetPoints;
    score += preferencePoints;
    score += ageMatch ? 5 : 0;
    score += directionBonus;
    // 마지막 확인이 오래된 상품은 가격·재고가 달라졌을 수 있어 뒤로 보낸다.
    score -= product.isStale() ? 8 : 0;
    score -= _riskPenalty(matched);

    return ProductPick(
      product: product,
      score: score.clamp(0, 100),
      riskLevel: riskLevel,
      badge: _badge(
        intent: intent,
        product: product,
        budgetPoints: budgetPoints,
        occasionMatch: occasionMatch,
        riskLevel: riskLevel,
      ),
      reason: _reason(
        intent: intent,
        product: product,
        budgetPoints: budgetPoints,
        occasionMatch: occasionMatch,
        recipientMatch: recipientMatch,
        cautions: matched
            .map((RiskRule rule) => rule.message)
            .where((String m) => m.isNotEmpty)
            .toList(growable: false),
      ),
    );
  }

  /// 예산 적합도 0..25. 예산을 넘기면 크게 깎는다.
  ///
  /// 가격을 알 수 없는 상품은 예산으로 판단할 수 없으므로 중간값을 준다.
  int budgetFit(GiftIntent intent, Product product) {
    final int? price = product.price;
    if (price == null) return 10;

    final BudgetRange range = intent.budgetRange;
    if (price >= range.min && price <= range.max) return 25;

    if (price > range.max) {
      final int over = price - range.max;
      final double ratio = over / math.max(1, range.max);
      if (ratio <= 0.15) return 10;
      if (ratio <= 0.4) return 3;
      return 0;
    }

    // 예산보다 저렴한 경우는 과하게 깎지 않는다.
    final int under = range.min - price;
    final double ratio = under / math.max(1, range.min);
    if (ratio <= 0.25) return 16;
    if (ratio <= 0.6) return 8;
    return 2;
  }

  /// 태그 평균으로 추정한 상품의 실용↔감성 성향.
  static double preferenceOf(Product product) {
    final List<double> values = product.tags
        .map((String tag) => _tagPreference[tag])
        .nonNulls
        .toList(growable: false);
    if (values.isEmpty) return 0.5;
    return values.reduce((double a, double b) => a + b) / values.length;
  }

  Map<String, int> _directionBonuses(List<GiftRecommendation> directions) {
    final Map<String, int> bonuses = <String, int>{};
    const List<int> weights = <int>[12, 8, 5];
    for (int i = 0; i < directions.length && i < weights.length; i++) {
      for (final String category
          in directionMap[directions[i].categoryId] ?? const <String>[]) {
        final int existing = bonuses[category] ?? 0;
        bonuses[category] = math.max(existing, weights[i]);
      }
    }
    return bonuses;
  }

  List<ProductPick> _withFallback(
    GiftIntent intent,
    List<ProductPick> picks,
    int limit,
  ) {
    final Set<String> taken = picks
        .map((ProductPick p) => p.product.id)
        .toSet();
    final List<Product> extras = catalog.sellable
        .where((Product p) => !taken.contains(p.id))
        .where((Product p) => !p.tags.any(intent.avoidTags.contains))
        .toList();
    extras.sort((Product a, Product b) {
      final int byBudget = budgetFit(intent, b).compareTo(budgetFit(intent, a));
      return byBudget != 0 ? byBudget : a.id.compareTo(b.id);
    });

    final List<ProductPick> filled = List<ProductPick>.of(picks);
    for (final Product product in extras) {
      if (filled.length >= math.max(3, math.min(limit, 6))) break;
      filled.add(
        ProductPick(
          product: product,
          score: 0,
          riskLevel: RiskLevel.safe,
          badge: '두루 무난해요',
          reason: '조건에 꼭 맞는 상품이 적어 무난하게 선택되는 상품을 함께 보여드려요.',
        ),
      );
    }
    return filled.take(limit).toList(growable: false);
  }

  RiskLevel _riskLevel(List<RiskRule> matched) {
    if (matched.any((RiskRule r) => r.level == RiskLevel.avoid)) {
      return RiskLevel.avoid;
    }
    if (matched.any((RiskRule r) => r.level == RiskLevel.caution)) {
      return RiskLevel.caution;
    }
    return RiskLevel.safe;
  }

  int _riskPenalty(List<RiskRule> matched) => matched
      .fold<int>(0, (int sum, RiskRule rule) => sum + rule.penalty)
      .clamp(0, 50);

  String _badge({
    required GiftIntent intent,
    required Product product,
    required int budgetPoints,
    required bool occasionMatch,
    required RiskLevel riskLevel,
  }) {
    if (product.hasDiscount) return '${product.discountRate}% 할인 중';
    if (budgetPoints == 25) return '예산에 딱 맞아요';
    if (occasionMatch) return '${intent.situation.label} 선물로 무난해요';
    if (riskLevel == RiskLevel.safe) return '취향 부담이 적어요';
    return '두루 어울려요';
  }

  String _reason({
    required GiftIntent intent,
    required Product product,
    required int budgetPoints,
    required bool occasionMatch,
    required bool recipientMatch,
    required List<String> cautions,
  }) {
    final List<String> parts = <String>[];
    if (budgetPoints >= 16) parts.add('예산 범위에 잘 맞아요');
    if (occasionMatch) parts.add('${intent.situation.label} 선물로 자주 선택돼요');
    if (recipientMatch) parts.add('${intent.relationship.label}에게 어울려요');
    if (parts.isEmpty) parts.add(product.recommendationReason);
    return parts.join(' · ');
  }
}
