import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Material 3 테마.
///
/// 카드 중첩·그라디언트·짙은 그림자를 쓰지 않고, 테두리와 tonal surface로
/// 구분한다. 포인트 컬러는 주요 행동과 선택 상태에만 나타난다.
abstract final class AppTheme {
  static ThemeData light() {
    final ColorScheme scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: AppColors.onPrimary,
          primaryContainer: AppColors.primaryContainer,
          onPrimaryContainer: AppColors.onPrimaryContainer,
          secondary: AppColors.accent,
          onSecondary: AppColors.onAccent,
          secondaryContainer: AppColors.accentContainer,
          onSecondaryContainer: AppColors.onAccentContainer,
          tertiary: AppColors.accent,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
          onSurfaceVariant: AppColors.textSecondary,
          surfaceContainerLowest: AppColors.surface,
          surfaceContainerLow: AppColors.background,
          surfaceContainer: AppColors.surfaceVariant,
          surfaceContainerHighest: AppColors.surfaceVariant,
          outline: AppColors.outlineStrong,
          outlineVariant: AppColors.outline,
          error: AppColors.error,
          onError: AppColors.onError,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: AppTypography.textTheme,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: AppColors.textPrimary,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSpacing.primaryButtonHeight),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: AppColors.surfaceVariant,
          disabledForegroundColor: AppColors.textTertiary,
          textStyle: AppTypography.textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(
            AppSpacing.minTouchTarget,
            AppSpacing.minTouchTarget,
          ),
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.outlineStrong),
          textStyle: AppTypography.textTheme.labelMedium,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(
            AppSpacing.minTouchTarget,
            AppSpacing.minTouchTarget,
          ),
          foregroundColor: AppColors.primary,
          textStyle: AppTypography.textTheme.labelMedium,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.textSecondary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        hintStyle: AppTypography.textTheme.bodyMedium?.copyWith(
          color: AppColors.textTertiary,
          fontWeight: FontWeight.w400,
        ),
        border: _inputBorder(AppColors.outline),
        enabledBorder: _inputBorder(AppColors.outline),
        focusedBorder: _inputBorder(AppColors.primary, width: 1.6),
        errorBorder: _inputBorder(AppColors.error, width: 1.4),
        focusedErrorBorder: _inputBorder(AppColors.error, width: 1.6),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primaryContainer,
        elevation: 0,
        height: 66,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((
          Set<WidgetState> states,
        ) {
          final bool selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? AppColors.primary : AppColors.textTertiary,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((
          Set<WidgetState> states,
        ) {
          final bool selected = states.contains(WidgetState.selected);
          // 선택 상태를 색상만이 아니라 굵기로도 전달한다.
          return TextStyle(
            fontSize: 11.5,
            height: 1.2,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          );
        }),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textSecondary,
          selectedBackgroundColor: AppColors.primaryContainer,
          selectedForegroundColor: AppColors.onPrimaryContainer,
          side: const BorderSide(color: AppColors.outline),
          textStyle: AppTypography.textTheme.labelMedium,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariant,
        side: BorderSide.none,
        labelStyle: AppTypography.textTheme.labelMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.primary,
        thumbColor: AppColors.primary,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: AppTypography.textTheme.bodyMedium?.copyWith(
          color: AppColors.surface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.outline,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.surfaceVariant,
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.button),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
