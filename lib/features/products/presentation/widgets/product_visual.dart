import 'package:flutter/material.dart';

import '../../../../core/config/api_bootstrap.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/product.dart';

/// 카테고리별 시각 정체성.
///
/// 번들 데모 상품은 외부 이미지 URL을 쓰지 않고, asset 이미지가 없을 때도
/// 상품 영역이 비어 보이지 않도록 카테고리 색과 아이콘으로 그린다.
/// 수집한 실제 상품만 공급원이 공개한 이미지 URL을 쓰고,
/// 불러오지 못하면 같은 카테고리 비주얼로 되돌아간다.
class ProductVisual {
  const ProductVisual(this.background, this.foreground, this.icon);

  final Color background;
  final Color foreground;
  final IconData icon;

  static const ProductVisual _fallback = ProductVisual(
    Color(0xFFF1EFEA),
    Color(0xFF7A7466),
    Icons.card_giftcard_outlined,
  );

  static const Map<String, ProductVisual> _byCategory = <String, ProductVisual>{
    'perfume': ProductVisual(
      Color(0xFFF3EAE4),
      Color(0xFF8A5F45),
      Icons.water_drop_outlined,
    ),
    'hand_care': ProductVisual(
      Color(0xFFEFF1E9),
      Color(0xFF5E6B4A),
      Icons.back_hand_outlined,
    ),
    'body_care': ProductVisual(
      Color(0xFFEDF0F2),
      Color(0xFF4E6472),
      Icons.spa_outlined,
    ),
    'tea_coffee': ProductVisual(
      Color(0xFFF0EBE2),
      Color(0xFF7A5B38),
      Icons.emoji_food_beverage_outlined,
    ),
    'dessert': ProductVisual(
      Color(0xFFF6EDE6),
      Color(0xFF9A6240),
      Icons.cake_outlined,
    ),
    'candle': ProductVisual(
      Color(0xFFF4EEE6),
      Color(0xFF8C6B44),
      Icons.local_fire_department_outlined,
    ),
    'stationery': ProductVisual(
      Color(0xFFEDEFF4),
      Color(0xFF4F5B77),
      Icons.edit_note_outlined,
    ),
    'desk': ProductVisual(
      Color(0xFFECEEF0),
      Color(0xFF505A63),
      Icons.desktop_mac_outlined,
    ),
    'homewear': ProductVisual(
      Color(0xFFF2EFF3),
      Color(0xFF6B5C74),
      Icons.bed_outlined,
    ),
    'fashion_accessory': ProductVisual(
      Color(0xFFF4EDEF),
      Color(0xFF7E5764),
      Icons.diamond_outlined,
    ),
    'wallet': ProductVisual(
      Color(0xFFF0EDE8),
      Color(0xFF6E5B45),
      Icons.account_balance_wallet_outlined,
    ),
    'tumbler': ProductVisual(
      Color(0xFFE9EFF1),
      Color(0xFF44636E),
      Icons.local_cafe_outlined,
    ),
    'living': ProductVisual(
      Color(0xFFEFF1EE),
      Color(0xFF57665C),
      Icons.chair_outlined,
    ),
    'beauty': ProductVisual(
      Color(0xFFF5EDF0),
      Color(0xFF8A5B6B),
      Icons.face_retouching_natural_outlined,
    ),
    'hobby': ProductVisual(
      Color(0xFFEDF1EC),
      Color(0xFF4F6B54),
      Icons.auto_awesome_outlined,
    ),
  };

  static ProductVisual of(String category) =>
      _byCategory[category] ?? _fallback;
}

/// 상품 이미지 영역.
///
/// `imageAsset`이 있으면 asset을 쓰고, 없으면 카테고리 비주얼을 그린다.
/// 카드에서 가장 먼저 인식되도록 충분한 비율을 차지한다.
class ProductImage extends StatelessWidget {
  const ProductImage({
    required this.product,
    this.aspectRatio = 1,
    this.radius = AppRadius.card,
    this.showBrandMark = true,
    this.expand = false,
    super.key,
  });

  final Product product;
  final double aspectRatio;
  final double radius;
  final bool showBrandMark;

