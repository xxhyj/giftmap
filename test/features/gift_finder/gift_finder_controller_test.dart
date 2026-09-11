import 'package:flutter_test/flutter_test.dart';
import 'package:giftmap/features/gift_finder/application/gift_finder_controller.dart';
import 'package:giftmap/features/gift_finder/data/local_recommendation_engine.dart';
import 'package:giftmap/features/gift_finder/data/mock_recommendation_repository.dart';
import 'package:giftmap/features/gift_finder/domain/gift_intent.dart';
import 'package:giftmap/features/gift_finder/domain/recommendation_repository.dart';
import 'package:giftmap/features/gift_finder/domain/recommendation_result.dart';

import '../../fixtures/ruleset_fixture.dart';

/// 항상 실패하는 저장소. 로컬 폴백 경로를 확인한다.
final class _FailingRepository implements RecommendationRepository {
  @override
  Future<RecommendationResult> recommend(GiftIntent intent) async {
    throw StateError('network down');
  }
}

void main() {
  late LocalRecommendationEngine engine;

  setUp(() {
    engine = LocalRecommendationEngine(loadBundledRuleset());
  });

  GiftFinderController buildController({
    RecommendationRepository? repository,
    Duration timeout = const Duration(milliseconds: 2500),
  }) {
    return GiftFinderController(
      repository: repository ?? MockRecommendationRepository(engine),
      fallbackEngine: engine,
      timeout: timeout,
    );
  }

  void fillSession(GiftFinderController controller) {
    controller
      ..startSession()
      ..selectSituation(GiftSituation.birthday)
      ..selectRelationship(RelationshipType.friend)
      ..selectBudget(BudgetBand.from30kTo50k)
      ..setPreference(0.7);
  }

  test('필수 조건을 모두 고르기 전에는 제출할 수 없다', () {
    final GiftFinderController controller = buildController();
    controller.startSession();
    expect(controller.canSubmit, isFalse);
    controller.selectSituation(GiftSituation.birthday);
    expect(controller.canSubmit, isFalse);
    controller.selectRelationship(RelationshipType.friend);
    expect(controller.canSubmit, isFalse);
    controller.selectBudget(BudgetBand.from30kTo50k);
    expect(controller.canSubmit, isTrue);
    controller.dispose();
  });

  test('직접 입력 예산은 범위를 벗어나면 오류 문구를 돌려준다', () {
    final GiftFinderController controller = buildController();
    controller.startSession();
    expect(controller.setCustomBudget(500), isNotNull);
    expect(controller.isBudgetValid, isFalse);
    expect(controller.setCustomBudget(45000), isNull);
    expect(controller.isBudgetValid, isTrue);
    controller.dispose();
  });

  test('단계 이동은 0..4 범위를 벗어나지 않는다', () {
    final GiftFinderController controller = buildController();
    controller.startSession();
    controller.goToStep(-2);
    expect(controller.step, 0);
    controller.goToStep(9);
    expect(controller.step, GiftFinderController.totalSteps - 1);
    controller.dispose();
  });

  test('정상 제출은 추천 3개를 만들고 기록 콜백을 호출한다', () async {
    int completed = 0;
    final GiftFinderController controller = GiftFinderController(
      repository: MockRecommendationRepository(engine),
      fallbackEngine: engine,
      onSessionCompleted: (GiftIntent _, RecommendationResult _) async {
        completed++;
      },
    );
    fillSession(controller);
    await controller.submit();

    expect(controller.status, FinderStatus.ready);
    expect(controller.result!.items.length, 3);
    expect(controller.result!.usedFallback, isFalse);
    expect(completed, 1);
    controller.dispose();
  });

  test('저장소 실패 시 로컬 폴백으로 결과를 만든다', () async {
    final GiftFinderController controller = buildController(
      repository: _FailingRepository(),
    );
    fillSession(controller);
    await controller.submit();

    expect(controller.status, FinderStatus.ready);
    expect(controller.result!.usedFallback, isTrue);
    expect(controller.result!.items.length, 3);
    controller.dispose();
  });

  test('timeout이 지나면 로컬 결과로 완결한다', () async {
    final GiftFinderController controller = buildController(
      repository: MockRecommendationRepository(
        engine,
        latency: const Duration(seconds: 5),
      ),
      timeout: const Duration(milliseconds: 50),
    );
    fillSession(controller);
    await controller.submit();

    expect(controller.result!.usedFallback, isTrue);
    controller.dispose();
  });

  test('분석 중 중복 제출은 무시된다', () async {
    final GiftFinderController controller = buildController(
      repository: MockRecommendationRepository(
        engine,
        latency: const Duration(milliseconds: 80),
      ),
    );
    fillSession(controller);

    final Future<void> first = controller.submit();
    final Future<void> second = controller.submit();
    await Future.wait(<Future<void>>[first, second]);

    expect(controller.status, FinderStatus.ready);
    controller.dispose();
  });

  test('dispose 이후에는 notifyListeners를 호출하지 않는다', () async {
    final GiftFinderController controller = buildController(
      repository: MockRecommendationRepository(
        engine,
        latency: const Duration(milliseconds: 40),
      ),
    );
    fillSession(controller);
    final Future<void> pending = controller.submit();
    controller.dispose();
    await pending;

    expect(controller.result, isNull);
  });

  test('다른 후보는 한 슬롯만 교체하고 나머지는 유지한다', () async {
    final GiftFinderController controller = buildController();
    fillSession(controller);
    await controller.submit();

    final List<String> before = controller.result!.items
        .map((GiftRecommendation i) => i.categoryId)
        .toList();
    controller.replaceSlot(0);
    final List<String> after = controller.result!.items
        .map((GiftRecommendation i) => i.categoryId)
        .toList();

    expect(after[0], isNot(before[0]));
    expect(after.sublist(1), before.sublist(1));
    expect(after.toSet().length, 3);
    controller.dispose();
  });

  test('과거 조건 재사용은 값을 그대로 복사한다', () {
    final GiftFinderController controller = buildController();
    const GiftIntent intent = GiftIntent(
      situation: GiftSituation.housewarming,
      relationship: RelationshipType.colleague,
      ageBand: AgeBand.thirties,
      budget: BudgetBand.from50kTo100k,
      preference: 0.3,
      avoidTags: <String>['food'],
    );
    controller.startFromIntent(intent);

    expect(controller.situation, GiftSituation.housewarming);
    expect(controller.relationship, RelationshipType.colleague);
    expect(controller.ageBand, AgeBand.thirties);
    expect(controller.budget, BudgetBand.from50kTo100k);
    expect(controller.avoidTags, <String>{'food'});
    expect(controller.canSubmit, isTrue);
    controller.dispose();
  });
}
