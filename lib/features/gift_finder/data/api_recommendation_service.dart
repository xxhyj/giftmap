import 'package:flutter/foundation.dart';

import '../../../core/config/api_config.dart';
import '../../../core/net/json_http_client.dart';
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
/// 서버가 `fallback: true` 를 주거나 호출이 실패하면 null 을 돌려주고,
/// 부르는 쪽이 기존 추천 엔진으로 계속한다. 화면이 비지 않는다.
final class ApiRecommendationService implements AiRecommendationService {
  const ApiRecommendationService(this._config, this._client);

  final ApiConfig _config;
  final JsonHttpClient _client;

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

        // 서버가 없는 상품을 말하면 버린다. 앱은 카탈로그만 믿는다.
        final Product? product = catalog.byId(id);
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
