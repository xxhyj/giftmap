import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// 선택 상태를 색상과 함께 아이콘·굵기로도 전달하는 칩.
class SelectableChip extends StatelessWidget {
  const SelectableChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.semanticsLabel,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = Theme.of(context).textTheme.labelMedium!.copyWith(
      color: selected ? Colors.white : AppColors.ink,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
    );

    return Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel ?? label,
      child: Material(
        color: selected ? AppColors.brandCoral : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.minTouchTarget,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (selected) ...<Widget>[
                  const Icon(Icons.check, size: 18, color: Colors.white),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Flexible(
                  child: Text(label, style: style, textAlign: TextAlign.center),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 조건 요약처럼 탭할 수 없는 칩. 버튼 semantics를 붙이지 않는다.
class ReadOnlyChip extends StatelessWidget {
  const ReadOnlyChip({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

/// 칩을 줄바꿈으로 배치해 텍스트 확대에서도 넘치지 않게 한다.
class ChipWrap extends StatelessWidget {
  const ChipWrap({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: children,
    );
  }
}
