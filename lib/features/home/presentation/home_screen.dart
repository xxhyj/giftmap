import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../app/app_scope.dart';
import '../../../app/app_shell.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/rounded_surface.dart';
import '../../gift_finder/domain/gift_intent.dart';
import '../../products/domain/product.dart';
import '../../products/presentation/product_detail_screen.dart';
import '../../products/presentation/widgets/product_collections.dart';
import '../../search/presentation/search_screen.dart';
import '../widgets/home_hero.dart';
import '../widgets/occasion_quick_row.dart';

/// S1. 홈. 선물을 "발견하는" 공간이다.
///
/// 상품 이미지 중심의 큐레이션 섹션과 선물 찾기 진입점을 함께 보여준다.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _refreshed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_refreshed) return;
    _refreshed = true;
    AppScope.of(context).historyStore.refresh();
  }

  void _openSearch({String? query}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => SearchScreen(initialQuery: query),
      ),
    );
  }

  void _openProduct(Product product) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            ProductDetailScreen(product: product),
      ),
    );
  }

  void _startFinder({
    GiftSituation? situation,
    RelationshipType? relationship,
  }) {
    final AppDependencies deps = AppScope.of(context);
    deps.finderController.startSession(
      entryPoint: situation == null && relationship == null
          ? 'home_cta'
          : 'home_quick',
    );
    if (situation != null) deps.finderController.selectSituation(situation);
    if (relationship != null) {
      deps.finderController.selectRelationship(relationship);
    }
    deps.shellTab.goTo(ShellTabController.finderTab);
  }

  @override
  Widget build(BuildContext context) {
    final AppDependencies deps = AppScope.of(context);
    final TextTheme text = Theme.of(context).textTheme;

    final List<Product> popular = deps.catalog.popular;
    final List<Product> under30k = deps.catalog.byPriceUnder(30000);
    final List<Product> forFriend = deps.catalog.byRecipient(
      RelationshipType.friend,
    );
    final List<Product> housewarming = deps.catalog.byOccasion(
      GiftSituation.housewarming,
    );
    final List<Product> curated = deps.catalog.discounted
        .take(6)
        .toList(growable: false);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.bottomAction),
          children: <Widget>[
            _TopBar(
              onSearch: _openSearch,
              onLibrary: () =>
                  deps.shellTab.goTo(ShellTabController.libraryTab),
              onSettings: () =>
                  Navigator.of(context).push(AppRouter.settings()),
            ),
            HomeHero(
              onSearchTap: _openSearch,
              onStartTap: () => _startFinder(),
            ),
            const SizedBox(height: AppSpacing.lg),
            OccasionQuickRow(
              onSituation: (GiftSituation s) => _startFinder(situation: s),
              onRelationship: (RelationshipType r) =>
                  _startFinder(relationship: r),
            ),
            if (popular.isNotEmpty) ...<Widget>[
              SectionTitleRow(
                title: '지금 많이 찾는 선물',
                subtitle: '상황을 가리지 않고 무난한 선택',
                actionLabel: '더 보기',
                onAction: _openSearch,
              ),
              ProductCarousel(products: popular, onOpen: _openProduct),
            ],
            if (under30k.isNotEmpty) ...<Widget>[
              const SectionTitleRow(
                title: '3만원 이하',
                subtitle: '부담 없이 건네기 좋은 가격대',
              ),
              ProductCarousel(products: under30k, onOpen: _openProduct),
            ],
            if (forFriend.isNotEmpty) ...<Widget>[
              const SectionTitleRow(
                title: '친구에게 주기 좋은 선물',
                subtitle: '취향 부담이 적은 구성 위주',
              ),
              ProductCarousel(products: forFriend, onOpen: _openProduct),
            ],
            if (housewarming.isNotEmpty) ...<Widget>[
              const SectionTitleRow(
                title: '센스 있는 집들이 선물',
                subtitle: '공간에 두고 오래 쓰는 것들',
              ),
              ProductCarousel(products: housewarming, onOpen: _openProduct),
            ],
            if (curated.isNotEmpty) ...<Widget>[
              const SectionTitleRow(
                title: 'GiftMap 추천 상품',
                subtitle: '지금 할인 중인 데모 상품',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screen,
                ),
                child: ProductGrid(products: curated, onOpen: _openProduct),
              ),
            ],
            _RecentlyViewedSection(onOpen: _openProduct),
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screen,
              ),
              child: RoundedSurface(
                onTap: () =>
                    Navigator.of(context).push(AppRouter.anniversary()),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.event_outlined, color: AppColors.inkMuted),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('기념일 미리 챙기기', style: text.titleMedium),
                          const SizedBox(height: AppSpacing.xs),
                          Text('기기에만 저장되는 간단한 목록이에요', style: text.labelSmall),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.inkMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screen,
              ),
              child: NoticeBlock(text: deps.productDisclaimer),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onSearch,
    required this.onLibrary,
    required this.onSettings,
  });

  final VoidCallback onSearch;
  final VoidCallback onLibrary;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final AppDependencies deps = AppScope.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.sm,
        AppSpacing.sm,
        0,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              'GiftMap',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.brandCoralDark,
                letterSpacing: -0.4,
              ),
            ),
          ),
          IconButton(
            onPressed: onSearch,
            icon: const Icon(Icons.search),
            tooltip: '상품 검색',
          ),
          ListenableBuilder(
            listenable: deps.favorites,
            builder: (BuildContext context, _) {
              return IconButton(
                onPressed: onLibrary,
                tooltip: '보관함',
                icon: Badge(
                  isLabelVisible: deps.favorites.count > 0,
                  label: Text('${deps.favorites.count}'),
                  child: const Icon(Icons.favorite_border),
                ),
              );
            },
          ),
          IconButton(
            onPressed: onSettings,
            icon: const Icon(Icons.settings_outlined),
            tooltip: '설정',
          ),
        ],
      ),
    );
  }
}

class _RecentlyViewedSection extends StatelessWidget {
  const _RecentlyViewedSection({required this.onOpen});

  final void Function(Product product) onOpen;

  @override
  Widget build(BuildContext context) {
    final AppDependencies deps = AppScope.of(context);

    return ListenableBuilder(
      listenable: deps.recentlyViewed,
      builder: (BuildContext context, _) {
        final List<Product> products = deps.catalog
            .byIds(deps.recentlyViewed.ids)
            .take(10)
            .toList(growable: false);
        if (products.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SectionTitleRow(
              title: '최근 본 상품',
              actionLabel: '전체 보기',
              onAction: () => deps.shellTab.goTo(ShellTabController.libraryTab),
            ),
            ProductCarousel(products: products, onOpen: onOpen),
          ],
        );
      },
    );
  }
}
