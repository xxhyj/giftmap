import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../app/app_shell.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/responsive_body.dart';
import '../../products/domain/product.dart';
import '../../products/presentation/product_detail_screen.dart';
import '../../products/presentation/widgets/product_collections.dart';

/// 찜 탭. 사용자가 저장한 상품만 보여준다.
///
/// 저장은 기기 로컬(`IdListStorage`)이라 앱을 다시 켜도 유지된다.
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  void _openProduct(BuildContext context, Product product) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            ProductDetailScreen(product: product),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppDependencies deps = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('찜')),
      body: SafeArea(
        child: ResponsiveBody(
          child: ListenableBuilder(
            listenable: deps.favorites,
            builder: (BuildContext context, _) {
              if (!deps.favorites.isLoaded) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                  child: ProductGridSkeleton(),
                );
              }

              // 카탈로그에 없는 id는 자동으로 걸러지므로 상품 수가 바뀌어도 안전하다.
              final List<Product> products = deps.catalog.byIds(
                deps.favorites.ids,
              );

              if (products.isEmpty) {
                return EmptyStateView(
                  icon: Icons.favorite_border,
                  title: '아직 찜한 상품이 없어요',
                  message: '마음에 드는 상품의 하트를 누르면 여기에 모아둘게요.',
                  actionLabel: '카테고리 둘러보기',
                  onAction: () =>
                      deps.shellTab.goTo(ShellTabController.categoryTab),
                  secondaryActionLabel: '선물추천 받기',
                  onSecondaryAction: () =>
                      deps.shellTab.goTo(ShellTabController.finderTab),
                );
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  AppSpacing.sm,
                  AppSpacing.screen,
                  AppSpacing.bottomAction,
                ),
                children: <Widget>[
                  Text(
                    '${products.length}개의 상품을 찜했어요',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ProductGrid(
                    products: products,
                    onOpen: (Product product) => _openProduct(context, product),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
