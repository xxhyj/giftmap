import 'package:flutter/material.dart';

import '../core/analytics/analytics_event.dart';
import '../core/config/api_bootstrap.dart';
import '../core/theme/app_theme.dart';
import '../features/anniversary/application/anniversary_store.dart';
import '../features/anniversary/data/in_memory_anniversary_repository.dart';
import '../features/gift_finder/application/gift_finder_controller.dart';
import '../features/gift_finder/data/ai_recommendation_service.dart';
import '../features/gift_finder/data/bundled_category_data_source.dart';
import '../features/gift_finder/data/local_recommendation_engine.dart';
import '../features/gift_finder/data/mock_recommendation_repository.dart';
import '../features/gift_finder/data/product_recommendation_engine.dart';
import '../features/gift_finder/domain/gift_intent.dart';
import '../features/gift_finder/domain/gift_ruleset.dart';
import '../features/gift_finder/domain/recommendation_result.dart';
import '../features/history/application/history_store.dart';
import '../features/history/data/in_memory_history_repository.dart';
import '../features/history/domain/history_entry.dart';
import '../features/library/application/favorites_store.dart';
import '../features/library/application/recently_viewed_store.dart';
import '../features/library/data/prefs_id_list_storage.dart';
import '../features/library/domain/id_list_storage.dart';
import '../features/products/data/bundled_product_data_source.dart';
import '../features/products/application/catalog_store.dart';
import '../features/search/data/search_trend_service.dart';
import '../features/splash/presentation/load_failure_screen.dart';
import '../features/splash/presentation/splash_screen.dart';
import 'app_scope.dart';
import 'app_shell.dart';

class GiftmapApp extends StatefulWidget {
  const GiftmapApp({
    this.dataSource,
    this.productDataSource,
    this.storage,
    this.aiService,
    this.searchTrends,
    super.key,
  });

  /// 테스트에서 번들 대신 다른 데이터 소스를 주입할 수 있도록 열어 둔다.
  final CategoryDataSource? dataSource;

  /// 상품 카탈로그 데이터 소스.
  ///
  /// 기본값은 번들 Mock 데이터다. `main()`이 Supabase 연결에 성공하면
  /// 원격 우선 데이터 소스를 넣어 준다.
  final ProductDataSource? productDataSource;

  /// 찜·최근 본 상품 저장소.
  final IdListStorage? storage;

  /// 서버 추천 서비스. 주지 않으면 Supabase 연결 여부에 따라 정해진다.
  final AiRecommendationService? aiService;

  /// 검색어 집계 서비스. 주지 않으면 Supabase 연결 여부에 따라 정해진다.
  final SearchTrendService? searchTrends;

  @override
  State<GiftmapApp> createState() => _GiftmapAppState();
}

class _GiftmapAppState extends State<GiftmapApp> {
  AppDependencies? _dependencies;

  /// 상품을 불러오지 못한 이유. null이 아니면 재시도 화면을 보여준다.
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  /// 다시 시도. 실패 상태를 지우고 처음부터 조립한다.
  void _retry() {
    setState(() => _loadError = null);
    _bootstrap();
  }

  /// 데이터를 읽고 의존성을 조립한다. 인위적 지연은 두지 않는다.
  ///
  /// 실제 상품 모드에서는 상품을 못 읽으면 데모로 대체하지 않고 실패로 남긴다.
  Future<void> _bootstrap() async {
    try {
      await _assemble();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error.toString());
    }
  }

  Future<void> _assemble() async {
    final CategoryDataSource source =
        widget.dataSource ?? const BundledCategoryDataSource();
    final GiftRuleset ruleset = await source.load();
    // 첫 화면에 필요한 만큼만 먼저 받는다. 나머지는 목록 끝에서 이어 받는다.
    final CatalogStore catalogStore = CatalogStore(
      source: widget.productDataSource ?? const BundledProductDataSource(),
    );
    await catalogStore.loadFirstPage();
    // 실제 상품 모드에서 상품이 하나도 없으면 빈 화면을 보여주지 않고
    // 재시도 화면으로 보낸다. 데모로 채우지 않는다.
    if (catalogStore.catalog.isEmpty && ApiBootstrap.isRemoteMode) {
      throw StateError('실제 상품을 한 건도 불러오지 못했습니다.');
    }
    final LocalRecommendationEngine engine = LocalRecommendationEngine(ruleset);
    final IdListStorage storage = widget.storage ?? const PrefsIdListStorage();
    final FavoritesStore favorites = FavoritesStore(storage);
    final RecentlyViewedStore recentlyViewed = RecentlyViewedStore(storage);
    await favorites.load();
    await recentlyViewed.load();
    final HistoryStore historyStore = HistoryStore(InMemoryHistoryRepository());
    final AnniversaryStore anniversaryStore = AnniversaryStore(
      InMemoryAnniversaryRepository(),
    );
    final AnalyticsRecorder analytics = AnalyticsRecorder();

    final ProductRecommendationEngine productEngine =
        ProductRecommendationEngine(
          catalog: () => catalogStore.catalog,
          ruleset: ruleset,
        );

    final AppDependencies dependencies = AppDependencies(
      ruleset: ruleset,
      engine: engine,
      finderController: GiftFinderController(
        repository: MockRecommendationRepository(engine),
        fallbackEngine: engine,
        productEngine: productEngine,
        analytics: analytics,
        // 서버 추천이 준비되어 있으면 먼저 쓰고, 실패하면 위 엔진이 맡는다.
        aiService: widget.aiService,
        catalog: () => catalogStore.catalog,
        onSessionCompleted: (GiftIntent intent, RecommendationResult result) =>
            historyStore.add(
              HistoryEntry(
                id: result.generatedAt.microsecondsSinceEpoch.toRadixString(36),
                intent: intent,
                result: result,
                createdAt: result.generatedAt,
              ),
            ),
      ),
      historyStore: historyStore,
      anniversaryStore: anniversaryStore,
      analytics: analytics,
      shellTab: ShellTabController(),
      catalogStore: catalogStore,
      searchTrends: widget.searchTrends ?? const NoopSearchTrendService(),
      productEngine: productEngine,
      favorites: favorites,
      recentlyViewed: recentlyViewed,
    );

    if (!mounted) return;
    setState(() => _dependencies = dependencies);
  }

  @override
  void dispose() {
    _dependencies?.finderController.dispose();
    _dependencies?.historyStore.dispose();
    _dependencies?.anniversaryStore.dispose();
    _dependencies?.shellTab.dispose();
    _dependencies?.favorites.dispose();
    _dependencies?.recentlyViewed.dispose();
    _dependencies?.catalogStore.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppDependencies? dependencies = _dependencies;
    if (dependencies == null) {
      final String? error = _loadError;
      return MaterialApp(
        title: 'Giftmap',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: error == null
            ? const SplashScreen()
            : LoadFailureScreen(onRetry: _retry, detail: error),
      );
    }

    // AppScope는 MaterialApp보다 위에 둔다. push된 화면은 루트 Navigator에 올라가므로
    // AppScope가 MaterialApp 아래에 있으면 의존성을 찾지 못한다.
    return AppScope(
      dependencies: dependencies,
      child: MaterialApp(
        title: 'Giftmap',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        // 상품을 이어 받으면 화면이 새 목록을 반영하도록 듣는다.
        home: ListenableBuilder(
          listenable: dependencies.catalogStore,
          builder: (BuildContext context, Widget? child) => const AppShell(),
        ),
      ),
    );
  }
}
