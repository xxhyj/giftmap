import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/rounded_surface.dart';
import '../../application/gift_finder_controller.dart';
import '../../domain/gift_intent.dart';
import 'selection_tile.dart';

/// 5단계. 피하고 싶은 조건. 선택한 태그와 겹치는 상품은 추천에서 제외한다.
class AvoidStep extends StatelessWidget {
  const AvoidStep({required this.controller, super.key});

  final GiftFinderController controller;

  static const Map<String, (IconData, String)> _options =
      <String, (IconData, String)>{
        AvoidTags.scent: (Icons.air_outlined, '향수, 디퓨저, 캔들 등'),
        AvoidTags.food: (Icons.no_food_outlined, '차, 디저트, 간식 등'),
        AvoidTags.sizing: (Icons.straighten_outlined, '옷, 홈웨어 등 사이즈가 필요한 것'),
        AvoidTags.strongTaste: (Icons.palette_outlined, '취향이 뚜렷하게 갈리는 것'),
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '선택한 항목과 겹치는 상품은 추천에서 빼드려요. 없으면 그냥 넘어가도 좋아요.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        Column(
          children: _options.entries
              .map(
                (MapEntry<String, (IconData, String)> entry) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: SelectionTile(
                    label: AvoidTags.labels[entry.key] ?? entry.key,
                    description: entry.value.$2,
                    icon: entry.value.$1,
                    selected: controller.avoidTags.contains(entry.key),
                    onTap: () => controller.toggleAvoidTag(entry.key),
                  ),
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: AppSpacing.md),
        const NoticeBlock(
          text: '상품 가격과 정보는 데모 데이터이며 실시간 판매 정보가 아니에요.',
          icon: Icons.sell_outlined,
        ),
      ],
    );
  }
}
