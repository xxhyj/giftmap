import 'gift_category.dart';
import 'gift_intent.dart';

/// 관계·상황·태그 조합에 따른 선물 위험 규칙.
///
/// 성별 등 민감 특성은 규칙 입력으로 사용하지 않는다.
class RiskRule {
  const RiskRule({
    required this.id,
    required this.level,
    required this.penalty,
    required this.message,
    required this.tags,
    required this.relationships,
    required this.situations,
  });

  final String id;
  final RiskLevel level;

  /// 0..50 범위의 점수 패널티.
  final int penalty;

  /// 사용자에게 보여줄 주의 문구.
  final String message;

  /// 비어 있으면 모든 값에 적용된다.
  final List<String> tags;
  final List<RelationshipType> relationships;
  final List<GiftSituation> situations;

  factory RiskRule.fromJson(Map<String, Object?> json) {
    final Object? id = json['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('risk rule requires id');
    }
    final int penalty = json['penalty'] is num
        ? (json['penalty']! as num).round()
        : 0;
    return RiskRule(
      id: id,
      level: RiskLevel.fromWire(json['level'] as String?),
      penalty: penalty.clamp(0, 50),
      message: json['message'] is String ? json['message']! as String : '',
      tags: _stringList(json['tags']),
      relationships: _stringList(json['relationships'])
          .map(RelationshipType.fromWire)
          .nonNulls
          .toList(growable: false),
      situations: _stringList(json['situations'])
          .map(GiftSituation.fromWire)
          .nonNulls
          .toList(growable: false),
    );
  }

  bool matches(GiftIntent intent, GiftCategory category) =>
      matchesTags(intent, category.tags);

  /// 카테고리와 상품이 같은 태그 어휘를 쓰므로 규칙 판정도 공유한다.
  bool matchesTags(GiftIntent intent, List<String> targetTags) {
    if (tags.isNotEmpty && !tags.any(targetTags.contains)) return false;
    if (relationships.isNotEmpty &&
        !relationships.contains(intent.relationship)) {
      return false;
    }
    if (situations.isNotEmpty && !situations.contains(intent.situation)) {
      return false;
    }
    return true;
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const <String>[];
    return value.whereType<String>().toList(growable: false);
  }
}
