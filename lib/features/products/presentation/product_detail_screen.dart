import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/responsive_body.dart';
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
/// 수집한 실제 상품은 하단의 단일 CTA로 원본 판매 페이지를 외부 브라우저에서 열고,
/// 번들 데모 상품은 판매 페이지가 없으므로 CTA가 비활성 상태로 남는다.
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
    // build 중 알림이 퍼지지 않도록 첫 프레임 이후에 기록한다.
    final AppDependencies deps = AppScope.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) deps.recentlyViewed.markViewed(widget.product.id);
    });
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
        child: ResponsiveBody(
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            children: <Widget>[
              Stack(
                children: <Widget>[
                  ProductImage(
                    product: product,
                    radius: 0,
                    showBrandMark: false,
                  ),
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
                    Text(product.brandLabel, style: text.labelMedium),
                    const SizedBox(height: AppSpacing.xs),
                    // 상세에서는 말줄임 없이 전체 상품명을 보여준다.
                    Text(product.productName, style: text.headlineSmall),
                    const SizedBox(height: AppSpacing.md),
                    ProductPrice(product: product, large: true),
                    const SizedBox(height: AppSpacing.xs),
                    // 데모 상품에만 데모 고지를 붙인다.
                    // 수집한 실제 상품에는 "언제 확인한 값인지"를 알린다.
                    Text(
                      product.isDemo
                          ? deps.productDisclaimer
                          : _verifiedNotice(product),
                      style: text.labelSmall,
                    ),
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
                    if (product.sourceLabel != null)
                      _InfoRow(label: '판매처', value: product.sourceLabel!),
                    if (product.inStock != null)
                      _InfoRow(
                        label: '재고',
                        value: product.isSoldOut ? '품절' : '판매 중',
                      ),
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

/// 수집한 실제 상품에 붙이는 안내.
///
/// 가격·재고는 수집 시점의 공개 정보라 판매처에서 달라질 수 있다.
/// 언제 확인한 값인지 밝혀 두면 사용자가 판단할 수 있다.
String _verifiedNotice(Product product) {
  final DateTime? verified = product.lastVerifiedAt;
  final String where = product.sourceLabel ?? '판매처';
  if (verified == null) {
    return '$where에 공개된 정보예요. 가격과 재고는 판매처에서 다시 확인해 주세요.';
  }
  final Duration ago = DateTime.now().difference(verified);
  final String when = switch (ago.inDays) {
    <= 0 => '오늘',
    1 => '어제',
    final int days when days < 7 => '$days일 전',
    final int days => '${days ~/ 7}주 전',
  };
  return '$when $where에서 확인한 정보예요. 가격과 재고는 판매처 기준이에요.';
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

/// 하단 고정 액션.
///
/// 수집한 실제 상품에서만 "상품 보러 가기"가 활성화되고, 원본 판매 페이지를
/// 외부 브라우저로 연다. 앱 안에서 결제·구매를 처리하지 않는다.
class _DetailActionBar extends StatelessWidget {
  const _DetailActionBar({required this.product});

  final Product product;

  Future<void> _openStore(BuildContext context) async {
    final Uri? url = Uri.tryParse(product.productUrl ?? '');
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    bool opened = false;
    if (url != null && url.hasScheme) {
      try {
        opened = await launchUrl(url, mode: LaunchMode.externalApplication);
      } on Object {
        // 브라우저를 열 수 없는 환경에서도 화면이 멈추지 않게 한다.
        opened = false;
      }
    }
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text('판매 페이지를 열 수 없어요. 잠시 후 다시 시도해 주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canOpenStore = product.canOpenStore;
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
              switch ((product.isSoldOut, canOpenStore)) {
                (true, _) => '지금은 품절이에요. 다시 들어오면 주문할 수 있어요.',
                (false, true) => '판매처 페이지로 이동해요. 가격과 재고는 판매처 기준이에요.',
                (false, false) => '데모 상품이라 실제 판매 페이지 연동은 준비 중이에요.',
              },
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
                Expanded(
                  child: FilledButton(
                    onPressed: canOpenStore ? () => _openStore(context) : null,
                    child: Text(product.isSoldOut ? '품절' : '상품 보러 가기'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
