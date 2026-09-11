import 'gift_category.dart';
import 'risk_rule.dart';

/// 번들 JSON에서 읽어온 추천 규칙 묶음.
class GiftRuleset {
  const GiftRuleset({
    required this.version,
    required this.priceDisclaimer,
    required this.categories,
    required this.rules,
    required this.queryTemplates,
  });

  final String version;
  final String priceDisclaimer;
  final List<GiftCategory> categories;
  final List<RiskRule> rules;
  final List<String> queryTemplates;

  bool get isUsable => categories.length >= 3;

  /// 세 개의 JSON 문서를 검증하며 하나의 ruleset으로 합친다.
  ///
  /// 카테고리 하나가 손상돼도 나머지는 사용할 수 있도록 개별적으로 건너뛴다.
  factory GiftRuleset.fromJson({
    required Map<String, Object?> categoriesJson,
    required Map<String, Object?> rulesJson,
    required Map<String, Object?> queriesJson,
  }) {
    final List<GiftCategory> categories = <GiftCategory>[];
    final Object? rawCategories = categoriesJson['categories'];
    if (rawCategories is List) {
      for (final Object? entry in rawCategories) {
        if (entry is! Map<String, Object?>) continue;
        try {
          categories.add(GiftCategory.fromJson(entry));
        } on FormatException {
          continue;
        }
      }
    }

    final List<RiskRule> rules = <RiskRule>[];
    final Object? rawRules = rulesJson['rules'];
    if (rawRules is List) {
      for (final Object? entry in rawRules) {
        if (entry is! Map<String, Object?>) continue;
        try {
          rules.add(RiskRule.fromJson(entry));
        } on FormatException {
          continue;
        }
      }
    }

    final Object? rawTemplates = queriesJson['templates'];
    final List<String> templates = rawTemplates is List
        ? rawTemplates.whereType<String>().toList(growable: false)
        : const <String>[];

    return GiftRuleset(
      version: categoriesJson['rulesetVersion'] is String
          ? categoriesJson['rulesetVersion']! as String
          : 'unknown',
      priceDisclaimer: categoriesJson['priceDisclaimer'] is String
          ? categoriesJson['priceDisclaimer']! as String
          : '데모 시세 범위이며 실시간 판매가가 아닙니다.',
      categories: List<GiftCategory>.unmodifiable(categories),
      rules: List<RiskRule>.unmodifiable(rules),
      queryTemplates: List<String>.unmodifiable(templates),
    );
  }
}
