import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// 의미 단위를 구분하는 최소한의 rounded surface.
/// 그림자·그라디언트를 쓰지 않고 배경과 얇은 테두리로만 구분한다.
class RoundedSurface extends StatelessWidget {
  const RoundedSurface({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.color = AppColors.surface,
    this.bordered = true,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final bool bordered;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(AppRadius.card);
    final Widget content = Padding(padding: padding, child: child);

    // Material은 borderRadius와 shape를 동시에 받지 않으므로 shape 하나로 표현한다.
    return Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: bordered
            ? const BorderSide(color: AppColors.outline)
            : BorderSide.none,
      ),
      child: onTap == null
          ? content
          : InkWell(onTap: onTap, borderRadius: radius, child: content),
    );
  }
}

/// 고지·안내 문구 블록.
class NoticeBlock extends StatelessWidget {
  const NoticeBlock({
    required this.text,
    this.icon = Icons.info_outline,
    super.key,
  });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: AppColors.inkMuted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.labelSmall),
          ),
        ],
      ),
    );
  }
}
