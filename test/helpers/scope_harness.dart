import 'package:flutter/material.dart';
import 'package:giftmap/app/app_scope.dart';
import 'package:giftmap/app/app_shell.dart';
import 'package:giftmap/core/analytics/analytics_event.dart';
import 'package:giftmap/core/theme/app_theme.dart';
import 'package:giftmap/features/anniversary/application/anniversary_store.dart';
import 'package:giftmap/features/anniversary/data/in_memory_anniversary_repository.dart';
import 'package:giftmap/features/gift_finder/application/gift_finder_controller.dart';
import 'package:giftmap/features/gift_finder/data/local_recommendation_engine.dart';
import 'package:giftmap/features/gift_finder/data/mock_recommendation_repository.dart';
import 'package:giftmap/features/gift_finder/data/product_recommendation_engine.dart';
import 'package:giftmap/features/gift_finder/domain/gift_ruleset.dart';
import 'package:giftmap/features/history/application/history_store.dart';
import 'package:giftmap/features/history/data/in_memory_history_repository.dart';
import 'package:giftmap/features/library/application/favorites_store.dart';
import 'package:giftmap/features/library/application/recently_viewed_store.dart';
import 'package:giftmap/features/library/data/in_memory_id_list_storage.dart';
import 'package:giftmap/features/products/domain/product.dart';
import 'package:giftmap/features/products/application/catalog_store.dart';
import 'package:giftmap/features/products/data/bundled_product_data_source.dart';
import 'package:giftmap/features/products/domain/product_catalog.dart';
import 'package:giftmap/features/search/data/search_trend_service.dart';

import '../fixtures/ruleset_fixture.dart';

/// 위젯 하나만 띄우면서 AppScope가 필요한 경우에 쓰는 최소 조립.
///
/// 앱 전체를 부팅하지 않고 컴포넌트만 검증할 때 사용한다.
Widget wrapWithScope(Widget child, {List<Product>? products}) {
  final GiftRuleset ruleset = loadBundledRuleset();
  final ProductCatalog catalog = products == null
      ? loadBundledCatalog()
      : ProductCatalog(
          products: products,
          version: 'test',
          disclaimer: '데모 상품 데이터입니다.',
        );
  final LocalRecommendationEngine engine = LocalRecommendationEngine(ruleset);
  final InMemoryIdListStorage storage = InMemoryIdListStorage();

  final AppDependencies dependencies = AppDependencies(
    ruleset: ruleset,
    engine: engine,
    finderController: GiftFinderController(
      repository: MockRecommendationRepository(engine),
      fallbackEngine: engine,
    ),
    historyStore: HistoryStore(InMemoryHistoryRepository()),
    anniversaryStore: AnniversaryStore(InMemoryAnniversaryRepository()),
    analytics: AnalyticsRecorder(),
    shellTab: ShellTabController(),
    catalogStore: CatalogStore(source: _FixedSource(catalog))..loadFirstPage(),
    searchTrends: const NoopSearchTrendService(),
    productEngine: ProductRecommendationEngine(
      catalog: () => catalog,
      ruleset: ruleset,
    ),
    favorites: FavoritesStore(storage),
    recentlyViewed: RecentlyViewedStore(storage),
  );

  return AppScope(
    dependencies: dependencies,
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

/// 테스트가 이미 만들어 둔 카탈로그를 그대로 돌려주는 소스.
final class _FixedSource implements ProductDataSource {
  const _FixedSource(this.catalog);

  final ProductCatalog catalog;

  @override
  Future<ProductCatalog> load() async => catalog;
}
