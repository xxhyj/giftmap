import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/responsive_body.dart';
import '../../../core/widgets/rounded_surface.dart';
import '../../../core/widgets/selectable_chip.dart';
import '../../products/domain/product.dart';
import '../../products/presentation/product_detail_screen.dart';
import '../../products/presentation/widgets/product_collections.dart';
import '../application/gift_finder_controller.dart';
import '../data/product_recommendation_engine.dart';
import '../domain/gift_intent.dart';
import '../domain/recommendation_result.dart';

/// 추천 결과. 카테고리가 아니라 상품이 주인공이다.
///
/// 상단에 사용자가 고른 조건과 추천 방향을 요약하고,
/// 아래에는 조건에 맞춰 점수화한 상품을 2열 그리드로 보여준다.
class ResultScreen extends StatefulWidget {
  const ResultScreen({
    this.intent,
    this.picks,
    this.directions,
    this.title,
    super.key,
  });

  /// 기록에서 열 때처럼 controller 상태 대신 값을 직접 넘기는 경우에 쓴다.
  final GiftIntent? intent;
  final List<ProductPick>? picks;
  final List<GiftRecommendation>? directions;
  final String? title;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  static const int _initialCount = 8;

  int _visible = _initialCount;

  void _openProduct(ProductPick pick) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ProductDetailScreen(
          product: pick.product,
          recommendationReason: pick.reason,
        ),
      ),
    );
  }

  void _editConditions(GiftFinderController controller) {
    controller.goToStep(0);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppDependencies deps = AppScope.of(context);
    final GiftFinderController controller = deps.finderController;

    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) {
        final GiftIntent? intent = widget.intent ?? controller.result?.intent;
        final List<ProductPick> picks = widget.picks ?? controller.picks;
        final List<GiftRecommendation> directions =
            widget.directions ??
            controller.result?.items ??
            const <GiftRecommendation>[];

        if (intent == null || picks.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('추천 결과')),
            body: EmptyStateView(
              icon: Icons.inbox_outlined,
              title: '표시할 추천이 없어요',
              message: '조건을 다시 선택하면 새로운 선물을 찾아드릴게요.',
              actionLabel: '조건 수정',
              onAction: () => _editConditions(controller),
            ),
          );
        }

        final List<ProductPick> shown = picks.take(_visible).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('추천 결과'),
            actions: <Widget>[
              if (widget.picks == null)
                TextButton(
                  onPressed: () => _editConditions(controller),
                  child: const Text('조건 수정'),
                ),
            ],
          ),
          body: SafeArea(
            child: ResponsiveBody(
              child: ListView(
                padding: const EdgeInsets.only(bottom: AppSpacing.bottomAction),
                children: <Widget>[
                  _ResultHeader(
                    intent: intent,
                    directions: directions,
                    title: widget.title,
                    count: picks.length,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screen,
                    ),
                    child: ProductGrid(
                      products: shown
                          .map((ProductPick p) => p.product)
                          .toList(growable: false),
                      badgeOf: (Product product) => shown
                          .firstWhere(
                            (ProductPick p) => p.product.id == product.id,
                          )
                          .badge,
                      onOpen: (Product product) => _openProduct(
                        shown.firstWhere(
                          (ProductPick p) => p.product.id == product.id,
                        ),
                      ),
                    ),
                  ),
                  if (_visible < picks.length) ...<Widget>[
                    const SizedBox(height: AppSpacing.lg),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screen,
                      ),
                      child: OutlinedButton(
                        onPressed: () =>
                            setState(() => _visible = picks.length),
                        child: Text('추천 상품 더 보기 (${picks.length - _visible})'),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screen,
                    ),
                    child: NoticeBlock(text: deps.productDisclaimer),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({
    required this.intent,
    required this.directions,
    required this.count,
    this.title,
  });

  final GiftIntent intent;
  final List<GiftRecommendation> directions;
  final int count;
  final String? title;

  /// "30대 친구의 생일 선물" 형태의 요약 문장.
  String get _headline {
    if (title != null) return title!;
    final String age = intent.ageBand == AgeBand.unspecified
        ? ''
        : '${intent.ageBand.label} ';
    return '$age${intent.relationship.label}의 ${intent.situation.label} 선물';
  }

  String get _reason {
    final List<String> names = directions
        .take(2)
        .map((GiftRecommendation d) => d.title)
        .toList();
    if (names.isEmpty) {
      return '예산과 상황에 맞춰 실패 확률이 낮은 상품을 골랐어요.';
    }
    return '${names.join('와 ')} 방향을 중심으로, '
        '${intent.budgetLabel} 예산에서 만족도가 높은 상품을 골랐어요.';
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.md,
        AppSpacing.screen,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(_headline, style: text.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${intent.budgetLabel} · ${intent.preferenceLabel} · 추천 상품 $count개',
            style: text.labelSmall,
          ),
          const SizedBox(height: AppSpacing.md),
          RoundedSurface(
            color: AppColors.primaryContainer,
            bordered: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('이런 선물을 추천해요', style: text.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(_reason, style: text.bodyMedium),
              ],
            ),
          ),
          if (intent.avoidTags.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            ChipWrap(
              children: intent.avoidTags
                  .map(
                    (String tag) => ReadOnlyChip(
                      label: '${AvoidTags.labels[tag] ?? tag} 제외',
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }
}
