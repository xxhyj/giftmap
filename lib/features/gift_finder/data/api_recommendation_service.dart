import 'package:flutter/foundation.dart';

import '../../../core/config/api_config.dart';
import '../../../core/net/json_http_client.dart';
import '../../products/data/api_product_data_source.dart';
import '../../products/domain/product.dart';
import '../../products/domain/product_catalog.dart';
import '../domain/gift_intent.dart';
import 'ai_recommendation_service.dart';
import 'product_recommendation_engine.dart';

/// Vercel API 로 추천을 요청하는 구현체.
///
/// OpenAI 호출은 서버 안에서만 일어나고 앱에는 키가 없다. 서버는 DB 에 있는
/// 상품 id 만 돌려주기로 되어 있고, 앱은 그 약속을 한 번 더 확인한다.
/// 카탈로그에 없는 id 는 버린다.
///
/// 서버는 DB 에 있는 상품 id 만 돌려주기로 되어 있고, 앱은 그 약속을 확인한다.
/// 카탈로그에 있으면 그대로 쓰고, 없으면 서버에 그 상품 하나를 다시 물어본다.
/// 서버가 모르는 상품이라고 하면 버린다. 모델이 지어낸 id 는 여기서 걸러진다.
///
/// 서버가 `fallback: true` 를 주거나 호출이 실패하면 null 을 돌려주고,
/// 부르는 쪽이 기존 추천 엔진으로 계속한다. 화면이 비지 않는다.
final class ApiRecommendationService implements AiRecommendationService {
  const ApiRecommendationService(this._config, this._client, {this.products});

  final ApiConfig _config;
  final JsonHttpClient _client;

  /// 카탈로그에 아직 없는 상품을 한 건씩 확인하는 곳.
  ///
  /// 앱은 첫 화면에 필요한 만큼만 들고 있는데 서버는 전체 상품에서 고른다.
  /// 그래서 고른 상품이 손에 없는 경우가 대부분이다. 이것이 없으면 추천이
  /// 매번 버려지고 로컬 엔진으로 떨어진다.
  final ApiProductDataSource? products;

  /// 어떤 클라이언트로 부르는지. 대기 시간을 확인할 때 쓴다.
  @visibleForTesting
  JsonHttpClient get client => _client;

  @override
  Future<List<ProductPick>?> recommend(
    GiftIntent intent, {
    required ProductCatalog catalog,
  }) async {
    try {
      final Object? body = await _client.postJson(
        _config.resolve('/api/recommend'),
        _toRequest(intent),
      );
      if (body is! Map) return null;
      if (body['fallback'] == true) {
        debugPrint('[Giftmap] AI 추천 fallback: ${body['reason']}');
        return null;
      }

      final Object? rawPicks = body['picks'];
      if (rawPicks is! List) return null;

      final List<ProductPick> picks = <ProductPick>[];
      final Set<String> seen = <String>{};
      for (final Object? item in rawPicks) {
        if (item is! Map) continue;
        final String? id = item['productId']?.toString();
        if (id == null || !seen.add(id)) continue;

        // 손에 있으면 그대로 쓰고, 없으면 서버에 그 상품만 다시 물어본다.
        // 서버도 모르는 상품이면 버린다(모델이 지어낸 id 가 여기서 걸러진다).
        final Product? product = catalog.byId(id) ?? await _fetch(id);
        if (product == null) continue;

        picks.add(
          ProductPick(
            product: product,
            // AI 추천에는 점수 개념이 없다. 순서가 곧 추천 순위다.
            score: 0,
            riskLevel: RiskLevel.safe,
            badge: 'AI 추천',
            reason: item['reason']?.toString() ?? '',
          ),
        );
      }

      // 3개 미만이면 신뢰하지 않고 기존 엔진에 맡긴다.
      return picks.length >= 3 ? picks : null;
    } on Object catch (error) {
      debugPrint('[Giftmap] AI 추천 호출 실패: $error');
      return null;
    }
  }

  /// 카탈로그에 없는 상품 한 건을 서버에서 확인한다. 실패하면 null 이다.
  Future<Product?> _fetch(String id) async {
    final ApiProductDataSource? source = products;
    if (source == null) return null;
    try {
      return await source.fetchProduct(id);
    } on Object catch (error) {
      debugPrint('[Giftmap] 추천 상품을 확인하지 못했습니다($id): $error');
      return null;
    }
  }

  /// 서버가 읽는 조건. 사용자가 고른 값만 담는다.
  Map<String, Object?> _toRequest(GiftIntent intent) => <String, Object?>{
    'relationship': intent.relationship.wireName,
    'situation': intent.situation.wireName,
    'budgetMin': intent.budgetRange.min,
    'budgetMax': intent.budgetRange.max,
    'ageBand': intent.ageBand.wireName,
    'avoidTags': intent.avoidTags.toList(growable: false),
    'preference': intent.preference,
  };
}
