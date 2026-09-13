import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// 실제 상품을 불러오지 못했을 때 보여주는 화면.
///
/// 실제 상품 모드에서는 데모 상품으로 조용히 대체하지 않는다.
/// 무엇이 잘못됐는지 알리고 다시 시도할 수 있게 한다.
class LoadFailureScreen extends StatelessWidget {
  const LoadFailureScreen({required this.onRetry, this.detail, super.key});

  /// 다시 시도 버튼을 눌렀을 때.
  final VoidCallback onRetry;

  /// 개발 중 원인을 확인하기 위한 설명. 사용자에게는 짧게만 보여준다.
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.cloud_off_outlined,
                  size: 48,
                  color: AppColors.ink,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '상품을 불러오지 못했어요',
                  style: text.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '네트워크 상태를 확인한 뒤 다시 시도해 주세요.',
                  style: text.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                if (detail != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    detail!,
                    style: text.labelSmall,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: onRetry,
                    child: const Text('다시 시도'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
