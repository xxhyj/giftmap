import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../gift_finder/domain/gift_intent.dart';

/// 상황·관계로 바로 들어가는 빠른 진입 타일.
///
/// 텍스트만 나열하지 않고 아이콘 타일로 보여준다.
class OccasionQuickRow extends StatelessWidget {
  const OccasionQuickRow({
    required this.onSituation,
    required this.onRelationship,
    super.key,
  });

  final void Function(GiftSituation situation) onSituation;
  final void Function(RelationshipType relationship) onRelationship;

  static const List<(GiftSituation, IconData)> _situations =
      <(GiftSituation, IconData)>[
        (GiftSituation.birthday, Icons.cake_outlined),
        (GiftSituation.anniversary, Icons.favorite_border),
        (GiftSituation.housewarming, Icons.home_outlined),
        (GiftSituation.thanks, Icons.volunteer_activism_outlined),
        (GiftSituation.promotion, Icons.trending_up),
      ];

  static const List<(RelationshipType, IconData)> _relationships =
      <(RelationshipType, IconData)>[
        (RelationshipType.friend, Icons.people_alt_outlined),
        (RelationshipType.partner, Icons.favorite_outline),
        (RelationshipType.family, Icons.house_outlined),
      ];

  @override
  Widget build(BuildContext context) {
    final double scale = MediaQuery.textScalerOf(context).scale(15) / 15;

    return SizedBox(
      height: 92 * scale.clamp(1.0, 1.3),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
        children: <Widget>[
          for (final (GiftSituation situation, IconData icon) in _situations)
            _QuickTile(
              label: situation.label,
              icon: icon,
              onTap: () => onSituation(situation),
            ),
          for (final (RelationshipType relationship, IconData icon)
              in _relationships)
            _QuickTile(
              label: relationship.label,
              icon: icon,
              onTap: () => onRelationship(relationship),
            ),
        ],
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: SizedBox(
          width: 68,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 22, color: AppColors.brandCoralDark),
              ),
              const SizedBox(height: AppSpacing.sm),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
