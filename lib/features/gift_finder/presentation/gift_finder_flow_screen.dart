import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../app/app_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/responsive_body.dart';
import '../application/gift_finder_controller.dart';
import 'widgets/avoid_step.dart';
import 'widgets/budget_step.dart';
import 'widgets/preference_step.dart';
import 'widgets/recipient_step.dart';
import 'widgets/situation_step.dart';

/// 선물 찾기 위저드(5단계).
///
/// 진행 중 세션은 탭을 바꿔도 controller에 그대로 남는다.
class GiftFinderFlowScreen extends StatefulWidget {
  const GiftFinderFlowScreen({super.key});

  @override
  State<GiftFinderFlowScreen> createState() => _GiftFinderFlowScreenState();
}

class _GiftFinderFlowScreenState extends State<GiftFinderFlowScreen> {
  bool _started = false;

  static const List<String> _titles = <String>[
    '어떤 상황인가요?',
    '누구에게 주나요?',
    '예산은 얼마인가요?',
    '어떤 느낌의 선물을 원하나요?',
    '피하고 싶은 것이 있나요?',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final GiftFinderController controller = AppScope.of(context)
        .finderController;
    if (controller.sessionId.isEmpty) {
      controller.startSession(entryPoint: 'finder_tab');
    }
  }

  bool _isStepComplete(GiftFinderController c) {
    return switch (c.step) {
      0 => c.situation != null,
      1 => c.relationship != null,
      2 => c.budget != null && c.isBudgetValid,
      _ => true,
    };
  }

  Future<void> _onNext(GiftFinderController controller) async {
    if (controller.step < GiftFinderController.totalSteps - 1) {
      controller.goToStep(controller.step + 1);
      return;
    }
    if (!controller.canSubmit) return;
    await Navigator.of(context).push(AppRouter.analyzing());
  }

  @override
  Widget build(BuildContext context) {
    final GiftFinderController controller = AppScope.of(context)
        .finderController;

    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) {
        final bool isLast =
            controller.step == GiftFinderController.totalSteps - 1;
        final bool enabled = _isStepComplete(controller);
        final TextTheme text = Theme.of(context).textTheme;

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leading: controller.step == 0
                ? null
                : IconButton(
                    onPressed: () => controller.goToStep(controller.step - 1),
                    icon: const Icon(Icons.arrow_back),
                    tooltip: '이전 단계',
                  ),
            title: Text(
              '0${controller.step + 1} / 0${GiftFinderController.totalSteps}',
              style: text.labelMedium?.copyWith(color: AppColors.inkMuted),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(3),
              child: LinearProgressIndicator(
                value: controller.progress,
                minHeight: 3,
                backgroundColor: AppColors.surfaceMuted,
                color: AppColors.brandCoral,
              ),
            ),
          ),
          body: SafeArea(
            child: ResponsiveBody(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  AppSpacing.md,
                  AppSpacing.screen,
                  AppSpacing.lg,
                ),
                children: <Widget>[
                  Text(_titles[controller.step], style: text.headlineSmall),
                  const SizedBox(height: AppSpacing.lg),
                  switch (controller.step) {
                    0 => SituationStep(controller: controller),
                    1 => RecipientStep(controller: controller),
                    2 => BudgetStep(controller: controller),
                    3 => PreferenceStep(controller: controller),
                    _ => AvoidStep(controller: controller),
                  },
                ],
              ),
            ),
          ),
          bottomNavigationBar: BottomActionBar(
            label: isLast ? '추천 상품 보기' : '다음',
            helper: enabled ? null : '이 단계의 조건을 먼저 골라주세요',
            onPressed: enabled ? () => _onNext(controller) : null,
          ),
        );
      },
    );
  }
}
