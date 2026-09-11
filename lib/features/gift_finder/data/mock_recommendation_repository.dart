import '../domain/gift_intent.dart';
import '../domain/recommendation_repository.dart';
import '../domain/recommendation_result.dart';
import 'local_recommendation_engine.dart';

/// MVP의 유일한 추천 제공자. 서버 없이 로컬 엔진 결과를 그대로 돌려준다.
///
/// Phase 2의 `RealRecommendationRepository`는 같은 계약을 구현하면서 실패 시
/// 이 엔진으로 폴백한다.
final class MockRecommendationRepository implements RecommendationRepository {
  const MockRecommendationRepository(this.engine, {this.latency});

  final LocalRecommendationEngine engine;

  /// 테스트에서 timeout 폴백을 검증하기 위한 인위적 지연.
  final Duration? latency;

  @override
  Future<RecommendationResult> recommend(GiftIntent intent) async {
    final Duration? delay = latency;
    if (delay != null) {
      await Future<void>.delayed(delay);
    }
    return engine.recommend(intent);
  }
}
