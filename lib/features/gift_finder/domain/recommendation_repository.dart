import 'gift_intent.dart';
import 'recommendation_result.dart';

/// 추천 제공자 계약. Phase 2의 `RealRecommendationRepository`도 동일 계약을
/// 구현하며, 화면과 controller는 구현체를 알지 못한다.
abstract interface class RecommendationRepository {
  Future<RecommendationResult> recommend(GiftIntent intent);
}

/// Phase 2에서 서버 추천을 붙일 자리. MVP에서는 구현·연결하지 않는다.
abstract interface class RemoteRecommendationDataSource {
  Future<RecommendationResult> recommend(GiftIntent intent);
}
