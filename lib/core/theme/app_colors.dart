import 'package:flutter/material.dart';

/// Giftmap 색상 토큰.
///
/// 방향: 차분하고 전문적인 톤 위에 선물 서비스다운 따뜻함을 얹는다.
/// - primary(딥 그린)는 신뢰와 안정감을 담당하고 주요 행동에만 쓴다.
/// - accent(웜 클레이)는 선물 포장의 온기를 담당하는 절제된 포인트다.
/// - 배경은 상품 이미지와 경쟁하지 않도록 따뜻한 오프화이트를 쓴다.
/// - 빨강은 error/destructive 상태에만 사용한다.
abstract final class AppColors {
  // Primary — 딥 그린
  static const Color primary = Color(0xFF2E5D4B);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFDCE8E1);
  static const Color onPrimaryContainer = Color(0xFF16352A);

  // Accent — 웜 클레이 (포인트)
  static const Color accent = Color(0xFFC0714F);
  static const Color onAccent = Color(0xFFFFFFFF);
  static const Color accentContainer = Color(0xFFF7E7DE);
  static const Color onAccentContainer = Color(0xFF6B3721);

  // Surface / background
  static const Color background = Color(0xFFFBF9F6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF3F0EB);
  static const Color surfaceMuted = Color(0xFFF3F0EB);

  // Text
  static const Color textPrimary = Color(0xFF1E2422);
  static const Color textSecondary = Color(0xFF5F6B66);
  static const Color textTertiary = Color(0xFF8A938F);

  // Line
  static const Color outline = Color(0xFFE3DED6);
  static const Color outlineStrong = Color(0xFFCFC8BE);

  // Status — 빨강은 오직 error에만 쓴다.
  static const Color error = Color(0xFFB3261E);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color success = Color(0xFF2F6D4F);
  static const Color warning = Color(0xFF8A5A00);

  /// 선물 위험도 표기. 색만으로 의미를 전달하지 않고 라벨·아이콘과 함께 쓴다.
  static const Color riskSafe = success;
  static const Color riskCaution = warning;
  static const Color riskAvoid = error;

  /// 이전 디자인과의 호환을 위해 남겨 둔 별칭.
  /// 신규 코드는 [primary] / [accent] / [textPrimary]를 직접 쓴다.
  static const Color ink = textPrimary;
  static const Color inkMuted = textSecondary;
  static const Color brandCoral = accent;
  static const Color brandCoralDark = onAccentContainer;
}
