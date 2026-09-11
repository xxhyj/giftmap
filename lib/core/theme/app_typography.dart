import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 타이포그래피 역할 토큰.
///
/// | 역할 | 스타일 |
/// |---|---|
/// | Hero | displaySmall |
/// | Screen title | headlineSmall |
/// | Section title | titleLarge |
/// | Product title | bodyMedium |
/// | Body | bodyLarge |
/// | Label | labelMedium |
/// | Caption | labelSmall |
/// | Price | titleMedium (가격 전용 강조) |
abstract final class AppTypography {
  static const TextTheme textTheme = TextTheme(
    // Hero
    displaySmall: TextStyle(
      fontSize: 26,
      height: 1.3,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
      color: AppColors.textPrimary,
    ),
    headlineMedium: TextStyle(
      fontSize: 24,
      height: 1.3,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
      color: AppColors.textPrimary,
    ),
    // Screen title
    headlineSmall: TextStyle(
      fontSize: 21,
      height: 1.35,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      color: AppColors.textPrimary,
    ),
    // Section title
    titleLarge: TextStyle(
      fontSize: 18,
      height: 1.35,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      color: AppColors.textPrimary,
    ),
    // Price / 강조 소제목
    titleMedium: TextStyle(
      fontSize: 16,
      height: 1.35,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    ),
    titleSmall: TextStyle(
      fontSize: 15,
      height: 1.4,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    // Body
    bodyLarge: TextStyle(
      fontSize: 15,
      height: 1.55,
      fontWeight: FontWeight.w400,
      color: AppColors.textPrimary,
    ),
    // Product title
    bodyMedium: TextStyle(
      fontSize: 15,
      height: 1.45,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
    ),
    bodySmall: TextStyle(
      fontSize: 14,
      height: 1.5,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary,
    ),
    labelLarge: TextStyle(
      fontSize: 16,
      height: 1.2,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    // Label
    labelMedium: TextStyle(
      fontSize: 14,
      height: 1.3,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    // Caption
    labelSmall: TextStyle(
      fontSize: 13,
      height: 1.35,
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondary,
    ),
  );
}
