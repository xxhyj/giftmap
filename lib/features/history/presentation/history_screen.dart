import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../app/app_scope.dart';
import '../../../app/app_shell.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/responsive_body.dart';
import '../../../core/widgets/rounded_surface.dart';
import '../../gift_finder/domain/gift_intent.dart';
import '../../products/domain/product.dart';
import '../../products/presentation/product_detail_screen.dart';
import '../../products/presentation/widgets/product_card.dart';
import '../application/history_store.dart';
import '../domain/history_entry.dart';

/// 기록 탭. 최근 본 상품과 추천 기록을 보여준다.
///
/// 검색 키워드 기록(Search History)은 저장하지 않는다. 여기서 다루는 것은
/// 5단계 추천 세션 기록(Recommendation History)뿐이다.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _segment = 0;
  bool _refreshed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_refreshed) return;
    _refreshed = true;
    AppScope.of(context).historyStore.refresh();
  }

  void _openProduct(Product product) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            ProductDetailScreen(product: product),
      ),
    );
  }

  void _startFinder() =>
      AppScope.of(context).shellTab.goTo(ShellTabController.finderTab);

  @override
  Widget build(BuildContext context) {
    final AppDependencies deps = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('기록')),
      body: SafeArea(
        child: ResponsiveBody(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  AppSpacing.sm,
                  AppSpacing.screen,
                  AppSpacing.md,
                ),
                child: SegmentedButton<int>(
                  segments: const <ButtonSegment<int>>[
                    ButtonSegment<int>(
                      value: 0,
                      label: Text('최근 본 상품'),
                      icon: Icon(Icons.visibility_outlined, size: 18),
                    ),
                    ButtonSegment<int>(
                      value: 1,
                      label: Text('추천 기록'),
                      icon: Icon(Icons.redeem_outlined, size: 18),
                    ),
                  ],
                  selected: <int>{_segment},
                  showSelectedIcon: false,
                  onSelectionChanged: (Set<int> value) =>
                      setState(() => _segment = value.first),
                ),
              ),
              Expanded(
                child: _segment == 0
                    ? _RecentlyViewedTab(
                        onOpen: _openProduct,
                        onFind: _startFinder,
                      )
                    : _RecommendationHistoryTab(
                        store: deps.historyStore,
                        onFind: _startFinder,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentlyViewedTab extends StatelessWidget {
  const _RecentlyViewedTab({required this.onOpen, required this.onFind});

  final void Function(Product product) onOpen;
  final VoidCallback onFind;

  @override
  Widget build(BuildContext context) {
    final AppDependencies deps = AppScope.of(context);

    return ListenableBuilder(
      listenable: deps.recentlyViewed,
      builder: (BuildContext context, _) {
        final List<Product> products = deps.catalog.byIds(
          deps.recentlyViewed.ids,
        );

        if (products.isEmpty) {
          return EmptyStateView(
            icon: Icons.visibility_outlined,
            title: '최근 본 상품이 없어요',
            message: '상품을 열어보면 여기에서 다시 찾을 수 있어요.',
            actionLabel: '카테고리 둘러보기',
            onAction: () => deps.shellTab.goTo(ShellTabController.categoryTab),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            0,
            AppSpacing.screen,
            AppSpacing.bottomAction,
          ),
          itemCount: products.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (BuildContext context, int index) {
            final Product product = products[index];
            return ProductRowCard(
              product: product,
              onTap: () => onOpen(product),
            );
          },
        );
      },
    );
  }
}

class _RecommendationHistoryTab extends StatelessWidget {
  const _RecommendationHistoryTab({required this.store, required this.onFind});

  final HistoryStore store;
  final VoidCallback onFind;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: store,
      builder: (BuildContext context, _) {
        if (store.isLoading) {
          return Center(
            child: Semantics(
              label: '추천 기록을 불러오는 중',
              child: const CircularProgressIndicator(),
            ),
          );
        }
        if (store.entries.isEmpty) {
          return EmptyStateView(
            icon: Icons.redeem_outlined,
            title: '아직 추천 기록이 없어요',
            message: '선물추천을 한 번 마치면 조건과 결과가 여기에 남아요.',
            actionLabel: '선물추천 시작하기',
            onAction: onFind,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            0,
            AppSpacing.screen,
            AppSpacing.bottomAction,
          ),
          itemCount: store.entries.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (BuildContext context, int index) {
            final HistoryEntry entry = store.entries[index];
            return RoundedSurface(
              onTap: () =>
                  Navigator.of(context).push(AppRouter.historyDetail(entry)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Text(entry.title, style: text.titleMedium),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        DateFormatKo.relativeDay(entry.createdAt),
                        style: text.labelSmall,
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: AppColors.textTertiary,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // 당시 5단계 입력 조건 요약
                  _ConditionSummary(entry: entry),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '추천 방향 · ${entry.summary}',
                    style: text.labelSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ConditionSummary extends StatelessWidget {
  const _ConditionSummary({required this.entry});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final GiftIntent intent = entry.intent;
    final List<String> conditions = <String>[
      intent.situation.label,
      intent.relationship.label,
      if (intent.ageBand != AgeBand.unspecified) intent.ageBand.label,
      intent.budgetLabel,
      intent.preferenceLabel,
      for (final String tag in intent.avoidTags)
        '${AvoidTags.labels[tag] ?? tag} 제외',
    ];

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: conditions
          .map(
            (String label) => Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: Text(label, style: Theme.of(context).textTheme.labelSmall),
            ),
          )
          .toList(growable: false),
    );
  }
}
