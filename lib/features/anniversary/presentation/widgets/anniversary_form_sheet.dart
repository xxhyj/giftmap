import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/selectable_chip.dart';
import '../../../gift_finder/domain/gift_intent.dart';
import '../../domain/anniversary.dart';

/// 기념일 추가 입력 시트. 이름·관계·상황·날짜만 받는다.
class AnniversaryFormSheet extends StatefulWidget {
  const AnniversaryFormSheet({super.key});

  static Future<Anniversary?> show(BuildContext context) {
    return showModalBottomSheet<Anniversary>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) => const AnniversaryFormSheet(),
    );
  }

  @override
  State<AnniversaryFormSheet> createState() => _AnniversaryFormSheetState();
}

class _AnniversaryFormSheetState extends State<AnniversaryFormSheet> {
  final TextEditingController _nameController = TextEditingController();
  RelationshipType _relationship = RelationshipType.friend;
  GiftSituation _situation = GiftSituation.birthday;
  DateTime? _date;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _submit() {
    final String name = _nameController.text.trim();
    final DateTime? date = _date;
    if (name.isEmpty || date == null) return;
    Navigator.of(context).pop(
      Anniversary(
        id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
        displayName: name,
        relationship: _relationship,
        situation: _situation,
        date: date,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool ready = _nameController.text.trim().isNotEmpty && _date != null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: <Widget>[
          Text('기념일 추가', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _nameController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: '이름',
              hintText: '예: 민지',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: '관계'),
          ChipWrap(
            children: RelationshipType.values
                .map(
                  (RelationshipType value) => SelectableChip(
                    label: value.label,
                    selected: _relationship == value,
                    onTap: () => setState(() => _relationship = value),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: '기념일 종류'),
          ChipWrap(
            children: GiftSituation.values
                .map(
                  (GiftSituation value) => SelectableChip(
                    label: value.label,
                    selected: _situation == value,
                    onTap: () => setState(() => _situation = value),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(
              _date == null
                  ? '날짜 선택'
                  : '${_date!.year}년 ${_date!.month}월 ${_date!.day}일',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: ready ? _submit : null,
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}
