import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../app/app_scope.dart';
import '../../../core/analytics/analytics_event.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/rounded_surface.dart';
import '../../gift_finder/data/product_recommendation_engine.dart';
import '../../products/domain/product.dart';
import '../../products/presentation/product_detail_screen.dart';
import '../../products/presentation/widgets/product_collections.dart';
import '../domain/history_entry.dart';

/// 과거 추천 상세.
///
/// 추천 엔진이 결정론적이므로 저장된 조건으로 다시 계산하면 당시와 같은 상품이
/// 나온다. 상품 목록을 따로 저장하지 않고 조건만 보관한다.
class HistoryDetailScreen extends StatelessWidget {
  const HistoryDetailScreen({required this.entry, super.key});

  final HistoryEntry entry;

  Future<void> _reuse(BuildContext context) async {
    final AppDependencies deps = AppScope.of(context);
    deps.analytics.record(const HistoryReused());
    deps.finderController.startFromIntent(entry.intent);
    await Navigator.of(context).pushReplacement(AppRouter.analyzing());
  }

  Future<void> _delete(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('기록을 삭제할까요?'),
        content: const Text('삭제한 기록은 되돌릴 수 없어요.'),
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
    if (confirmed != true || !context.mounted) return;
    await AppScope.of(context).historyStore.remove(entry.id);
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final AppDependencies deps = AppScope.of(context);

    final List<ProductPick> picks = deps.productEngine.recommend(
      entry.intent,
      directions: entry.result.items,
      limit: 6,
    );

    return Scaffold(
      appBar: AppBar(title: Text(entry.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.md,
            AppSpacing.screen,
            AppSpacing.lg,
          ),
          children: <Widget>[
            Text(
              '${DateFormatKo.dotted(entry.createdAt)} · ${entry.intent.budgetLabel}',
              style: text.labelSmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('당시 추천', style: text.titleLarge),
            const SizedBox(height: AppSpacing.md),
            if (picks.isEmpty)
              const RoundedSurface(child: Text('표시할 상품이 없어요.'))
            else
              ProductGrid(
                products: picks
                    .map((ProductPick p) => p.product)
                    .toList(growable: false),
                badgeOf: (Product product) => picks
                    .firstWhere((ProductPick p) => p.product.id == product.id)
                    .badge,
                onOpen: (Product product) {
                  final ProductPick pick = picks.firstWhere(
                    (ProductPick p) => p.product.id == product.id,
                  );
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) => ProductDetailScreen(
                        product: pick.product,
                        recommendationReason: pick.reason,
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: AppSpacing.lg),
            NoticeBlock(text: deps.productDisclaimer),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () => _reuse(context),
              child: const Text('이 조건으로 다시 추천'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () => _delete(context),
              child: const Text('기록 삭제'),
            ),
          ],
        ),
      ),
    );
  }
}
