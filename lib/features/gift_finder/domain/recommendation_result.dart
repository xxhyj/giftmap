import 'gift_intent.dart';

/// 가격 근거. 근거가 없으면 가격을 표시하지 않는다.
class MarketEvidence {
  const MarketEvidence({
    required this.sourceTitle,
    required this.sourceUrl,
    this.observedPrice,
    this.observedAt,
    this.note,
  });

  final String sourceTitle;
  final Uri sourceUrl;
  final int? observedPrice;
  final DateTime? observedAt;
  final String? note;
}

/// 결과 화면에 노출되는 추천 카테고리 1건.
class GiftRecommendation {
  const GiftRecommendation({
    required this.categoryId,
    required this.title,
    required this.fitScore,
    required this.riskLevel,
    required this.reason,
    required this.caution,
    required this.searchQueries,
    required this.highlights,
    this.emoji = '🎁',
    this.marketLow,
    this.marketMedian,
    this.marketHigh,
    this.priceAvailable = false,
    this.marketEvidence = const <MarketEvidence>[],
    this.affiliateUrl,
  });

  final String categoryId;
  final String title;

  /// 0..100.
  final int fitScore;
  final RiskLevel riskLevel;
  final String reason;
  final String caution;
  final List<String> searchQueries;
  final List<String> highlights;
  final String emoji;
  final bool priceAvailable;
  final int? marketLow;
  final int? marketMedian;
  final int? marketHigh;
  final List<MarketEvidence> marketEvidence;

  /// MVP에서는 mock URL이며 실제 제휴 연결이 아니다.
  final Uri? affiliateUrl;

  /// 0..4 사이의 적합도 등급. 색상 외 보조 표기에 사용한다.
  int get fitLevel => (fitScore / 20).floor().clamp(0, 5);
}

class RecommendationResult {
  const RecommendationResult({
    required this.apiVersion,
    required this.intent,
    required this.items,
    required this.generatedAt,
    required this.usedFallback,
    this.rulesetVersion = 'local',
    this.alternates = const <GiftRecommendation>[],
  });

  final String apiVersion;
  final GiftIntent intent;
  final List<GiftRecommendation> items;
  final DateTime generatedAt;

  /// 원격 실패로 로컬 결과를 사용했는지 여부.
  final bool usedFallback;
  final String rulesetVersion;

  /// `다른 후보` 교체에 사용할 예비 후보.
  final List<GiftRecommendation> alternates;

  RecommendationResult copyWith({
    List<GiftRecommendation>? items,
    List<GiftRecommendation>? alternates,
    bool? usedFallback,
  }) {
    return RecommendationResult(
      apiVersion: apiVersion,
      intent: intent,
      items: items ?? this.items,
      generatedAt: generatedAt,
      usedFallback: usedFallback ?? this.usedFallback,
      rulesetVersion: rulesetVersion,
      alternates: alternates ?? this.alternates,
    );
  }
}
