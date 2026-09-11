import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../app/app_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../application/gift_finder_controller.dart';

/// S08. 추천 계산과 폴백을 관리하는 대기 화면.
class AnalyzingScreen extends StatefulWidget {
  const AnalyzingScreen({super.key});

  @override
  State<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends State<AnalyzingScreen> {
  static const List<String> _steps = <String>[
    '관계와 상황 확인',
    '예산에 맞는 상품 비교',
    '부담 요소 점검',
  ];

  Timer? _ticker;
  int _visibleStep = 0;
  bool _navigated = false;
  GiftFinderController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final GiftFinderController controller = AppScope.of(context)
        .finderController;
    _controller = controller..addListener(_onControllerChanged);
    _startTicker();
    // build 중 상태 변경을 피하기 위해 첫 프레임 이후에 실행한다.
    // 중복 실행은 controller가 막는다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) controller.submit();
    });
  }

  void _startTicker() {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _visibleStep = _steps.length - 1;
      return;
    }
    _ticker = Timer.periodic(const Duration(milliseconds: 600), (Timer timer) {
      if (!mounted) return;
      setState(() {
        _visibleStep = (_visibleStep + 1).clamp(0, _steps.length - 1);
      });
      if (_visibleStep == _steps.length - 1) timer.cancel();
    });
  }

  void _onControllerChanged() {
    final GiftFinderController? controller = _controller;
    if (controller == null || !mounted) return;
    if (controller.status != FinderStatus.ready || _navigated) {
      setState(() {});
      return;
    }
    _navigated = true;
    Navigator.of(context).pushReplacement(AppRouter.result());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _controller?.removeListener(_onControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final GiftFinderController controller = AppScope.of(context)
        .finderController;
    final TextTheme text = Theme.of(context).textTheme;

    if (controller.status == FinderStatus.failed) {
      return Scaffold(
        appBar: AppBar(title: const Text('추천 실패')),
        body: EmptyStateView(
          icon: Icons.error_outline,
          title: '추천을 만들지 못했어요',
          message: controller.failure?.message ?? '조건을 조금 바꿔서 다시 시도해 주세요.',
          actionLabel: '조건으로 돌아가기',
          onAction: () => Navigator.of(context).pop(),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('선물을 고르는 중이에요', style: text.headlineSmall),
              const SizedBox(height: AppSpacing.lg),
              for (int i = 0; i < _steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        i < _visibleStep
                            ? Icons.check_circle
                            : i == _visibleStep
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 20,
                        color: i <= _visibleStep
                            ? AppColors.brandCoral
                            : AppColors.outline,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: Text(_steps[i], style: text.bodyLarge)),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              Text('기기 안에서 바로 계산하고 있어요. 잠시만 기다려 주세요.', style: text.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}
