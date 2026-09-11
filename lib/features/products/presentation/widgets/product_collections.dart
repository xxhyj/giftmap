import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/product.dart';
import 'carousel_navigation_button.dart';
import 'product_card.dart';

/// 화면 폭에 따른 상품 카드 레이아웃 계산.
///
/// 상품 개수나 화면 크기를 특정 값으로 가정하지 않는다.
abstract final class ProductLayout {
  /// 카드 한 장의 최소 폭. 이보다 좁아지면 열 수를 줄인다.
  static const double minCardWidth = 150;

  /// 그리드 열 수. 좁은 화면에서는 1열까지 떨어진다.
  static int columnsFor(double width) {
    final int columns =
        ((width + AppSpacing.md) / (minCardWidth + AppSpacing.md)).floor();
    return columns.clamp(1, 4);
  }

  /// 카드 비율. 텍스트 배율이 커지면 글자 영역이 늘어나므로 함께 낮춘다.
  ///
  /// 카드에는 이미지 외에 브랜드 1줄, 상품명 2줄, 가격, 배지가 들어갈 수 있어
  /// 이미지(1:1)보다 충분히 여유 있는 세로 공간을 확보한다.
  static double aspectRatioFor(BuildContext context) {
    final double scale = MediaQuery.textScalerOf(context).scale(15) / 15;
    return (0.52 - (scale - 1) * 0.14).clamp(0.32, 0.56);
  }

  /// 캐러셀 카드 비율. 그리드보다 텍스트 영역을 조금 더 준다.
  static double carouselAspectRatioFor(BuildContext context) =>
      (aspectRatioFor(context) + 0.02).clamp(0.32, 0.58);

  /// 캐러셀 카드 폭.
  static double carouselCardWidth(double viewportWidth) {
    if (viewportWidth >= 900) return 220;
    if (viewportWidth >= 600) return 190;
    if (viewportWidth <= 340) return 140;
    return 158;
  }
}

/// 반응형 2열(넓은 화면에서는 그 이상) 상품 그리드.
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
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = ProductLayout.columnsFor(constraints.maxWidth);
        return GridView.builder(
          padding: padding,
          shrinkWrap: shrinkWrap,
          physics: physics,
          itemCount: products.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.lg,
            childAspectRatio: ProductLayout.aspectRatioFor(context),
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
      },
    );
  }
}

/// 손가락으로 넘기는 가로 상품 캐러셀.
///
/// 각 캐러셀은 자신만의 `PageController`를 가진다. 현재 위치가 바뀌면
/// [onPositionChanged]로 알려 주어 화살표 버튼 상태가 swipe와 동기화된다.
class ProductCarousel extends StatefulWidget {
  const ProductCarousel({
    required this.products,
    required this.onOpen,
    this.badgeOf,
    this.onPositionChanged,
    this.controller,
    super.key,
  });

  final List<Product> products;
  final void Function(Product product) onOpen;
  final String? Function(Product product)? badgeOf;

  /// (현재 페이지, 전체 페이지 수)
  final void Function(double page, int pageCount)? onPositionChanged;

  /// 외부에서 이동을 제어하기 위한 핸들.
  final ProductCarouselController? controller;

  @override
  State<ProductCarousel> createState() => _ProductCarouselState();
}

/// 캐러셀 이동 명령을 전달하는 얇은 핸들.
class ProductCarouselController {
  void Function(int delta)? _moveBy;

  void previous() => _moveBy?.call(-1);

  void next() => _moveBy?.call(1);
}

class _ProductCarouselState extends State<ProductCarousel> {
  PageController? _controller;
  double _page = 0;

  @override
  void initState() {
    super.initState();
    widget.controller?._moveBy = _animateBy;
  }

