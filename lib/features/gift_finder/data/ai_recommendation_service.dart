import '../../products/domain/product_catalog.dart';
import '../domain/gift_intent.dart';
import 'product_recommendation_engine.dart';

/// 서버가 고른 실제 상품 추천.
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
