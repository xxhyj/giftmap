import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// 홈 상단의 핵심 가치 전달 영역.
///
/// 검색 진입과 선물 찾기 CTA를 한 화면에서 바로 누를 수 있게 둔다.
class HomeHero extends StatelessWidget {
  const HomeHero({
    required this.onSearchTap,
    required this.onStartTap,
    super.key,
  });

  final VoidCallback onSearchTap;
  final VoidCallback onStartTap;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('어떤 선물을 찾고 있나요?', style: text.displaySmall),
          const SizedBox(height: AppSpacing.sm),
          Text('상황과 예산만 알려주면 어울리는 선물을 골라드려요.', style: text.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
          // 실제 입력은 검색 화면에서 받는다. 홈에서는 진입만 담당한다.
          InkWell(
            onTap: onSearchTap,
            borderRadius: BorderRadius.circular(AppRadius.button),
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.search, color: AppColors.inkMuted),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '브랜드, 상품, 카테고리 검색',
                      style: text.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: onStartTap,
            icon: const Icon(Icons.auto_awesome_outlined, size: 20),
            label: const Text('선물 찾기 시작하기'),
          ),
        ],
      ),
    );
  }
}
