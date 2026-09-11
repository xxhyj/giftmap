import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../app/app_scope.dart';
import '../../../app/app_shell.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/rounded_surface.dart';
import '../../history/application/history_store.dart';
import '../../history/domain/history_entry.dart';
import '../../products/domain/product.dart';
import '../../products/presentation/product_detail_screen.dart';
import '../../products/presentation/widgets/product_card.dart';
import '../../products/presentation/widgets/product_collections.dart';

/// 보관함. 찜한 상품 · 최근 본 상품 · 추천 기록을 한 곳에서 본다.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  int _tab = 0;
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

  void _goFind() =>
      AppScope.of(context).shellTab.goTo(ShellTabController.finderTab);

  @override
  Widget build(BuildContext context) {
    final AppDependencies deps = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('보관함')),
      body: SafeArea(
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
                  ButtonSegment<int>(value: 0, label: Text('찜한 상품')),
                  ButtonSegment<int>(value: 1, label: Text('최근 본 상품')),
                  ButtonSegment<int>(value: 2, label: Text('추천 기록')),
                ],
                selected: <int>{_tab},
                showSelectedIcon: false,
                onSelectionChanged: (Set<int> value) =>
                    setState(() => _tab = value.first),
              ),
            ),
            Expanded(
              child: switch (_tab) {
                0 => _FavoritesTab(onOpen: _openProduct, onFind: _goFind),
                1 => _RecentlyViewedTab(onOpen: _openProduct, onFind: _goFind),
                _ => _HistoryTab(store: deps.historyStore, onFind: _goFind),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoritesTab extends StatelessWidget {
  const _FavoritesTab({required this.onOpen, required this.onFind});

  final void Function(Product product) onOpen;
  final VoidCallback onFind;

  @override
  Widget build(BuildContext context) {
    final AppDependencies deps = AppScope.of(context);

    return ListenableBuilder(
      listenable: deps.favorites,
      builder: (BuildContext context, _) {
        if (!deps.favorites.isLoaded) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.screen),
            child: ProductGridSkeleton(),
          );
        }
        final List<Product> products = deps.catalog.byIds(deps.favorites.ids);
        if (products.isEmpty) {
          return EmptyStateView(
            icon: Icons.favorite_border,
            title: '아직 찜한 상품이 없어요',
            message: '마음에 드는 상품의 하트를 누르면 여기에 모아둘게요.',
            actionLabel: '선물 찾아보기',
            onAction: onFind,
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            0,
            AppSpacing.screen,
            AppSpacing.bottomAction,
          ),
          children: <Widget>[
            Text(
              '${products.length}개의 상품을 찜했어요',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: AppSpacing.md),
            ProductGrid(products: products, onOpen: onOpen),
          ],
        );
      },
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
            icon: Icons.history,
            title: '최근 본 상품이 없어요',
            message: '상품을 열어보면 여기에서 다시 찾을 수 있어요.',
            actionLabel: '선물 찾아보기',
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

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.store, required this.onFind});

  final HistoryStore store;
  final VoidCallback onFind;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: store,
      builder: (BuildContext context, _) {
        if (store.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (store.entries.isEmpty) {
          return EmptyStateView(
            icon: Icons.assignment_outlined,
            title: '아직 추천 기록이 없어요',
            message: '선물 찾기를 한 번 마치면 여기에서 다시 볼 수 있어요.',
            actionLabel: '선물 찾기 시작',
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          DateFormatKo.relativeDay(entry.createdAt),
                          style: text.labelSmall,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(entry.title, style: text.titleMedium),
                        const SizedBox(height: AppSpacing.xs),
                        Text(entry.summary, style: text.bodyMedium),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.inkMuted),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
