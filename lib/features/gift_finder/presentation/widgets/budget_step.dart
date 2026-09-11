import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/selectable_chip.dart';
import '../../application/gift_finder_controller.dart';
import '../../domain/gift_intent.dart';

/// S06. 예산 선택. 직접 입력은 KRW 정수만 받는다.
class BudgetStep extends StatefulWidget {
  const BudgetStep({required this.controller, super.key});

  final GiftFinderController controller;

  @override
  State<BudgetStep> createState() => _BudgetStepState();
}

class _BudgetStepState extends State<BudgetStep> {
  late final TextEditingController _amountController = TextEditingController(
    text: widget.controller.customBudget?.toString() ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _onAmountChanged(String raw) {
    final int? value = int.tryParse(raw.trim());
    setState(() {
      _error = widget.controller.setCustomBudget(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final GiftFinderController controller = widget.controller;
    final bool custom = controller.budget == BudgetBand.custom;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '부담 없는 예산을 골라주세요',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        ChipWrap(
          children: BudgetBand.values
              .map(
                (BudgetBand value) => SelectableChip(
                  label: value.label,
                  selected: controller.budget == value,
                  onTap: () {
                    if (value == BudgetBand.custom) {
                      _onAmountChanged(_amountController.text);
                    } else {
                      setState(() => _error = null);
                      controller.selectBudget(value);
                    }
                  },
                ),
              )
              .toList(growable: false),
        ),
        if (custom) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            onChanged: _onAmountChanged,
            decoration: InputDecoration(
              labelText: '예산(원)',
              hintText: '예: 45000',
              errorText: _error,
              helperText: '1,000원 ~ 10,000,000원',
            ),
          ),
        ],
      ],
    );
  }
}
