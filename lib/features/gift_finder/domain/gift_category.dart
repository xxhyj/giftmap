import 'gift_intent.dart';

/// 번들 JSON으로 제공되는 추천 카테고리.
///
/// 가격은 데모 범위이며 실시간 판매가가 아니다. 출시 전에는 관측 출처와
/// 관측일을 가진 evidence로 교체해야 한다.
class GiftCategory {
  const GiftCategory({
    required this.id,
    required this.title,
    required this.group,
    required this.emoji,
    required this.preference,
    required this.priceMin,
    required this.priceMedian,
    required this.priceMax,
    required this.tags,
    required this.situations,
    required this.relationships,
    required this.safeDefault,
    required this.priceAvailable,
    required this.reason,
    required this.caution,
    required this.highlights,
    required this.searchQueries,
  });

  final String id;
  final String title;

  /// 결과 다양성 확보를 위한 상위 그룹. 그룹당 최대 1개만 추천한다.
  final String group;
  final String emoji;

  /// 0.0 실용적 ~ 1.0 감성적.
  final double preference;
  final int priceMin;
  final int priceMedian;
  final int priceMax;
  final List<String> tags;
  final List<GiftSituation> situations;
  final List<RelationshipType> relationships;
  final bool safeDefault;

  /// 시세 근거가 없으면 false이며, UI는 가격 대신 "가격 확인 필요"를 표시한다.
  /// 예산 적합도 계산에는 내부 추정 범위를 계속 사용한다.
  final bool priceAvailable;
  final String reason;
  final String caution;
  final List<String> highlights;
  final List<String> searchQueries;

  /// 스키마 검증 실패 시 `FormatException`을 던진다.
  factory GiftCategory.fromJson(Map<String, Object?> json) {
    final String? id = _asString(json['id']);
    final String? title = _asString(json['title']);
    if (id == null || title == null) {
      throw const FormatException('category requires id and title');
    }

    final int priceMin = _asInt(json['priceMin']) ?? 0;
    final int priceMedian = _asInt(json['priceMedian']) ?? priceMin;
    final int priceMax = _asInt(json['priceMax']) ?? priceMedian;
    if (priceMin <= 0 || priceMin > priceMedian || priceMedian > priceMax) {
      throw FormatException('category $id has an invalid price range');
    }

    final double preference = _asDouble(json['preference']) ?? 0.5;
    if (preference < 0 || preference > 1) {
      throw FormatException('category $id preference must be within 0..1');
    }

    return GiftCategory(
      id: id,
      title: title,
      group: _asString(json['group']) ?? id,
      emoji: _asString(json['emoji']) ?? '🎁',
      preference: preference,
      priceMin: priceMin,
      priceMedian: priceMedian,
      priceMax: priceMax,
      tags: _asStringList(json['tags']),
      situations: _asStringList(json['situations'])
          .map(GiftSituation.fromWire)
          .nonNulls
          .toList(growable: false),
      relationships: _asStringList(json['relationships'])
          .map(RelationshipType.fromWire)
          .nonNulls
          .toList(growable: false),
      safeDefault: json['safeDefault'] == true,
      priceAvailable: json['priceAvailable'] != false,
      reason: _asString(json['reason']) ?? '',
      caution: _asString(json['caution']) ?? '',
      highlights: _asStringList(json['highlights']),
      searchQueries: _asStringList(json['searchQueries']),
    );
  }

  static String? _asString(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  static int? _asInt(Object? value) => value is num ? value.round() : null;

  static double? _asDouble(Object? value) =>
      value is num ? value.toDouble() : null;

  static List<String> _asStringList(Object? value) {
    if (value is! List) return const <String>[];
    return value.map(_asString).nonNulls.toList(growable: false);
  }
}
