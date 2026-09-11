import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// 넓은 화면에서 콘텐츠가 과도하게 늘어나지 않도록 최대 폭을 제한한다.
///
/// 모바일에서는 아무 영향이 없고, 태블릿·데스크톱 창에서만 가운데 정렬된다.
class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({
    required this.child,
    this.maxWidth = AppSpacing.maxContentWidth,
    super.key,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
