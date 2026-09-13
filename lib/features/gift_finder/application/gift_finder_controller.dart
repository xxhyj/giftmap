import 'package:flutter/foundation.dart';

import '../../../core/analytics/analytics_event.dart';
import '../../../core/errors/app_failure.dart';
import '../../products/domain/product_catalog.dart';
import '../data/ai_recommendation_service.dart';
import '../data/local_intent_parser.dart';
import '../data/local_recommendation_engine.dart';
import '../data/product_recommendation_engine.dart';
import '../domain/gift_intent.dart';
import '../domain/recommendation_repository.dart';
import '../domain/recommendation_result.dart';

enum FinderStatus { editing, analyzing, ready, failed }

/// 완료된 세션을 기록으로 넘기는 콜백. history feature가 주입한다.
typedef SessionCompleted = Future<void> Function(
  GiftIntent intent,
  RecommendationResult result,
);

/// 진행 중인 추천 세션 하나를 관리한다.
///
/// 화면은 이 controller의 상태를 읽고 이벤트만 전달하며 점수를 계산하지 않는다.
class GiftFinderController extends ChangeNotifier {
  GiftFinderController({
    required RecommendationRepository repository,
    required LocalRecommendationEngine fallbackEngine,
    ProductRecommendationEngine? productEngine,
    AnalyticsRecorder? analytics,
    AiRecommendationService? aiService,
    ProductCatalog? catalog,
    this.onSessionCompleted,
    this.timeout = const Duration(milliseconds: 2500),
  }) : // 이름 있는 매개변수는 private 이름을 쓸 수 없어 초기화 목록으로 대입한다.
       // ignore_for_file: prefer_initializing_formals
       _repository = repository,
       _fallbackEngine = fallbackEngine,
       _productEngine = productEngine,
       _analytics = analytics,
       _aiService = aiService,
       _catalog = catalog;

  final RecommendationRepository _repository;
  final LocalRecommendationEngine _fallbackEngine;
  final ProductRecommendationEngine? _productEngine;
  final AnalyticsRecorder? _analytics;

  /// 서버가 실제 상품 중에서 골라 주는 추천. 없거나 실패하면 쓰지 않는다.
  final AiRecommendationService? _aiService;

  /// AI가 돌려준 상품 id를 실제 상품으로 바꿀 때 쓴다.
  final ProductCatalog? _catalog;

  final SessionCompleted? onSessionCompleted;

  /// 마지막 추천이 AI가 고른 것인지. 화면에서 표시에 쓸 수 있다.
  bool _usedAiPicks = false;
  bool get usedAiPicks => _usedAiPicks;

  /// 저장소가 응답하지 않을 때를 대비한 로컬 안전장치다.
  ///
  /// 이 단계에는 네트워크 요청이 없으므로 네트워크 타임아웃이 아니며,
  /// 저장소가 예외를 던지거나 멈추면 곧바로 로컬 엔진 결과로 완결시키는 용도다.
  /// 재시도 루프는 두지 않는다.
  final Duration timeout;

  static const int totalSteps = 5;

  bool _disposed = false;
  String _sessionId = '';
  FinderStatus _status = FinderStatus.editing;
  AppFailure? _failure;
  RecommendationResult? _result;
  List<ProductPick> _picks = const <ProductPick>[];
  ParsedIntent? _parsedIntent;
  int _step = 0;

  GiftSituation? _situation;
  RelationshipType? _relationship;
  AgeBand _ageBand = AgeBand.unspecified;
  BudgetBand? _budget;
  int? _customBudget;
  double _preference = 0.5;
  final Set<String> _avoidTags = <String>{};
  String? _rawQuery;

  FinderStatus get status => _status;
  AppFailure? get failure => _failure;
  RecommendationResult? get result => _result;

  /// 추천 결과 화면이 보여줄 상품 목록. 카테고리 방향을 반영해 정렬된다.
  List<ProductPick> get picks => _picks;
  ParsedIntent? get parsedIntent => _parsedIntent;
  String get sessionId => _sessionId;
  int get step => _step;
  GiftSituation? get situation => _situation;
  RelationshipType? get relationship => _relationship;
  AgeBand get ageBand => _ageBand;
  BudgetBand? get budget => _budget;
  int? get customBudget => _customBudget;
  double get preference => _preference;
  Set<String> get avoidTags => Set<String>.unmodifiable(_avoidTags);
  String? get rawQuery => _rawQuery;

