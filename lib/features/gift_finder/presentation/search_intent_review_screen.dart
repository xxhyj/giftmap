import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../app/app_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/rounded_surface.dart';
import '../../../core/widgets/selectable_chip.dart';
import '../application/gift_finder_controller.dart';
import '../data/local_intent_parser.dart';
import '../domain/gift_intent.dart';

/// S03. 자연어 입력에서 뽑은 조건을 확인한다.
///
/// 신뢰도 0.7 미만 필드만 사용자 확인을 요구하고, 사용자의 수정값이 항상 우선한다.
class SearchIntentReviewScreen extends StatefulWidget {
  const SearchIntentReviewScreen({required this.parsed, super.key});

  final ParsedIntent parsed;

  @override
  State<SearchIntentReviewScreen> createState() =>
      _SearchIntentReviewScreenState();
}

class _SearchIntentReviewScreenState extends State<SearchIntentReviewScreen> {
  GiftSituation? _situation;
  RelationshipType? _relationship;
  AgeBand _ageBand = AgeBand.unspecified;
  BudgetBand? _budget;
  double? _preference;

  @override
  void initState() {
    super.initState();
    final ParsedIntent parsed = widget.parsed;
    if (parsed.situation.isConfident) _situation = parsed.situation.value;
    if (parsed.relationship.isConfident) {
      _relationship = parsed.relationship.value;
    }
    if (parsed.ageBand.isConfident) _ageBand = parsed.ageBand.value;
    if (parsed.budget.isConfident) _budget = parsed.budget.value;
    if (parsed.preference.isConfident) _preference = parsed.preference.value;
  }

  bool get _isReady =>
      _situation != null && _relationship != null && _budget != null;

  Future<void> _pick<T>({
    required String title,
    required List<T> options,
    required String Function(T value) labelOf,
    required T? current,
    required ValueChanged<T> onSelected,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              ChipWrap(
                children: options
                    .map(
                      (T option) => SelectableChip(
                        label: labelOf(option),
                        selected: option == current,
                        onTap: () {
                          onSelected(option);
                          Navigator.of(sheetContext).pop();
                        },
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final AppDependencies deps = AppScope.of(context);
    final GiftFinderController controller = deps.finderController;
    controller.startFromParsed(widget.parsed);
    controller.selectSituation(_situation!);
    controller.selectRelationship(_relationship!);
    if (_ageBand != AgeBand.unspecified && controller.ageBand != _ageBand) {
      controller.selectAgeBand(_ageBand);
    }
    controller.selectBudget(_budget!);
    if (_budget == BudgetBand.custom) {
      controller.setCustomBudget(widget.parsed.customBudget);
    }
    controller.setPreference(_preference ?? 0.5);
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(AppRouter.analyzing());
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('조건 확인')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.md,
            AppSpacing.screen,
            AppSpacing.lg,
          ),
          children: <Widget>[
            RoundedSurface(
              color: AppColors.surfaceMuted,
              bordered: false,
              child: Text('“${widget.parsed.rawQuery}”', style: text.bodyLarge),
            ),
            const SizedBox(height: AppSpacing.lg),
            _FieldRow(
              label: '상황',
              value: _situation?.label,
              onTap: () => _pick<GiftSituation>(
                title: '어떤 순간인가요?',
                options: GiftSituation.values,
                labelOf: (GiftSituation v) => v.label,
                current: _situation,
                onSelected: (GiftSituation v) => setState(() => _situation = v),
              ),
            ),
            _FieldRow(
              label: '관계',
              value: _relationship?.label,
              onTap: () => _pick<RelationshipType>(
                title: '누구에게 주나요?',
                options: RelationshipType.values,
                labelOf: (RelationshipType v) => v.label,
                current: _relationship,
                onSelected: (RelationshipType v) =>
                    setState(() => _relationship = v),
              ),
            ),
            _FieldRow(
              label: '연령',
              value: _ageBand == AgeBand.unspecified ? null : _ageBand.label,
              optional: true,
              onTap: () => _pick<AgeBand>(
                title: '연령대(선택)',
                options: AgeBand.values,
                labelOf: (AgeBand v) => v.label,
                current: _ageBand,
                onSelected: (AgeBand v) => setState(() => _ageBand = v),
              ),
            ),
            _FieldRow(
              label: '예산',
              value: _budget?.label,
              onTap: () => _pick<BudgetBand>(
                title: '예산은 어느 정도인가요?',
                options: BudgetBand.values
                    .where((BudgetBand b) => b != BudgetBand.custom)
                    .toList(growable: false),
                labelOf: (BudgetBand v) => v.label,
                current: _budget,
                onSelected: (BudgetBand v) => setState(() => _budget = v),
              ),
            ),
            _FieldRow(
              label: '취향',
              value: _preference == null
                  ? null
                  : (_preference! <= 0.35
                        ? '실용적'
                        : _preference! >= 0.65
                        ? '감성적'
                        : '균형'),
              optional: true,
              onTap: () => _pick<double>(
                title: '어떤 느낌에 더 가까울까요?',
                options: const <double>[0.2, 0.5, 0.8],
                labelOf: (double v) =>
                    v <= 0.35 ? '실용적' : (v >= 0.65 ? '감성적' : '균형'),
                current: _preference,
                onSelected: (double v) => setState(() => _preference = v),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('확인이 필요한 항목만 한 번 더 물어볼게요.', style: text.labelSmall),
          ],
        ),
      ),
      bottomNavigationBar: BottomActionBar(
        label: '이 조건으로 추천받기',
        helper: _isReady ? null : '상황·관계·예산을 확인해 주세요',
        onPressed: _isReady ? _submit : null,
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.optional = false,
  });

  final String label;
  final String? value;
  final VoidCallback onTap;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool confirmed = value != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: RoundedSurface(
        onTap: onTap,
        child: Row(
          children: <Widget>[
            SizedBox(width: 64, child: Text(label, style: text.labelMedium)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                confirmed ? value! : (optional ? '선택 안 함' : '확인이 필요해요'),
                style: text.bodyLarge?.copyWith(
                  color: confirmed || optional
                      ? AppColors.ink
                      : AppColors.riskCaution,
                ),
              ),
            ),
            Icon(
              confirmed
                  ? Icons.check_circle_outline
                  : (optional ? Icons.add : Icons.help_outline),
              size: 20,
              color: confirmed ? AppColors.riskSafe : AppColors.inkMuted,
            ),
          ],
        ),
      ),
    );
  }
}
