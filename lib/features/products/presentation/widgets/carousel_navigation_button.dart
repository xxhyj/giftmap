import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// 캐러셀 이전/다음 이동 버튼.
///
/// 최소 48dp 터치 영역을 가지며, 더 이동할 수 없으면 비활성화된다.
/// 비활성 상태는 색상만이 아니라 semantics(enabled=false)로도 전달한다.
class CarouselNavigationButton extends StatelessWidget {
  const CarouselNavigationButton({
    required this.direction,
    required this.onPressed,
    super.key,
  });

  const CarouselNavigationButton.previous({
    required VoidCallback? onPressed,
    Key? key,
  }) : this(direction: AxisDirection.left, onPressed: onPressed, key: key);

  const CarouselNavigationButton.next({
    required VoidCallback? onPressed,
    Key? key,
  }) : this(direction: AxisDirection.right, onPressed: onPressed, key: key);

  final AxisDirection direction;

  /// null이면 비활성 상태로 렌더링한다.
  final VoidCallback? onPressed;

  bool get _isPrevious => direction == AxisDirection.left;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    final String label = _isPrevious ? '이전 상품 보기' : '다음 상품 보기';
    // 화면 방향(RTL)을 따라 아이콘이 뒤집히도록 방향성 아이콘을 쓴다.
    final IconData icon = _isPrevious
        ? Icons.arrow_back_ios_new
        : Icons.arrow_forward_ios;

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: SizedBox(
        width: AppSpacing.minTouchTarget,
        height: AppSpacing.minTouchTarget,
        child: Material(
          color: enabled ? AppColors.surface : AppColors.surfaceVariant,
          shape: CircleBorder(
            side: BorderSide(
              color: enabled ? AppColors.outlineStrong : AppColors.outline,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Center(
              child: Icon(
                icon,
                size: 15,
                color: enabled ? AppColors.textPrimary : AppColors.textTertiary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
