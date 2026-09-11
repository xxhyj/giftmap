import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/currency_format.dart';
import '../../../library/application/favorites_store.dart';
import '../../domain/product.dart';
import 'product_visual.dart';

/// 상품 카드의 텍스트 줄 수 규칙.
///
/// 실제 DB의 상품명은 Mock보다 길어질 수 있으므로 모든 카드가 같은 규칙을 쓴다.
abstract final class ProductTextLines {
  static const int brand = 1;
  static const int name = 2;
  static const int reason = 2;
  static const int description = 2;
}

/// 가격 표기. 할인은 `할인율 → 판매가 → 정가` 순으로 읽힌다.
///
/// 가격을 알 수 없으면 0원이 아니라 "가격 확인 필요"를 보여준다.
class ProductPrice extends StatelessWidget {
  const ProductPrice({required this.product, this.large = false, super.key});

  final Product product;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final TextStyle? priceStyle =
        (large ? text.headlineSmall : text.titleMedium)?.copyWith(
          color: AppColors.textPrimary,
        );

    if (!product.hasPrice) {
      return Text(
        '가격 확인 필요',
        style: (large ? text.titleMedium : text.labelMedium)?.copyWith(
          color: AppColors.textSecondary,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    // 긴 상품명 때문에 가격이 밀리거나 잘리지 않도록 줄바꿈을 허용한다.
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.xs,
      children: <Widget>[
        if (product.hasDiscount)
          Text(
            '${product.discountRate}%',
            style: priceStyle?.copyWith(color: AppColors.accent),
          ),
        Text(CurrencyFormat.won(product.price!), style: priceStyle),
        if (product.hasDiscount)
          Text(
            CurrencyFormat.won(product.originalPrice!),
            style: text.labelSmall?.copyWith(
              decoration: TextDecoration.lineThrough,
              color: AppColors.textTertiary,
            ),
          ),
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
        final String label = saved ? '찜 해제' : '찜하기';
        return IconButton(
          onPressed: () => store.toggle(productId),
          iconSize: dense ? 20 : 24,
          // dense 상태에서도 터치 영역은 48dp 이상을 유지한다.
          constraints: const BoxConstraints(
            minWidth: AppSpacing.minTouchTarget,
            minHeight: AppSpacing.minTouchTarget,
          ),
          padding: EdgeInsets.zero,
          tooltip: label,
          icon: Icon(
            saved ? Icons.favorite : Icons.favorite_border,
            // 선택 상태를 색과 아이콘 형태로 함께 전달한다.
            color: saved ? AppColors.accent : AppColors.textTertiary,
            semanticLabel: label,
          ),
        );
      },
    );
  }
}

/// 이미지 위에 얹는 찜 버튼.
class _ImageFavoriteButton extends StatelessWidget {
  const _ImageFavoriteButton({required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface.withValues(alpha: 0.88),
      shape: const CircleBorder(),
      child: FavoriteButton(productId: productId, dense: true),
    );
  }
}

/// 상품 카드의 텍스트 블록. 모든 카드가 같은 위계와 줄 수 규칙을 공유한다.
class _ProductCardText extends StatelessWidget {
  const _ProductCardText({required this.product, this.badge});

  final Product product;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          product.brandLabel,
          style: text.labelSmall,
          maxLines: ProductTextLines.brand,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          product.productName,
          style: text.bodyMedium,
          maxLines: ProductTextLines.name,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.sm),
        ProductPrice(product: product),
        if (badge != null && badge!.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          ProductBadgeChip(label: badge!),
        ],
      ],
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
    return Semantics(
      button: true,
      // 카드에서는 말줄임이 있어도 스크린리더에는 전체 상품명을 읽어준다.
      label: '${product.brandLabel} ${product.productName}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 이미지가 남는 높이를 흡수해 텍스트가 잘리지 않게 한다.
            Expanded(
              child: Stack(
                children: <Widget>[
                  ProductImage(product: product, expand: true),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: _ImageFavoriteButton(productId: product.id),
                  ),
                  if (product.isDemo)
                    const Positioned(
                      left: AppSpacing.sm,
                      top: AppSpacing.sm,
                      child: DemoBadge(compact: true),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ExcludeSemantics(
              child: _ProductCardText(product: product, badge: badge),
            ),
          ],
        ),
      ),
    );
  }
}

/// 가로 캐러셀용 카드.
class ProductTileCard extends StatelessWidget {
  const ProductTileCard({
    required this.product,
    required this.onTap,
    this.badge,
    super.key,
  });

  final Product product;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${product.brandLabel} ${product.productName}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Stack(
                children: <Widget>[
                  ProductImage(product: product, expand: true),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: _ImageFavoriteButton(productId: product.id),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ExcludeSemantics(
              child: _ProductCardText(product: product, badge: badge),
            ),
          ],
        ),
      ),
    );
  }
}

/// 목록형(가로 배치) 카드. 기록처럼 정보를 촘촘히 보여줄 때 쓴다.
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

    return Semantics(
      button: true,
      label: '${product.brandLabel} ${product.productName}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 84,
                child: ProductImage(
                  product: product,
                  radius: AppRadius.button,
                  showBrandMark: false,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        product.brandLabel,
                        style: text.labelSmall,
                        maxLines: ProductTextLines.brand,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        product.productName,
                        style: text.bodyMedium,
                        maxLines: ProductTextLines.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ProductPrice(product: product),
                    ],
                  ),
                ),
              ),
              trailing ?? FavoriteButton(productId: product.id, dense: true),
            ],
          ),
        ),
      ),
    );
  }
}

/// 추천 이유 등을 담는 작은 배지.
class ProductBadgeChip extends StatelessWidget {
  const ProductBadgeChip({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: AppColors.accentContainer,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.onAccentContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
