import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/product.dart';
import 'product_card.dart';

/// 2열 상품 그리드. 검색 결과와 추천 결과의 기본 표현이다.
class ProductGrid extends StatelessWidget {
  const ProductGrid({
    required this.products,
    required this.onOpen,
    this.badgeOf,
    this.padding = EdgeInsets.zero,
    this.shrinkWrap = true,
    this.physics = const NeverScrollableScrollPhysics(),
    super.key,
  });

  final List<Product> products;
  final void Function(Product product) onOpen;
  final String? Function(Product product)? badgeOf;
  final EdgeInsetsGeometry padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    // 텍스트 배율이 커지면 카드의 글자 영역이 늘어나므로 비율을 함께 낮춘다.
    final double scale = MediaQuery.textScalerOf(context).scale(15) / 15;
    final double ratio = (0.60 - (scale - 1) * 0.18).clamp(0.40, 0.62);

    return GridView.builder(
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
      itemCount: products.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.lg,
        childAspectRatio: ratio,
      ),
      itemBuilder: (BuildContext context, int index) {
        final Product product = products[index];
        return ProductGridCard(
          product: product,
          badge: badgeOf?.call(product),
          onTap: () => onOpen(product),
        );
      },
    );
  }
}

/// 가로 스크롤 상품 목록.
class ProductCarousel extends StatelessWidget {
  const ProductCarousel({
    required this.products,
    required this.onOpen,
    this.height = 268,
    super.key,
  });

  final List<Product> products;
  final void Function(Product product) onOpen;
  final double height;

  @override
  Widget build(BuildContext context) {
    final double scale = MediaQuery.textScalerOf(context).scale(15) / 15;

    return SizedBox(
      height: height * scale.clamp(1.0, 1.35),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
        itemCount: products.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (BuildContext context, int index) {
          final Product product = products[index];
          return ProductTileCard(
            product: product,
            onTap: () => onOpen(product),
          );
        },
      ),
    );
  }
}

/// 홈의 섹션 머리글. "더 보기"가 필요한 경우에만 trailing을 넘긴다.
class SectionTitleRow extends StatelessWidget {
  const SectionTitleRow({
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: text.titleLarge),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: text.labelSmall),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

/// 로딩 중 자리를 잡아주는 스켈레톤 블록.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({this.width, this.height = 14, this.radius = 8, super.key});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// 상품 그리드 스켈레톤.
class ProductGridSkeleton extends StatelessWidget {
  const ProductGridSkeleton({this.itemCount = 4, super.key});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.lg,
        childAspectRatio: 0.60,
      ),
      itemBuilder: (BuildContext context, int index) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const AspectRatio(
              aspectRatio: 1,
              child: SkeletonBox(
                radius: AppRadius.card,
                height: double.infinity,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const SkeletonBox(width: 56, height: 11),
            const SizedBox(height: AppSpacing.xs),
            const SkeletonBox(height: 13),
            const SizedBox(height: AppSpacing.xs),
            const SkeletonBox(width: 84, height: 16),
          ],
        );
      },
    );
  }
}
