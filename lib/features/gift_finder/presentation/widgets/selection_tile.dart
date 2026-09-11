import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// 아이콘과 라벨을 함께 보여주는 선택 타일.
///
/// 텍스트만 나열하지 않고 선택 상태를 테두리·배경·아이콘으로 함께 전달한다.
class SelectionTile extends StatelessWidget {
  const SelectionTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.description,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected
            ? AppColors.brandCoral.withValues(alpha: 0.08)
            : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(
            color: selected ? AppColors.brandCoral : AppColors.outline,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  icon,
                  size: 22,
                  color: selected
                      ? AppColors.brandCoralDark
                      : AppColors.inkMuted,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        label,
                        style: text.bodyLarge?.copyWith(
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: AppColors.ink,
                        ),
                      ),
                      if (description != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(description!, style: text.labelSmall),
                      ],
                    ],
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle,
                    size: 20,
                    color: AppColors.brandCoral,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 선택 타일을 2열로 배치한다. 좁은 화면에서는 1열로 떨어진다.
class SelectionTileGrid extends StatelessWidget {
  const SelectionTileGrid({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double scale = MediaQuery.textScalerOf(context).scale(15) / 15;
        final bool twoColumns = constraints.maxWidth >= 340 && scale < 1.25;
        final double width = twoColumns
            ? (constraints.maxWidth - AppSpacing.sm) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: children
              .map((Widget child) => SizedBox(width: width, child: child))
              .toList(growable: false),
        );
      },
    );
  }
}