  @override
  void didUpdateWidget(ProductCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._moveBy = null;
      widget.controller?._moveBy = _animateBy;
    }
  }

  @override
  void dispose() {
    widget.controller?._moveBy = null;
    _controller?.dispose();
    super.dispose();
  }

  /// 화면 폭이 바뀌면 viewportFraction이 달라지므로 controller를 다시 만든다.
  PageController _controllerFor(double fraction) {
    final PageController? current = _controller;
    if (current != null && current.viewportFraction == fraction) return current;
    final int initialPage = (current != null && current.hasClients)
        ? (current.page?.round() ?? 0)
        : _page.round();
    current?.dispose();
    final PageController created = PageController(
      viewportFraction: fraction,
      initialPage: initialPage,
    );
    _controller = created;
    _page = initialPage.toDouble();
    return created;
  }

  void _animateBy(int delta) {
    final PageController? controller = _controller;
    if (controller == null || !controller.hasClients) return;
    final int target = (_page.round() + delta).clamp(
      0,
      widget.products.length - 1,
    );
    controller.animateToPage(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _notify(double page) {
    _page = page;
    widget.onPositionChanged?.call(page, widget.products.length);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.products.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final double cardWidth = ProductLayout.carouselCardWidth(width);
        // 다음 카드가 살짝 보이도록 viewport를 카드보다 좁게 잡는다.
        final double fraction = ((cardWidth + AppSpacing.md) / width).clamp(
          0.28,
          1.0,
        );
        final PageController controller = _controllerFor(fraction);

        final double scale = MediaQuery.textScalerOf(context).scale(15) / 15;
        final double height = math.min(
          cardWidth / ProductLayout.carouselAspectRatioFor(context),
          460 * scale,
        );

        return SizedBox(
          height: height,
          child: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification notification) {
              if (controller.hasClients) {
                final double? page = controller.page;
                if (page != null && (page - _page).abs() > 0.01) _notify(page);
              }
              return false;
            },
            child: PageView.builder(
              controller: controller,
              padEnds: false,
              itemCount: widget.products.length,
              itemBuilder: (BuildContext context, int index) {
                final Product product = widget.products[index];
                return Padding(
                  padding: const EdgeInsetsDirectional.only(end: AppSpacing.md),
                  child: ProductTileCard(
                    product: product,
                    badge: widget.badgeOf?.call(product),
                    onTap: () => widget.onOpen(product),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// 캐러셀 섹션 하나(머리글 + 화살표 + 캐러셀).
///
/// 상품이 없으면 아무것도 그리지 않는다. 상품이 하나면 화살표는 비활성이다.
class ProductCarouselSection extends StatefulWidget {
  const ProductCarouselSection({
    required this.title,
    required this.products,
    required this.onOpen,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.badgeOf,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Product> products;
  final void Function(Product product) onOpen;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? Function(Product product)? badgeOf;

  @override
  State<ProductCarouselSection> createState() => _ProductCarouselSectionState();
}

class _ProductCarouselSectionState extends State<ProductCarouselSection> {
  final ProductCarouselController _carousel = ProductCarouselController();
  double _page = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.products.isEmpty) return const SizedBox.shrink();

    final int count = widget.products.length;
    final bool canPrevious = count > 1 && _page > 0.01;
    final bool canNext = count > 1 && _page < count - 1 - 0.01;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        CarouselSectionHeader(
          title: widget.title,
          subtitle: widget.subtitle,
          actionLabel: widget.actionLabel,
          onAction: widget.onAction,
          showControls: true,
          onPrevious: canPrevious ? _carousel.previous : null,
          onNext: canNext ? _carousel.next : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
          child: ProductCarousel(
            products: widget.products,
            onOpen: widget.onOpen,
            badgeOf: widget.badgeOf,
            controller: _carousel,
            onPositionChanged: (double page, int _) {
              if ((page - _page).abs() < 0.01) return;
              setState(() => _page = page);
            },
          ),
        ),
      ],
    );
  }
}

/// 섹션 머리글. 제목·설명과 함께 캐러셀 이동 버튼을 배치한다.
class CarouselSectionHeader extends StatelessWidget {
  const CarouselSectionHeader({
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.onPrevious,
    this.onNext,
    this.showControls = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  /// 캐러셀 섹션이면 화살표 자리를 항상 유지한다(비활성 포함).
  final bool showControls;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.lg,
        AppSpacing.screen,
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
                  Text(
                    subtitle!,
                    style: text.labelSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          if (showControls) ...<Widget>[
            const SizedBox(width: AppSpacing.xs),
            CarouselNavigationButton.previous(onPressed: onPrevious),
            const SizedBox(width: AppSpacing.sm),
            CarouselNavigationButton.next(onPressed: onNext),
          ],
        ],
      ),
    );
  }
}

/// 캐러셀이 아닌 섹션의 머리글.
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
    return CarouselSectionHeader(
      title: title,
      subtitle: subtitle,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}

/// 로딩 중 자리를 잡아주는 스켈레톤 블록.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    this.width,
    this.height = 14,
    this.radius = AppRadius.xs,
    super.key,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// 상품 그리드 스켈레톤. 실제 카드와 같은 비율로 자리를 잡는다.
class ProductGridSkeleton extends StatelessWidget {
  const ProductGridSkeleton({this.itemCount = 4, super.key});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '상품을 불러오는 중',
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: itemCount,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: ProductLayout.columnsFor(constraints.maxWidth),
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.lg,
              childAspectRatio: ProductLayout.aspectRatioFor(context),
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
                  const SizedBox(height: AppSpacing.sm),
                  const SkeletonBox(width: 84, height: 16),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
