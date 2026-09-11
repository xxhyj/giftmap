import 'package:flutter/material.dart';

/// Giftmap 브랜드 팔레트.
///
/// 코랄은 주요 CTA와 선택 상태에만 사용하고, 나머지 화면은 중립 surface로
/// 유지해 광고성 인상을 주지 않는다.
abstract final class AppColors {
  static const Color brandCoral = Color(0xFFF4635A);
  static const Color brandCoralDark = Color(0xFFC94840);
  static const Color ink = Color(0xFF1B1A1F);
  static const Color inkMuted = Color(0xFF5C5A66);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF5F4F7);
  static const Color outline = Color(0xFFDDDAE3);

  /// 위험도 표시는 색상만으로 전달하지 않고 라벨·아이콘과 함께 사용한다.
  static const Color riskSafe = Color(0xFF1F7A4D);
  static const Color riskCaution = Color(0xFF8A5A00);
  static const Color riskAvoid = Color(0xFF9B1C1C);
}
