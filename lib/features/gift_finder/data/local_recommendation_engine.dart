import 'dart:math' as math;

import '../domain/gift_category.dart';
import '../domain/gift_intent.dart';
import '../domain/gift_ruleset.dart';
import '../domain/recommendation_result.dart';
import '../domain/risk_rule.dart';

/// 규칙 적용 결과(점수 + 위험도 + 주의 문구).
class CategoryScore {
  const CategoryScore({
    required this.category,
    required this.score,
    required this.riskLevel,
    required this.cautions,
    required this.excluded,
  });

  final GiftCategory category;
  final int score;
  final RiskLevel riskLevel;
  final List<String> cautions;

  /// 회피 태그 충돌로 추천 대상에서 제외됐는지 여부.
  final bool excluded;
}

/// 결정적 로컬 점수 엔진.
///
/// 같은 입력에는 항상 같은 순서를 만들어야 한다. 동점은 `categoryId`
/// 오름차순으로 정렬해 재현성을 확보한다.
class LocalRecommendationEngine {
  const LocalRecommendationEngine(this.ruleset);

  final GiftRuleset ruleset;

  static const String apiVersion = '1.0';
  static const String mockAffiliateHost = 'mock.giftmap.app';

  RecommendationResult recommend(
    GiftIntent intent, {
    bool usedFallback = false,
  }) {
    final List<CategoryScore> scored =
        ruleset.categories
            .map((GiftCategory c) => evaluate(intent, c))
            .where((CategoryScore s) => !s.excluded)
            .where((CategoryScore s) => s.riskLevel != RiskLevel.avoid)
            .toList()
          ..sort(_byScoreThenId);

    final List<CategoryScore> picked = <CategoryScore>[];
    final Set<String> usedGroups = <String>{};
    for (final CategoryScore candidate in scored) {
      if (picked.length == 3) break;
      if (!usedGroups.add(candidate.category.group)) continue;
      picked.add(candidate);
    }

    // 그룹 제한으로 3개를 못 채우면 safeDefault, 그다음 남은 후보로 보충한다.
    if (picked.length < 3) {
      for (final bool safeOnly in <bool>[true, false]) {
        for (final CategoryScore candidate in scored) {
          if (picked.length == 3) break;
          if (safeOnly && !candidate.category.safeDefault) continue;
          if (picked.contains(candidate)) continue;
          picked.add(candidate);
        }
      }
    }

    final List<GiftRecommendation> items = picked
        .map((CategoryScore s) => _toRecommendation(intent, s))
        .toList(growable: false);
    final List<GiftRecommendation> alternates = scored
        .where((CategoryScore s) => !picked.contains(s))
        .map((CategoryScore s) => _toRecommendation(intent, s))
        .toList(growable: false);

    return RecommendationResult(
      apiVersion: apiVersion,
      intent: intent,
      items: items,
      generatedAt: DateTime.now(),
      usedFallback: usedFallback,
      rulesetVersion: ruleset.version,
      alternates: alternates,
    );
  }

  /// 단일 카테고리 점수 계산.
  ///
  /// base 40 / 상황 0..20 / 관계 0..15 / 예산 0..15 / 취향 0..10 /
  /// 위험 패널티 0..-50, 회피 태그 충돌은 제외.
  CategoryScore evaluate(GiftIntent intent, GiftCategory category) {
    final List<RiskRule> matched = ruleset.rules
        .where((RiskRule rule) => rule.matches(intent, category))
        .toList(growable: false);
    final RiskLevel riskLevel = _riskLevel(matched);

    if (category.tags.any(intent.avoidTags.contains)) {
      return CategoryScore(
        category: category,
        score: 0,
        riskLevel: riskLevel,
        cautions: const <String>[],
        excluded: true,
      );
    }

    var score = 40;
    score += category.situations.contains(intent.situation) ? 20 : 0;
    score += category.relationships.contains(intent.relationship) ? 15 : 0;
    score += budgetFit(intent, category);
    score += (10 * (1 - (intent.preference - category.preference).abs()))
        .round();
    score -= riskPenalty(matched);

    return CategoryScore(
      category: category,
      score: score.clamp(0, 100),
      riskLevel: riskLevel,
      cautions: matched
          .map((RiskRule rule) => rule.message)
          .where((String message) => message.isNotEmpty)
          .toList(growable: false),
      excluded: false,
    );
  }

