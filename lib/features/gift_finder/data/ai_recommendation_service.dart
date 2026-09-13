import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../products/domain/product.dart';
import '../../products/domain/product_catalog.dart';
import '../domain/gift_intent.dart';
import 'product_recommendation_engine.dart';

/// 서버(Supabase Edge Function)가 고른 실제 상품 추천.
///
/// OpenAI 호출은 전부 서버에서 일어나며 앱에는 API 키가 없다.
/// 서버는 **DB에 있는 상품 id만** 돌려주기로 되어 있고, 앱은 그 약속을
/// 한 번 더 확인한다. 카탈로그에 없는 id는 버린다.
///
/// 서버가 `fallback: true`를 주거나 호출이 실패하면 null을 돌려주고,
/// 호출한 쪽이 기존 추천 엔진(실제 상품 대상)으로 계속한다.
abstract interface class AiRecommendationService {
  Future<List<ProductPick>?> recommend(
    GiftIntent intent, {
    required ProductCatalog catalog,
  });
}

/// Supabase Functions 로 추천을 요청하는 구현체.
final class SupabaseAiRecommendationService implements AiRecommendationService {
  const SupabaseAiRecommendationService(
    this._client, {
    this.functionName = 'recommend',
    this.timeout = const Duration(seconds: 20),
  });

  final SupabaseClient _client;
  final String functionName;
  final Duration timeout;

  @override
  Future<List<ProductPick>?> recommend(
    GiftIntent intent, {
    required ProductCatalog catalog,
  }) async {
    try {
      final FunctionResponse response = await _client.functions
          .invoke(functionName, body: _toRequest(intent))
          .timeout(timeout);

      final Object? data = response.data;
      if (data is! Map) return null;
      if (data['fallback'] == true) {
        debugPrint('[Giftmap] AI 추천 fallback: ${data['reason']}');
        return null;
      }

      final Object? rawPicks = data['picks'];
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
