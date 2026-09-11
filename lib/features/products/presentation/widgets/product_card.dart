import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/currency_format.dart';
import '../../../library/application/favorites_store.dart';
import '../../domain/product.dart';
import 'product_visual.dart';

/// 가격 표기 블록. 할인 정보가 있으면 할인율 → 판매가 → 정가 순으로 읽힌다.
class ProductPrice extends StatelessWidget {
  const ProductPrice({required this.product, this.large = false, super.key});

  final Product product;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final TextStyle? priceStyle =
        (large ? text.headlineSmall : text.titleMedium)?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        if (product.hasDiscount) ...<Widget>[
          Text(
            '${product.discountRate}%',
            style: priceStyle?.copyWith(color: AppColors.brandCoralDark),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        Flexible(
          child: Text(
            CurrencyFormat.won(product.price),
            style: priceStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (product.hasDiscount) ...<Widget>[
          const SizedBox(width: AppSpacing.xs),
          Text(
            CurrencyFormat.won(product.originalPrice!),
            style: text.labelSmall?.copyWith(
              decoration: TextDecoration.lineThrough,
              color: AppColors.inkMuted,
            ),
          ),
        ],
      ],
    );
  }
}

/// 앱 어디에서나 같은 방식으로 동작하는 찜 버튼.
class FavoriteButton extends StatelessWidget {
  const FavoriteButton({
    required this.productId,
    this.dense = false,
    super.key,
  });

  final String productId;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final FavoritesStore store = AppScope.of(context).favorites;

    return ListenableBuilder(
      listenable: store,
      builder: (BuildContext context, _) {
        final bool saved = store.contains(productId);
        return IconButton(
          onPressed: () => store.toggle(productId),
          iconSize: dense ? 20 : 24,
          visualDensity: dense ? VisualDensity.compact : null,
          constraints: dense
              ? const BoxConstraints(minWidth: 36, minHeight: 36)
              : null,
          tooltip: saved ? '찜 해제' : '찜하기',
          icon: Icon(
            saved ? Icons.favorite : Icons.favorite_border,
            color: saved ? AppColors.brandCoral : AppColors.inkMuted,
          ),
        );
      },
    );
  }
}

/// 2열 그리드용 상품 카드. 이미지가 카드의 주인공이다.
class ProductGridCard extends StatelessWidget {
  const ProductGridCard({
    required this.product,
    required this.onTap,
    this.badge,
    super.key,
  });

  final Product product;
  final VoidCallback onTap;

  /// 추천 이유 같은 짧은 문구.
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Stack(
            children: <Widget>[
              ProductImage(product: product),
              Positioned(
                right: 0,
                top: 0,
                child: Material(
                  color: Colors.white.withValues(alpha: 0.82),
                  shape: const CircleBorder(),
                  child: FavoriteButton(productId: product.id, dense: true),
                ),
              ),
              if (product.isDemo)
                const Positioned(
                  left: AppSpacing.sm,
                  top: AppSpacing.sm,
                  child: DemoBadge(compact: true),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            product.brandName,
            style: text.labelSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            product.productName,
            style: text.bodyMedium?.copyWith(color: AppColors.ink),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xs),
          ProductPrice(product: product),
          if (badge != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            _BadgeChip(label: badge!),
          ],
        ],
      ),
    );
  }
}

/// 가로 스크롤 캐러셀용 카드.
class ProductTileCard extends StatelessWidget {
  const ProductTileCard({
    required this.product,
    required this.onTap,
    this.width = 156,
    super.key,
  });

  final Product product;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Stack(
              children: <Widget>[
                ProductImage(product: product),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.82),
                    shape: const CircleBorder(),
                    child: FavoriteButton(productId: product.id, dense: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              product.brandName,
              style: text.labelSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              product.productName,
              style: text.bodyMedium?.copyWith(color: AppColors.ink),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xs),
            ProductPrice(product: product),
          ],
        ),
      ),
    );
  }
}

/// 목록형(가로 배치) 카드. 보관함처럼 정보를 촘촘히 보여줄 때 쓴다.
class ProductRowCard extends StatelessWidget {
  const ProductRowCard({
    required this.product,
    required this.onTap,
    this.trailing,
    super.key,
  });

  final Product product;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 88,
              child: ProductImage(
                product: product,
                radius: AppRadius.button,
                showBrandMark: false,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    product.brandName,
                    style: text.labelSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.productName,
                    style: text.bodyMedium?.copyWith(color: AppColors.ink),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ProductPrice(product: product),
                ],
              ),
            ),
            trailing ?? FavoriteButton(productId: product.id, dense: true),
          ],
        ),
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: AppColors.brandCoral.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.brandCoralDark,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
