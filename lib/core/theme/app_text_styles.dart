import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 본문 최소 15sp, 캡션 13sp 기준의 타이포그래피.
abstract final class AppTextStyles {
  static const TextTheme textTheme = TextTheme(
    displaySmall: TextStyle(
      fontSize: 30,
      height: 1.3,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
    ),
    headlineMedium: TextStyle(
      fontSize: 26,
      height: 1.3,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
    ),
    headlineSmall: TextStyle(
      fontSize: 22,
      height: 1.35,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
    ),
    titleLarge: TextStyle(
      fontSize: 19,
      height: 1.4,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
    ),
    titleMedium: TextStyle(
      fontSize: 17,
      height: 1.4,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      height: 1.5,
      fontWeight: FontWeight.w400,
      color: AppColors.ink,
    ),
    bodyMedium: TextStyle(
      fontSize: 15,
      height: 1.5,
      fontWeight: FontWeight.w400,
      color: AppColors.inkMuted,
    ),
    labelLarge: TextStyle(
      fontSize: 16,
      height: 1.2,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    ),
    labelMedium: TextStyle(
      fontSize: 14,
      height: 1.3,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    ),
    labelSmall: TextStyle(
      fontSize: 13,
      height: 1.3,
      fontWeight: FontWeight.w500,
      color: AppColors.inkMuted,
    ),
  );
}
