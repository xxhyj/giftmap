import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/gift_category.dart';
import '../domain/gift_intent.dart';
import '../domain/gift_ruleset.dart';
import '../domain/risk_rule.dart';

abstract interface class CategoryDataSource {
  Future<GiftRuleset> load();
}

/// 앱 번들의 JSON을 읽어 ruleset을 만든다.
///
/// 데이터가 손상되면 예외를 던지지 않고 안전한 기본 카테고리 세트로 진입한다.
final class BundledCategoryDataSource implements CategoryDataSource {
  // 이름 있는 매개변수는 private 이름을 쓸 수 없어 초기화 목록으로 대입한다.
  // ignore: prefer_initializing_formals
  const BundledCategoryDataSource({AssetBundle? bundle}) : _bundle = bundle;

  static const String categoriesAsset = 'lib/data/gift_categories.json';
  static const String rulesAsset = 'lib/data/risk_rules.json';
  static const String queriesAsset = 'lib/data/search_queries.json';

  final AssetBundle? _bundle;

  AssetBundle get _assets => _bundle ?? rootBundle;

  @override
  Future<GiftRuleset> load() async {
    try {
      final GiftRuleset ruleset = GiftRuleset.fromJson(
        categoriesJson: await _readJson(categoriesAsset),
        rulesJson: await _readJson(rulesAsset),
        queriesJson: await _readJson(queriesAsset),
      );
      return ruleset.isUsable ? ruleset : safeDefaultRuleset;
    } on Object {
      return safeDefaultRuleset;
    }
  }

  Future<Map<String, Object?>> _readJson(String assetKey) async {
    final String raw = await _assets.loadString(assetKey);
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('asset root must be a JSON object');
    }
    return decoded;
  }
}

/// 번들 데이터를 읽지 못했을 때 사용하는 최소 카테고리 세트.
final GiftRuleset safeDefaultRuleset = GiftRuleset(
  version: 'safe-default',
  priceDisclaimer: '데모 시세 범위이며 실시간 판매가가 아닙니다.',
  categories: <GiftCategory>[
    GiftCategory(
      id: 'tea_set',
      title: '티웨어·차 세트',
      group: 'food_drink',
      emoji: '🍵',
      preference: 0.55,
      priceMin: 25000,
      priceMedian: 42000,
      priceMax: 69000,
      tags: const <String>['food', 'home'],
      situations: GiftSituation.values,
      relationships: RelationshipType.values,
      safeDefault: true,
      priceAvailable: true,
      reason: '관계와 연령을 크게 가리지 않는 무난한 선택이에요.',
      caution: '알레르기나 식이 제한을 먼저 확인하세요.',
      highlights: const <String>['관계 폭이 넓음', '보관 부담 낮음'],
      searchQueries: const <String>['차 선물세트'],
    ),
    GiftCategory(
      id: 'desk_accessory',
      title: '데스크 액세서리',
      group: 'desk',
      emoji: '🗂',
      preference: 0.2,
      priceMin: 20000,
      priceMedian: 35000,
      priceMax: 60000,
      tags: const <String>['office', 'practical'],
      situations: GiftSituation.values,
      relationships: RelationshipType.values,
      safeDefault: true,
      priceAvailable: true,
      reason: '매일 쓰는 자리에 남아 실용성이 분명한 선택이에요.',
      caution: '',
      highlights: const <String>['실용성 높음', '취향 리스크 낮음'],
      searchQueries: const <String>['데스크 정리 선물'],
    ),
    GiftCategory(
      id: 'premium_towel',
      title: '프리미엄 타월 세트',
      group: 'home_living',
      emoji: '🧺',
      preference: 0.25,
      priceMin: 30000,
      priceMedian: 48000,
      priceMax: 80000,
      tags: const <String>['home', 'practical'],
      situations: GiftSituation.values,
      relationships: RelationshipType.values,
      safeDefault: true,
      priceAvailable: true,
      reason: '소비가 빠른 생활용품이라 부담 없이 받을 수 있어요.',
      caution: '',
      highlights: const <String>['실패 확률 낮음', '보관 부담 없음'],
      searchQueries: const <String>['호텔 타월 선물세트'],
    ),
  ],
  rules: const <RiskRule>[],
  queryTemplates: const <String>['{relationship} {situation} {category}'],
);