  bool get canSubmit =>
      _situation != null &&
      _relationship != null &&
      _budget != null &&
      isBudgetValid;

  /// 직접 입력 예산이 허용 범위 안인지 여부.
  bool get isBudgetValid =>
      _budget != BudgetBand.custom ||
      (_customBudget != null &&
          _customBudget! >= BudgetBand.customMin &&
          _customBudget! <= BudgetBand.customMax);

  /// 진행률 0.0~1.0.
  double get progress => (_step + 1) / totalSteps;

  /// 새 세션을 시작한다. 진행 중 세션은 버린다.
  void startSession({String entryPoint = 'home_cta'}) {
    _sessionId = _newId();
    _status = FinderStatus.editing;
    _failure = null;
    _result = null;
    _picks = const <ProductPick>[];
    _usedAiPicks = false;
    _parsedIntent = null;
    _step = 0;
    _situation = null;
    _relationship = null;
    _ageBand = AgeBand.unspecified;
    _budget = null;
    _customBudget = null;
    _preference = 0.5;
    _avoidTags.clear();
    _rawQuery = null;
    _analytics?.record(FinderStarted(entryPoint: entryPoint));
    _notify();
  }

  /// 자연어 파싱 결과로 세션을 채운다. 신뢰도가 낮은 값도 초기값으로 넣되
  /// 화면은 `ParsedIntent.needsReview`를 보고 확인을 요청한다.
  void startFromParsed(ParsedIntent parsed) {
    startSession(entryPoint: 'home_search');
    _parsedIntent = parsed;
    _rawQuery = parsed.rawQuery;
    if (parsed.situation.isConfident) _situation = parsed.situation.value;
    if (parsed.relationship.isConfident) {
      _relationship = parsed.relationship.value;
    }
    if (parsed.ageBand.isConfident) _ageBand = parsed.ageBand.value;
    if (parsed.budget.isConfident) {
      _budget = parsed.budget.value;
      _customBudget = parsed.customBudget;
    }
    if (parsed.preference.isConfident) _preference = parsed.preference.value;
    _notify();
  }

  /// 과거 기록의 조건을 그대로 복사해 다시 계산할 준비를 한다.
  void startFromIntent(
    GiftIntent intent, {
    String entryPoint = 'history_reuse',
  }) {
    startSession(entryPoint: entryPoint);
    _situation = intent.situation;
    _relationship = intent.relationship;
    _ageBand = intent.ageBand;
    _budget = intent.budget;
    _customBudget = intent.customBudget;
    _preference = intent.preference;
    _avoidTags
      ..clear()
      ..addAll(intent.avoidTags);
    _step = totalSteps - 1;
    _notify();
  }

  void goToStep(int step) {
    _step = step.clamp(0, totalSteps - 1);
    _notify();
  }

  void selectSituation(GiftSituation value) {
    _situation = value;
    _notify();
  }

  void selectRelationship(RelationshipType value) {
    _relationship = value;
    _notify();
  }

  void selectAgeBand(AgeBand value) {
    _ageBand = _ageBand == value ? AgeBand.unspecified : value;
    _notify();
  }

  void selectBudget(BudgetBand value) {
    _budget = value;
    if (value != BudgetBand.custom) _customBudget = null;
    _notify();
  }

  /// 직접 입력 예산. 범위를 벗어나면 `ValidationFailure` 메시지를 돌려준다.
  String? setCustomBudget(int? value) {
    _budget = BudgetBand.custom;
    _customBudget = value;
    _notify();
    if (value == null) return '금액을 입력해 주세요.';
    if (value < BudgetBand.customMin || value > BudgetBand.customMax) {
      return '1,000원 이상 10,000,000원 이하로 입력해 주세요.';
    }
    return null;
  }

  void setPreference(double value) {
    _preference = value.clamp(0, 1);
    _notify();
  }

  void toggleAvoidTag(String tag) {
    if (!_avoidTags.remove(tag)) _avoidTags.add(tag);
    _notify();
  }

