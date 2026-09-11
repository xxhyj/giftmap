export 'app_radius.dart';

/// 8pt 기반 간격 토큰(4는 반 단계).
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 40;

  /// 화면 좌우 기본 여백.
  static const double screen = 16;

  /// 하단 내비게이션에 콘텐츠가 가리지 않도록 두는 리스트 하단 여백.
  static const double bottomAction = 96;

  /// 최소 터치 영역(dp).
  static const double minTouchTarget = 48;

  /// 주요 버튼 높이(dp).
  static const double primaryButtonHeight = 56;

  /// 넓은 화면에서 콘텐츠가 과도하게 늘어나지 않도록 제한하는 최대 폭.
  static const double maxContentWidth = 720;
}
