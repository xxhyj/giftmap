import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// S01. 로컬 데이터를 준비하는 동안만 보이는 화면.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('📍', style: TextStyle(fontSize: 44)),
            const SizedBox(height: AppSpacing.md),
            Text('Giftmap', style: text.headlineMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '선물 고민의 방향을 찾다',
              style: text.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.brandCoral,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
