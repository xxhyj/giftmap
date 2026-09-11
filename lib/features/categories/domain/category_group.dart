import '../../products/domain/product_catalog.dart';

/// 카테고리 화면에서 쓰는 상위 그룹.
///
/// 상품 카테고리 수가 늘거나 줄어도 화면이 깨지지 않도록, 알려진 카테고리는
/// 지정된 그룹으로 묶고 나머지는 자동으로 "그 외"에 모은다.
/// 이 규칙은 표현 계층에만 존재하며 `Product` 모델은 바꾸지 않는다.
class CategoryGroup {
  const CategoryGroup({
    required this.id,
    required this.label,
    required this.description,
    required this.categoryIds,
  });

  final String id;
  final String label;
  final String description;

  /// 이 그룹에 속하는 상품 카테고리 id.
  final List<String> categoryIds;

  static const List<CategoryGroup> _defined = <CategoryGroup>[
    CategoryGroup(
      id: 'beauty_care',
      label: '뷰티·케어',
      description: '향과 손길이 남는 선물',
      categoryIds: <String>['perfume', 'hand_care', 'body_care', 'beauty'],
    ),
    CategoryGroup(
      id: 'food_drink',
      label: '푸드·디저트',
      description: '나눠 먹기 좋은 선물',
      categoryIds: <String>['tea_coffee', 'dessert'],
    ),
    CategoryGroup(
      id: 'home_living',
      label: '홈·리빙',
      description: '공간에 오래 머무는 선물',
      categoryIds: <String>['candle', 'homewear', 'living', 'tumbler'],
    ),
    CategoryGroup(
      id: 'desk_stationery',
      label: '문구·데스크',
      description: '매일 쓰는 자리에 남는 선물',
      categoryIds: <String>['stationery', 'desk'],
    ),
    CategoryGroup(
      id: 'fashion',
      label: '패션·잡화',
      description: '가지고 다니며 쓰는 선물',
      categoryIds: <String>['fashion_accessory', 'wallet'],
    ),
    CategoryGroup(
      id: 'hobby',
      label: '취미·라이프스타일',
      description: '취향을 응원하는 선물',
      categoryIds: <String>['hobby'],
    ),
  ];

  /// 카탈로그에 실제로 존재하는 카테고리만으로 그룹 목록을 만든다.
  ///
  /// 어떤 그룹에도 속하지 않은 카테고리는 "그 외"로 모아 빠뜨리지 않는다.
  static List<CategoryGroup> resolve(ProductCatalog catalog) {
    final Set<String> available = catalog.categories
        .map((({String id, String label}) c) => c.id)
        .toSet();

    final List<CategoryGroup> groups = <CategoryGroup>[];
    final Set<String> assigned = <String>{};

    for (final CategoryGroup group in _defined) {
      final List<String> ids = group.categoryIds
          .where(available.contains)
          .toList(growable: false);
      if (ids.isEmpty) continue;
      assigned.addAll(ids);
      groups.add(
        CategoryGroup(
          id: group.id,
          label: group.label,
          description: group.description,
          categoryIds: ids,
        ),
      );
    }

    final List<String> rest =
        available.where((String id) => !assigned.contains(id)).toList()..sort();
    if (rest.isNotEmpty) {
      groups.add(
        CategoryGroup(
          id: 'etc',
          label: '그 외',
          description: '다양한 선물',
          categoryIds: rest,
        ),
      );
    }
    return groups;
  }
}