  /// 현재까지 선택된 값으로 만든 확정 의도. 미완성이면 null이다.
  GiftIntent? buildIntent() {
    if (!canSubmit) return null;
    return GiftIntent(
      situation: _situation!,
      relationship: _relationship!,
      ageBand: _ageBand,
      budget: _budget!,
      preference: _preference,
      customBudget: _customBudget,
      avoidTags: _avoidTags.toList(growable: false)..sort(),
      rawQuery: _rawQuery,
    );
  }

  /// 추천을 실행한다. 이미 분석 중이면 중복 실행을 막는다.
  Future<void> submit() async {
    if (_status == FinderStatus.analyzing) return;
    final GiftIntent? intent = buildIntent();
    if (intent == null) {
      _failure = const ValidationFailure('조건을 모두 선택해 주세요.');
      _status = FinderStatus.failed;
      _notify();
      return;
    }

    _status = FinderStatus.analyzing;
    _failure = null;
    _notify();

    final Stopwatch stopwatch = Stopwatch()..start();
    RecommendationResult result;
    try {
      result = await _repository.recommend(intent).timeout(timeout);
    } on Object {
      // 원격/저장소 실패와 timeout 모두 로컬 결과로 완결한다.
      result = _fallbackEngine.recommend(intent, usedFallback: true);
    }
    stopwatch.stop();

    if (_disposed) return;

    if (result.items.isEmpty) {
      _failure = const RecommendationFailure();
      _status = FinderStatus.failed;
      _notify();
      return;
    }

    _result = result;
    // 서버(OpenAI)가 실제 상품 중에서 고르게 하고, 못 고르면 로컬 엔진을 쓴다.
    final List<ProductPick>? aiPicks = await _aiPicks(intent);
    if (_disposed) return;
    _usedAiPicks = aiPicks != null;
    _picks =
        aiPicks ??
        _productEngine?.recommend(intent, directions: result.items) ??
        const <ProductPick>[];
    _status = FinderStatus.ready;
    _analytics?.record(
      RecommendationViewed(
        sessionId: _sessionId,
        usedFallback: result.usedFallback,
        durationMs: stopwatch.elapsedMilliseconds,
      ),
    );
    _notify();

    await onSessionCompleted?.call(intent, result);
  }

  /// 서버 추천을 시도한다. 준비가 안 됐거나 실패하면 null이다.
  Future<List<ProductPick>?> _aiPicks(GiftIntent intent) async {
    final AiRecommendationService? service = _aiService;
    final ProductCatalog? catalog = _catalog;
    if (service == null || catalog == null) return null;
    try {
      return await service.recommend(intent, catalog: catalog);
    } on Object {
      // 서버 추천은 없어도 되는 기능이다. 실패해도 흐름을 막지 않는다.
      return null;
    }
  }

  /// 결과 한 슬롯만 예비 후보로 교체한다. 나머지 슬롯은 유지한다.
  void replaceSlot(int index) {
    final RecommendationResult? current = _result;
    if (current == null) return;
    if (index < 0 || index >= current.items.length) return;
    if (current.alternates.isEmpty) return;

    final GiftRecommendation incoming = current.alternates.first;
    final List<GiftRecommendation> items = List<GiftRecommendation>.of(
      current.items,
    );
    final GiftRecommendation outgoing = items[index];
    items[index] = incoming;

    final List<GiftRecommendation> alternates =
        List<GiftRecommendation>.of(current.alternates)
          ..removeAt(0)
          ..add(outgoing);

    _result = current.copyWith(items: items, alternates: alternates);
    _notify();
  }

  bool get canReplaceSlot => (_result?.alternates.isNotEmpty ?? false);

  void recordDetailOpened(String categoryId) =>
      _analytics?.record(DetailOpened(categoryId: categoryId));

  void recordQueryCopied(String categoryId) =>
      _analytics?.record(QueryCopied(categoryId: categoryId));

  /// 고지가 표시된 경우에만 클릭을 기록한다.
  void recordCommerceClicked({
    required String categoryId,
    required String destinationHost,
    required bool disclosureShown,
  }) {
    if (!disclosureShown) return;
    _analytics?.record(
      CommerceClicked(
        categoryId: categoryId,
        destinationHost: destinationHost,
        disclosureShown: disclosureShown,
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  static String _newId() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(36);
}
