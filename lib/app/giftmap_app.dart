import 'package:flutter/material.dart';

import '../core/analytics/analytics_event.dart';
import '../core/theme/app_theme.dart';
import '../features/anniversary/application/anniversary_store.dart';
import '../features/anniversary/data/in_memory_anniversary_repository.dart';
import '../features/gift_finder/application/gift_finder_controller.dart';
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
import '../features/products/domain/product_catalog.dart';
import '../features/splash/presentation/splash_screen.dart';
import 'app_scope.dart';
import 'app_shell.dart';

class GiftmapApp extends StatefulWidget {
  const GiftmapApp({
    this.dataSource,
    this.productDataSource,
    this.storage,
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

  @override
  State<GiftmapApp> createState() => _GiftmapAppState();
}

class _GiftmapAppState extends State<GiftmapApp> {
  AppDependencies? _dependencies;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  /// 번들 JSON을 읽고 의존성을 조립한다. 인위적 지연은 두지 않는다.
  Future<void> _bootstrap() async {
    final CategoryDataSource source =
        widget.dataSource ?? const BundledCategoryDataSource();
    final GiftRuleset ruleset = await source.load();
    final ProductCatalog catalog =
        await (widget.productDataSource ?? const BundledProductDataSource())
            .load();
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
        ProductRecommendationEngine(catalog: catalog, ruleset: ruleset);

    final AppDependencies dependencies = AppDependencies(
      ruleset: ruleset,
      engine: engine,
      finderController: GiftFinderController(
        repository: MockRecommendationRepository(engine),
        fallbackEngine: engine,
        productEngine: productEngine,
        analytics: analytics,
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
      catalog: catalog,
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppDependencies? dependencies = _dependencies;
    if (dependencies == null) {
      return MaterialApp(
        title: 'Giftmap',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const SplashScreen(),
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
        home: const AppShell(),
      ),
    );
  }
}
