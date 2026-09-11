import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../app/app_shell.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/rounded_surface.dart';
import '../application/anniversary_store.dart';
import '../domain/anniversary.dart';
import 'widgets/anniversary_form_sheet.dart';

/// S13. 기념일 로컬 관리. MVP에서는 알림을 보내지 않는다.
class AnniversaryScreen extends StatefulWidget {
  const AnniversaryScreen({super.key});

  @override
  State<AnniversaryScreen> createState() => _AnniversaryScreenState();
}

class _AnniversaryScreenState extends State<AnniversaryScreen> {
  bool _refreshed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_refreshed) return;
    _refreshed = true;
    AppScope.of(context).anniversaryStore.refresh();
  }

  Future<void> _add() async {
    final Anniversary? created = await AnniversaryFormSheet.show(context);
    if (created == null || !mounted) return;
    await AppScope.of(context).anniversaryStore.add(created);
  }

  Future<void> _remove(Anniversary anniversary) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text('${anniversary.displayName} 기념일을 삭제할까요?'),
        content: const Text('삭제한 기념일은 되돌릴 수 없어요.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await AppScope.of(context).anniversaryStore.remove(anniversary.id);
  }

  Future<void> _startGift(Anniversary anniversary) async {
    final AppDependencies deps = AppScope.of(context);
    deps.finderController.startSession(entryPoint: 'anniversary');
    deps.finderController
      ..selectSituation(anniversary.situation)
      ..selectRelationship(anniversary.relationship)
      ..goToStep(2);
    deps.shellTab.goTo(ShellTabController.finderTab);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AnniversaryStore store = AppScope.of(context).anniversaryStore;
    final DateTime now = DateTime.now();
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('기념일'),
        actions: <Widget>[
          IconButton(
            onPressed: _add,
            icon: const Icon(Icons.add),
            tooltip: '기념일 추가',
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (BuildContext context, _) {
            if (store.isEmpty) {
              return EmptyStateView(
                icon: Icons.event_outlined,
                title: '등록된 기념일이 없어요',
                message: '이름·관계·날짜만 기기에 저장해요. 알림은 아직 보내지 않아요.',
                actionLabel: '기념일 추가',
                onAction: _add,
              );
            }
            final List<Anniversary> items = store.sorted(now);
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.md,
                AppSpacing.screen,
                AppSpacing.lg,
              ),
              children: <Widget>[
                for (final Anniversary item in items) ...<Widget>[
                  RoundedSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Text(
                              item.dDayLabel(now),
                              style: text.labelMedium?.copyWith(
                                color: AppColors.brandCoralDark,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                '${item.displayName} · ${item.relationship.label}',
                                style: text.titleMedium,
                              ),
                            ),
                            IconButton(
                              onPressed: () => _remove(item),
                              icon: const Icon(Icons.delete_outline),
                              tooltip: '삭제',
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '${item.situation.label} · ${item.date.month}월 ${item.date.day}일',
                          style: text.labelSmall,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        OutlinedButton(
                          onPressed: () => _startGift(item),
                          child: const Text('선물 추천받기'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                const SizedBox(height: AppSpacing.md),
                const NoticeBlock(
                  text: '기념일은 이 기기에만 저장되며 서버로 전송하지 않아요. 알림 기능은 다음 단계에서 추가돼요.',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
