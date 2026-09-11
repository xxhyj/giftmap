import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// 홈 상단 검색 진입.
///
/// 실제 입력은 검색 화면에서 받는다. 홈에는 이 검색창 하나만 둔다.
class HomeSearchEntry extends StatelessWidget {
  const HomeSearchEntry({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
      child: Semantics(
        button: true,
        label: '상품 검색',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.button),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.button),
              border: Border.all(color: AppColors.outline),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.search,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '브랜드, 상품, 카테고리 검색',
                    style: text.bodyMedium?.copyWith(
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 선물추천 진입 배너.
///
/// 검색이 아니라 추천 흐름으로 들어가는 것이 이 배너의 유일한 역할이다.
/// 화면을 많이 차지하지 않도록 제목 한 줄, 설명 한 줄, CTA로만 구성한다.
class GiftFinderHeroBanner extends StatelessWidget {
  const GiftFinderHeroBanner({required this.onStart, super.key});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.md,
        AppSpacing.screen,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        // 좁은 화면에서 CTA가 잘리지 않도록 폭이 모자라면 세로로 쌓는다.
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double scale =
                MediaQuery.textScalerOf(context).scale(15) / 15;
            final bool stacked = constraints.maxWidth < 360 || scale > 1.15;

            final Widget copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '무엇을 줄지 고민된다면',
                  style: text.titleLarge?.copyWith(
                    color: AppColors.onPrimaryContainer,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '상황과 예산 몇 가지만 고르면 어울리는 선물을 좁혀드려요.',
                  style: text.labelSmall?.copyWith(
                    color: AppColors.onPrimaryContainer,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            );

            final Widget cta = FilledButton(
              onPressed: onStart,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
              ),
              child: const Text('추천받기'),
            );

            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  copy,
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(width: double.infinity, child: cta),
                ],
              );
            }

            return Row(
              children: <Widget>[
                Expanded(child: copy),
                const SizedBox(width: AppSpacing.md),
                cta,
              ],
            );
          },
        ),
      ),
    );
  }
}
