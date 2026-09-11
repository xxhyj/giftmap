import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../app/app_scope.dart';
import '../../../app/app_shell.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/responsive_body.dart';
import '../../../core/widgets/rounded_surface.dart';
import '../../gift_finder/domain/gift_intent.dart';
import '../../products/domain/product.dart';
import '../../products/presentation/product_detail_screen.dart';
import '../../products/presentation/widgets/product_collections.dart';
import '../../search/presentation/search_screen.dart';
import '../widgets/home_hero.dart';
import '../widgets/occasion_quick_row.dart';

/// 홈. 선물을 발견하는 공간이다.
///
/// 최근 본 상품은 홈이 아니라 기록 탭에서만 보여준다.
/// 모든 섹션은 카탈로그가 돌려준 목록 길이에 따라 자동으로 나타나고 사라진다.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openSearch(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const SearchScreen(),
      ),
    );
  }

  void _openProduct(BuildContext context, Product product) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            ProductDetailScreen(product: product),
      ),
    );
  }

  void _startFinder(
    BuildContext context, {
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

    void open(Product product) => _openProduct(context, product);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ResponsiveBody(
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.bottomAction),
            children: <Widget>[
              _HomeHeader(
                onLibrary: () =>
                    deps.shellTab.goTo(ShellTabController.favoritesTab),
                onSettings: () =>
                    Navigator.of(context).push(AppRouter.settings()),
              ),
              HomeSearchEntry(onTap: () => _openSearch(context)),
              GiftFinderHeroBanner(onStart: () => _startFinder(context)),
              const SizedBox(height: AppSpacing.lg),
              OccasionQuickRow(
                onSituation: (GiftSituation s) =>
                    _startFinder(context, situation: s),
                onRelationship: (RelationshipType r) =>
                    _startFinder(context, relationship: r),
              ),
              ProductCarouselSection(
                title: '요즘 눈여겨볼 선물',
                subtitle: '지금 할인 중인 데모 상품',
                products: deps.catalog.discounted,
                onOpen: open,
              ),
              ProductCarouselSection(
                title: 'Giftmap 추천 상품',
                subtitle: '상황을 가리지 않고 무난한 선택',
                products: deps.catalog.popular,
                onOpen: open,
              ),
              ProductCarouselSection(
                title: '인기 상품',
                subtitle: '데모 데이터 기준으로 고른 대표 상품',
                products: deps.catalog.byPriceUnder(50000, limit: 12),
                onOpen: open,
              ),
              ProductCarouselSection(
                title: '친구에게 주기 좋은 선물',
                subtitle: '취향 부담이 적은 구성 위주',
                products: deps.catalog.byRecipient(RelationshipType.friend),
                onOpen: open,
              ),
              ProductCarouselSection(
                title: '집들이에 센스 있는 선물',
                subtitle: '공간에 두고 오래 쓰는 것들',
                products: deps.catalog.byOccasion(GiftSituation.housewarming),
                onOpen: open,
              ),
              ProductCarouselSection(
                title: '부담 없이 마음을 전하기 좋은 선물',
                subtitle: '가볍게 건네기 좋은 가격대',
                products: deps.catalog.byPriceUnder(30000, limit: 12),
                onOpen: open,
              ),
              const SizedBox(height: AppSpacing.lg),
              _BrowseAllCard(
                onTap: () => deps.shellTab.goTo(ShellTabController.categoryTab),
              ),
              const SizedBox(height: AppSpacing.md),
              _AnniversaryCard(
                onTap: () =>
                    Navigator.of(context).push(AppRouter.anniversary()),
              ),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screen,
                ),
                child: Text(
                  deps.productDisclaimer,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.onLibrary, required this.onSettings});

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
        AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              'Giftmap',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(color: AppColors.primary, letterSpacing: -0.4),
            ),
          ),
          ListenableBuilder(
            listenable: deps.favorites,
            builder: (BuildContext context, _) {
              final int count = deps.favorites.count;
              return IconButton(
                onPressed: onLibrary,
                tooltip: count == 0 ? '찜' : '찜 $count개',
                icon: Badge(
                  isLabelVisible: count > 0,
                  backgroundColor: AppColors.accent,
                  label: Text('$count'),
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

class _BrowseAllCard extends StatelessWidget {
  const _BrowseAllCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
      child: RoundedSurface(
        onTap: onTap,
        child: Row(
          children: <Widget>[
            const Icon(
              Icons.grid_view_rounded,
              color: AppColors.primary,
              size: 22,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('전체 카테고리 둘러보기', style: text.titleMedium),
                  const SizedBox(height: 2),
                  Text('종류별로 천천히 비교해 보세요', style: text.labelSmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _AnniversaryCard extends StatelessWidget {
  const _AnniversaryCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
      child: RoundedSurface(
        onTap: onTap,
        child: Row(
          children: <Widget>[
            const Icon(
              Icons.event_outlined,
              color: AppColors.textSecondary,
              size: 22,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('기념일 미리 챙기기', style: text.titleMedium),
                  const SizedBox(height: 2),
                  Text('기기에만 저장되는 간단한 목록이에요', style: text.labelSmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
