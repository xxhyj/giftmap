import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/affiliate/affiliate_link_policy.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/rounded_surface.dart';
import '../../../core/widgets/section_header.dart';

/// S14. 설정과 법적 고지.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _clearAll() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('데이터를 모두 삭제할까요?'),
        content: const Text('추천 기록과 기념일이 모두 지워지고 되돌릴 수 없어요.'),
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
    await AppScope.of(context).clearAllLocalData();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('로컬 데이터를 모두 삭제했어요')));
  }

  Future<void> _showContact() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('문의'),
        content: const Text(
          '지금은 앱 안에서 문의를 보내지 않아요. '
          '문의 채널은 출시 준비 단계에서 연결할 예정이에요.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppDependencies deps = AppScope.of(context);
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.md,
            AppSpacing.screen,
            AppSpacing.lg,
          ),
          children: <Widget>[
            const SectionHeader(title: '앱 정보'),
            RoundedSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Giftmap MVP', style: text.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '추천 규칙 버전 ${deps.ruleset.version}',
                    style: text.labelSmall,
                  ),
                  if (deps.usingSafeDefaults) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '번들 데이터를 읽지 못해 기본 카테고리로 동작 중이에요.',
                      style: text.labelSmall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(
              title: '분석 데이터',
              subtitle: '동의하기 전에는 아무 것도 기록하지 않아요',
            ),
            RoundedSurface(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: deps.analytics.consentGranted,
                title: const Text('익명 사용 통계 보내기'),
                subtitle: const Text('검색어 원문은 수집하지 않아요'),
                onChanged: (bool value) => setState(() {
                  deps.analytics.consentGranted = value;
                  if (!value) deps.analytics.clear();
                }),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(title: '개인정보와 고지'),
            const RoundedSurface(
              child: Text(
                '추천 기록·기념일은 이 기기에만 저장되며 서버로 전송하지 않아요. '
                '로그인 없이 사용하고, 광고 식별자나 연락처와 결합하지 않아요.',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const RoundedSurface(
              child: Text(AffiliateLinkPolicy.disclosureText),
            ),
            const SizedBox(height: AppSpacing.sm),
            RoundedSurface(child: Text(deps.priceDisclaimer)),
            const SizedBox(height: AppSpacing.sm),
            const NoticeBlock(
              text: '개인정보 처리방침·제휴 약관·오픈소스 라이선스 원문은 출시 전 실제 문서로 연결합니다.',
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () =>
                  showLicensePage(context: context, applicationName: 'Giftmap'),
              child: const Text('오픈소스 라이선스'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(onPressed: _showContact, child: const Text('문의')),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(title: '데이터 관리'),
            OutlinedButton(
              onPressed: _clearAll,
              child: const Text('데이터 전체 삭제'),
            ),
          ],
        ),
      ),
    );
  }
}
