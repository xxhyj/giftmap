import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/rounded_surface.dart';
import '../../../core/widgets/selectable_chip.dart';
import '../../gift_finder/domain/gift_intent.dart';
import '../domain/product.dart';
import 'widgets/product_card.dart';
import 'widgets/product_collections.dart';
import 'widgets/product_visual.dart';

/// 상품 상세.
///
/// 화면에 진입하면 최근 본 상품에 자동으로 기록된다.
/// 실제 판매처 연결은 이번 단계에서 구현하지 않으며 CTA는 비활성 상태다.
class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    required this.product,
    this.recommendationReason,
    super.key,
  });

  final Product product;

  /// 추천 결과에서 넘어온 경우의 맞춤 추천 이유.
  final String? recommendationReason;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  bool _recorded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_recorded) return;
    _recorded = true;
    AppScope.of(context).recentlyViewed.markViewed(widget.product.id);
  }

  void _openRelated(Product product) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            ProductDetailScreen(product: product),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Product product = widget.product;
    final AppDependencies deps = AppScope.of(context);
    final TextTheme text = Theme.of(context).textTheme;

    final List<Product> related = deps.catalog.products
        .where(
          (Product p) => p.category == product.category && p.id != product.id,
        )
        .take(6)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(product.categoryLabel),
        actions: <Widget>[FavoriteButton(productId: product.id)],
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          children: <Widget>[
            Stack(
              children: <Widget>[
                ProductImage(product: product, radius: 0, showBrandMark: false),
                if (product.isDemo)
                  const Positioned(
                    left: AppSpacing.screen,
                    top: AppSpacing.md,
                    child: DemoBadge(),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.lg,
                AppSpacing.screen,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(product.brandName, style: text.labelMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(product.productName, style: text.headlineSmall),
                  const SizedBox(height: AppSpacing.md),
                  ProductPrice(product: product, large: true),
                  const SizedBox(height: AppSpacing.xs),
                  Text(deps.productDisclaimer, style: text.labelSmall),
                  const SizedBox(height: AppSpacing.lg),
                  Text(product.description, style: text.bodyLarge),
                  const SizedBox(height: AppSpacing.lg),
                  _ReasonBlock(
                    product: product,
                    customReason: widget.recommendationReason,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('선물할 때 참고하세요', style: text.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  _InfoRow(
                    label: '추천 상황',
                    value: product.occasions.isEmpty
                        ? '상황을 가리지 않아요'
                        : product.occasions
                              .map((GiftSituation s) => s.label)
                              .join(' · '),
                  ),
                  _InfoRow(
                    label: '추천 대상',
                    value: product.recipientTypes.isEmpty
                        ? '관계를 가리지 않아요'
                        : product.recipientTypes
                              .map((RelationshipType r) => r.label)
                              .join(' · '),
                  ),
                  _InfoRow(label: '가격대', value: product.priceRange.label),
                  if (product.subCategory.isNotEmpty)
                    _InfoRow(label: '분류', value: product.subCategory),
                  if (product.tags.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    ChipWrap(
                      children: product.tags
                          .map(
                            (String tag) => ReadOnlyChip(
                              label: '#${AvoidTags.labels[tag] ?? tag}',
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                ],
              ),
            ),
            if (related.isNotEmpty) ...<Widget>[
              SectionTitleRow(
                title: '비슷한 ${product.categoryLabel} 선물',
                subtitle: '같은 분류에서 함께 비교해 보세요',
              ),
              ProductCarousel(products: related, onOpen: _openRelated),
              const SizedBox(height: AppSpacing.lg),
            ],
          ],
        ),
      ),
      bottomNavigationBar: _DetailActionBar(product: product),
    );
  }
}

class _ReasonBlock extends StatelessWidget {
  const _ReasonBlock({required this.product, this.customReason});

  final Product product;
  final String? customReason;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final List<String> reasons = <String>[
      if (customReason != null && customReason!.isNotEmpty) customReason!,
      if (product.recommendationReason.isNotEmpty) product.recommendationReason,
    ];

    return RoundedSurface(
      color: AppColors.surfaceMuted,
      bordered: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('왜 이 상품을 추천했나요?', style: text.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          for (final String reason in reasons)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: AppColors.riskSafe,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(reason, style: text.bodyMedium)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(width: 72, child: Text(label, style: text.labelSmall)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(value, style: text.bodyMedium)),
        ],
      ),
    );
  }
}

/// 하단 고정 액션. 상품 이동은 데모 상태로 비활성이다.
class _DetailActionBar extends StatelessWidget {
  const _DetailActionBar({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.md,
          AppSpacing.screen,
          AppSpacing.md,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.outline)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '데모 상품이라 판매 페이지로 이동하지 않아요.',
              style: Theme.of(context).textTheme.labelSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.outline),
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                  child: FavoriteButton(productId: product.id),
                ),
                const SizedBox(width: AppSpacing.md),
                const Expanded(
                  child: FilledButton(onPressed: null, child: Text('상품 보러가기')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
