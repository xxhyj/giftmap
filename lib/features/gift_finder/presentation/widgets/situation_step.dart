import 'package:flutter/material.dart';

import '../../application/gift_finder_controller.dart';
import '../../domain/gift_intent.dart';
import 'selection_tile.dart';

/// 1단계. 선물 상황 선택.
class SituationStep extends StatelessWidget {
  const SituationStep({required this.controller, super.key});

  final GiftFinderController controller;

  static const Map<GiftSituation, IconData> _icons = <GiftSituation, IconData>{
    GiftSituation.birthday: Icons.cake_outlined,
    GiftSituation.anniversary: Icons.favorite_border,
    GiftSituation.promotion: Icons.trending_up,
    GiftSituation.thanks: Icons.volunteer_activism_outlined,
    GiftSituation.housewarming: Icons.home_outlined,
    GiftSituation.birth: Icons.child_friendly_outlined,
    GiftSituation.holiday: Icons.celebration_outlined,
    GiftSituation.support: Icons.emoji_events_outlined,
    GiftSituation.other: Icons.more_horiz,
  };

  @override
  Widget build(BuildContext context) {
    return SelectionTileGrid(
      children: GiftSituation.values
          .map(
            (GiftSituation value) => SelectionTile(
              label: value.label,
              icon: _icons[value] ?? Icons.card_giftcard_outlined,
              selected: controller.situation == value,
              onTap: () => controller.selectSituation(value),
            ),
          )
          .toList(growable: false),
    );
  }
}
