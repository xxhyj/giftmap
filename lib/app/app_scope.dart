import 'package:flutter/widgets.dart';

import '../core/affiliate/affiliate_link_policy.dart';
import '../core/analytics/analytics_event.dart';
import '../features/anniversary/application/anniversary_store.dart';
import '../features/gift_finder/application/gift_finder_controller.dart';
import '../features/gift_finder/data/local_intent_parser.dart';
import '../features/gift_finder/data/local_recommendation_engine.dart';
import '../features/gift_finder/domain/gift_ruleset.dart';
import '../features/gift_finder/data/product_recommendation_engine.dart';
import '../features/history/application/history_store.dart';
import '../features/library/application/favorites_store.dart';
import '../features/library/application/recently_viewed_store.dart';
import '../features/products/application/catalog_store.dart';
import '../features/products/domain/product_catalog.dart';
import '../features/search/data/search_trend_service.dart';
import 'app_shell.dart';

/// 앱 전역 의존성 묶음. 상태관리 패키지 없이 InheritedWidget으로만 전달한다.
class AppDependencies {
  const AppDependencies({
    required this.ruleset,
    required this.engine,
    required this.finderController,
    required this.historyStore,
    required this.anniversaryStore,
    required this.analytics,
    required this.shellTab,
    required this.catalogStore,
    required this.searchTrends,
    required this.productEngine,
    required this.favorites,
    required this.recentlyViewed,
    this.parser = const LocalIntentParser(),
    this.affiliatePolicy = const AffiliateLinkPolicy(),
  });

  final GiftRuleset ruleset;
  final LocalRecommendationEngine engine;
  final GiftFinderController finderController;
  final HistoryStore historyStore;
  final AnniversaryStore anniversaryStore;
  final AnalyticsRecorder analytics;

  /// 현재 선택된 바텀 탭. push된 화면에서도 탭 전환을 요청할 수 있게 공유한다.
  final ShellTabController shellTab;

  /// 상품 카탈로그를 나눠 받아 들고 있는 곳.
  /// 상품을 이어 받으면 스스로 알림을 보낸다.
  final CatalogStore catalogStore;

  /// 지금까지 받은 상품으로 만든 카탈로그.
  ProductCatalog get catalog => catalogStore.catalog;

  /// 검색어를 익명으로 집계하고 인기 검색어를 읽는다.
  /// 연결이 없으면 아무것도 기록하지 않는 구현이 들어온다.
  final SearchTrendService searchTrends;

  /// 조건에 맞는 상품을 점수화하는 결정론적 엔진.
  final ProductRecommendationEngine productEngine;

  /// 찜한 상품.
  final FavoritesStore favorites;

  /// 최근 본 상품.
  final RecentlyViewedStore recentlyViewed;
  final LocalIntentParser parser;
  final AffiliateLinkPolicy affiliatePolicy;

  /// 로컬 데이터가 손상돼 안전 기본값으로 진입했는지 여부.
  bool get usingSafeDefaults => ruleset.version == 'safe-default';

  String get priceDisclaimer => ruleset.priceDisclaimer;

  /// 상품 데모 데이터 고지 문구.
  String get productDisclaimer => catalog.disclaimer;

  /// 앱 데이터 전체 삭제. 설정 화면에서 사용한다.
  Future<void> clearAllLocalData() async {
    await historyStore.clear();
    await anniversaryStore.clear();
    await favorites.clear();
    await recentlyViewed.clear();
    analytics.clear();
  }
}

class AppScope extends InheritedWidget {
  const AppScope({required this.dependencies, required super.child, super.key});

  final AppDependencies dependencies;

  static AppDependencies of(BuildContext context) {
    final AppScope? scope = context
        .dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope를 찾지 못했습니다.');
    return scope!.dependencies;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      oldWidget.dependencies != dependencies;
}
