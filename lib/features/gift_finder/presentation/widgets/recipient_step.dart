import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/selectable_chip.dart';
import '../../application/gift_finder_controller.dart';
import '../../domain/gift_intent.dart';
import 'selection_tile.dart';

/// 2단계. 관계와 연령대 선택. 연령대는 선택 사항이다.
class RecipientStep extends StatelessWidget {
  const RecipientStep({required this.controller, super.key});

  final GiftFinderController controller;

  static const Map<RelationshipType, IconData> _icons =
      <RelationshipType, IconData>{
        RelationshipType.partner: Icons.favorite_outline,
        RelationshipType.friend: Icons.people_alt_outlined,
        RelationshipType.family: Icons.house_outlined,
        RelationshipType.colleague: Icons.badge_outlined,
        RelationshipType.manager: Icons.workspace_premium_outlined,
        RelationshipType.acquaintance: Icons.handshake_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SelectionTileGrid(
          children: RelationshipType.values
              .map(
                (RelationshipType value) => SelectionTile(
                  label: value.label,
                  icon: _icons[value] ?? Icons.person_outline,
                  selected: controller.relationship == value,
                  onTap: () => controller.selectRelationship(value),
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: AppSpacing.xl),
        const SectionHeader(title: '연령대', subtitle: '선택하지 않아도 추천을 받을 수 있어요'),
        ChipWrap(
          children: AgeBand.values
              .where((AgeBand value) => value != AgeBand.unspecified)
              .map(
                (AgeBand value) => SelectableChip(
                  label: value.label,
                  selected: controller.ageBand == value,
                  onTap: () => controller.selectAgeBand(value),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}