  /// true면 비율 대신 부모가 준 공간을 모두 채운다.
  /// 카드에서 이미지가 남는 높이를 흡수해 텍스트가 잘리지 않게 한다.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final ProductVisual visual = ProductVisual.of(product.category);
    final String? asset = product.imageAsset;
    final String? url = product.imageUrl;

    final Widget painted = _PaintedVisual(
      visual: visual,
      product: product,
      showBrandMark: showBrandMark,
    );

    // asset → 수집한 공개 이미지 → 카테고리 비주얼 순으로 그린다.
    final Widget content;
    if (asset != null) {
      content = Image.asset(
        asset,
        fit: BoxFit.cover,
        semanticLabel: product.productName,
      );
    } else if (url != null) {
      content = Image.network(
        // 웹에서만 서버를 거친다(판매처가 다른 출처의 요청을 막는다).
        ApiBootstrap.imageUrl(url),
        fit: BoxFit.cover,
        semanticLabel: product.productName,
        // 새 이미지가 준비될 때까지 앞 이미지를 유지해 깜빡임을 줄인다.
        gaplessPlayback: true,
        // 목록 카드는 작게 그려지므로 원본 해상도까지 디코딩할 필요가 없다.
        // 디코딩 비용과 메모리를 줄여 스크롤 중 이미지가 늦게 뜨는 것을 덜어준다.
        cacheWidth: expand ? 400 : null,
        // 받는 중에는 조용한 자리표시자를 둔다.
        // 여기서 카테고리 그림을 보여주면 "이미지가 깨졌다"로 읽힌다.
        loadingBuilder: (
          BuildContext context,
          Widget child,
          ImageChunkEvent? progress,
        ) => progress == null ? child : const _LoadingVisual(),
        // 정말 못 받은 경우에만 카테고리 그림으로 대신한다.
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
            painted,
      );
    } else {
      content = painted;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: expand
          ? SizedBox.expand(child: content)
          : AspectRatio(aspectRatio: aspectRatio, child: content),
    );
  }
}

/// 이미지를 받는 동안 두는 자리표시자.
///
/// 카테고리 그림을 쓰면 다 받은 뒤 그림이 바뀌어 "깨졌다가 고쳐진" 것처럼 보인다.
/// 그래서 아무 의미 없는 옅은 면만 둔다.
class _LoadingVisual extends StatelessWidget {
  const _LoadingVisual();

  @override
  Widget build(BuildContext context) =>
      const ColoredBox(color: AppColors.surfaceMuted);
}

class _PaintedVisual extends StatelessWidget {
  const _PaintedVisual({
    required this.visual,
    required this.product,
    required this.showBrandMark,
  });

  final ProductVisual visual;
  final Product product;
  final bool showBrandMark;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: visual.background,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // 바닥에 깔리는 넓은 색면으로 단순한 아이콘 나열처럼 보이지 않게 한다.
          Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: 0.34,
              child: Container(
                color: visual.foreground.withValues(alpha: 0.09),
              ),
            ),
          ),
          Center(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double size = constraints.biggest.shortestSide * 0.34;
                return Icon(
                  visual.icon,
                  size: size.clamp(20.0, 72.0),
                  color: visual.foreground.withValues(alpha: 0.85),
                );
              },
            ),
          ),
          if (showBrandMark)
            Positioned(
              left: AppSpacing.sm,
              bottom: AppSpacing.sm,
              child: Text(
                product.brandLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: visual.foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 품절이 확인된 상품에 붙이는 표시.
///
/// 재고를 알려주지 않는 공급원이 있어 "품절 아님"은 단정하지 않는다.
/// 공급원이 품절이라고 알려준 상품에만 붙인다.
class SoldOutBadge extends StatelessWidget {
  const SoldOutBadge({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : AppSpacing.sm,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(
        '품절',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontSize: compact ? 10 : 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 데모 데이터임을 알리는 작은 표시.
class DemoBadge extends StatelessWidget {
  const DemoBadge({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : AppSpacing.sm,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(
        compact ? 'DEMO' : '데모 상품',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontSize: compact ? 10 : 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
