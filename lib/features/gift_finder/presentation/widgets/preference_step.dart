import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../application/gift_finder_controller.dart';
import 'selection_tile.dart';

/// 4단계. 실용 ↔ 감성 성향 선택.
class PreferenceStep extends StatelessWidget {
  const PreferenceStep({required this.controller, super.key});

  final GiftFinderController controller;

  static const List<(double, String, String, IconData)> _options =
      <(double, String, String, IconData)>[
        (0.15, '실용적인 쪽', '매일 쓰는 물건 위주로 볼게요', Icons.check_circle_outline),
        (0.5, '반반이에요', '실용성과 분위기를 함께 볼게요', Icons.balance_outlined),
        (0.85, '감성적인 쪽', '분위기와 기분이 남는 선물 위주로 볼게요', Icons.auto_awesome_outlined),
      ];

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Column(
          children: _options
              .map(
                ((double, String, String, IconData) option) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: SelectionTile(
                    label: option.$2,
                    description: option.$3,
                    icon: option.$4,
                    selected: (controller.preference - option.$1).abs() < 0.12,
                    onTap: () => controller.setPreference(option.$1),
                  ),
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('더 세밀하게 조절하기', style: text.labelMedium),
        Row(
          children: <Widget>[
            Text('실용', style: text.labelSmall),
            Expanded(
              child: Slider(
                value: controller.preference,
                divisions: 10,
                activeColor: AppColors.brandCoral,
                label: controller.preference <= 0.35
                    ? '실용 쪽'
                    : (controller.preference >= 0.65 ? '감성 쪽' : '균형'),
                onChanged: controller.setPreference,
              ),
            ),
            Text('감성', style: text.labelSmall),
          ],
        ),
      ],
    );
  }
}