  /// 예산 적합도 0..15.
  int budgetFit(GiftIntent intent, GiftCategory category) {
    final BudgetRange range = intent.budgetRange;
    if (category.priceMedian >= range.min &&
        category.priceMedian <= range.max) {
      return 15;
    }

    final int overlapLow = math.max(range.min, category.priceMin);
    final int overlapHigh = math.min(range.max, category.priceMax);
    if (overlapLow <= overlapHigh) {
      final int span = math.max(1, range.max - range.min);
      final double ratio = (overlapHigh - overlapLow) / span;
      return (9 * ratio).round().clamp(4, 9);
    }

    final int distance = category.priceMin > range.max
        ? category.priceMin - range.max
        : range.min - category.priceMax;
    final int tolerance = math.max(1, (range.max * 0.3).round());
    return distance <= tolerance ? 2 : 0;
  }

  /// 위험 규칙 패널티 0..50.
  int riskPenalty(List<RiskRule> matched) {
    final int total = matched.fold<int>(
      0,
      (int sum, RiskRule rule) => sum + rule.penalty,
    );
    return total.clamp(0, 50);
  }

  /// 회피 태그와 위험 규칙을 제외하고 남는 카테고리가 있는지 확인한다.
  bool hasCandidates(GiftIntent intent) =>
      ruleset.categories.any((GiftCategory c) {
        final CategoryScore s = evaluate(intent, c);
        return !s.excluded && s.riskLevel != RiskLevel.avoid;
      });

  RiskLevel _riskLevel(List<RiskRule> matched) {
    if (matched.any((RiskRule r) => r.level == RiskLevel.avoid)) {
      return RiskLevel.avoid;
    }
    if (matched.any((RiskRule r) => r.level == RiskLevel.caution)) {
      return RiskLevel.caution;
    }
    return RiskLevel.safe;
  }

  static int _byScoreThenId(CategoryScore a, CategoryScore b) {
    final int byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    return a.category.id.compareTo(b.category.id);
  }

  GiftRecommendation _toRecommendation(GiftIntent intent, CategoryScore s) {
    final GiftCategory category = s.category;
    final String caution = <String>[
      if (category.caution.isNotEmpty) category.caution,
      ...s.cautions,
    ].join(' ');

    return GiftRecommendation(
      categoryId: category.id,
      title: category.title,
      emoji: category.emoji,
      fitScore: s.score,
      riskLevel: s.riskLevel,
      reason: category.reason,
      caution: caution,
      searchQueries: buildSearchQueries(intent, category),
      highlights: category.highlights,
      priceAvailable: category.priceAvailable,
      marketLow: category.priceAvailable ? category.priceMin : null,
      marketMedian: category.priceAvailable ? category.priceMedian : null,
      marketHigh: category.priceAvailable ? category.priceMax : null,
      marketEvidence: const <MarketEvidence>[],
      affiliateUrl: Uri.https(mockAffiliateHost, '/go', <String, String>{
        'category': category.id,
      }),
    );
  }

  /// 판매처 이름을 포함하지 않는 검색어 2~3개를 만든다.
  List<String> buildSearchQueries(GiftIntent intent, GiftCategory category) {
    final List<String> queries = <String>[...category.searchQueries];
    for (final String template in ruleset.queryTemplates) {
      queries.add(
        template
            .replaceAll('{relationship}', intent.relationship.label)
            .replaceAll('{situation}', intent.situation.label)
            .replaceAll('{category}', category.title)
            .replaceAll('{budget}', intent.budgetLabel)
            .replaceAll('{preference}', intent.preferenceLabel),
      );
    }
    return queries
        .map((String q) => q.trim())
        .where((String q) => q.isNotEmpty)
        .toSet()
        .take(3)
        .toList(growable: false);
  }
}
