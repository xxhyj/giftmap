import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/responsive_body.dart';
import '../../../core/widgets/selectable_chip.dart';
import '../../products/domain/product.dart';
import '../../products/domain/product_catalog.dart';
import '../../products/presentation/product_detail_screen.dart';
import '../../products/presentation/widgets/paged_product_grid.dart';
import '../../search/presentation/search_screen.dart';
import '../domain/category_group.dart';

/// 카테고리 탭. 전체 상품을 종류별로 탐색한다.
///
/// 상품 수·카테고리 수를 고정값으로 가정하지 않고 카탈로그가 돌려준 목록을
/// 그대로 사용한다.
class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  String? _groupId;
  String? _categoryId;
  ProductSort _sort = ProductSort.recommended;

  void _openProduct(Product product) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            ProductDetailScreen(product: product),
      ),
    );
  }

  void _resetFilters() {
    setState(() {
      _groupId = null;
      _categoryId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ProductCatalog catalog = AppScope.of(context).catalog;
    final TextTheme text = Theme.of(context).textTheme;

    final List<CategoryGroup> groups = CategoryGroup.resolve(catalog);
    final CategoryGroup? group = groups
        .where((CategoryGroup g) => g.id == _groupId)
        .firstOrNull;

    final List<({String id, String label})> subCategories = group == null
        ? catalog.categories
        : catalog.categories
              .where(
                (({String id, String label}) c) =>
                    group.categoryIds.contains(c.id),
              )
              .toList(growable: false);

    final List<Product> products = _filter(catalog, group);

    return Scaffold(
      appBar: AppBar(
        title: const Text('카테고리'),
        actions: <Widget>[
          IconButton(
            tooltip: '상품 검색',
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) => const SearchScreen(),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveBody(
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.bottomAction),
            children: <Widget>[
              if (catalog.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.xl),
                  child: EmptyStateView(
                    icon: Icons.inventory_2_outlined,
                    title: '아직 준비된 상품이 없어요',
                    message: '상품이 준비되면 카테고리별로 둘러볼 수 있어요.',
                  ),
                )
              else ...<Widget>[
                _GroupChips(
                  groups: groups,
                  selectedId: _groupId,
                  onSelected: (String? id) => setState(() {
                    _groupId = id;
                    _categoryId = null;
                  }),
                ),
                if (subCategories.isNotEmpty)
                  _SubCategoryChips(
                    categories: subCategories,
                    selectedId: _categoryId,
                    onSelected: (String? id) =>
                        setState(() => _categoryId = id),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screen,
                    AppSpacing.md,
                    AppSpacing.screen,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _titleFor(group, subCategories),
                        style: text.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _descriptionFor(group, products.length),
                        style: text.labelSmall,
                      ),
                    ],
                  ),
                ),
                _SortRow(
                  sort: _sort,
                  onChanged: (ProductSort value) =>
                      setState(() => _sort = value),
                ),
                if (products.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xl),
                    child: EmptyStateView(
                      icon: Icons.search_off,
                      title: '이 조건에 맞는 상품이 없어요',
                      message: '다른 카테고리를 골라보거나 전체 상품을 확인해 보세요.',
                      actionLabel: '전체 상품 보기',
                      onAction: _resetFilters,
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screen,
                    ),
                    child: PagedProductGrid(
                      products: products,
                      onOpen: _openProduct,
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screen,
                  ),
                  child: Text(
                    AppScope.of(context).productDisclaimer,
                    style: text.labelSmall,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Product> _filter(ProductCatalog catalog, CategoryGroup? group) {
    if (_categoryId != null) {
      return catalog.search('', category: _categoryId, sort: _sort);
    }
    final List<Product> all = catalog.search('', sort: _sort);
    if (group == null) return all;
    return all
        .where((Product p) => group.categoryIds.contains(p.category))
        .toList(growable: false);
  }

  String _titleFor(
    CategoryGroup? group,
    List<({String id, String label})> subCategories,
  ) {
    if (_categoryId != null) {
      return subCategories
              .where((({String id, String label}) c) => c.id == _categoryId)
              .firstOrNull
              ?.label ??
          '선택한 카테고리';
    }
    return group?.label ?? '전체 상품';
  }

  String _descriptionFor(CategoryGroup? group, int count) {
    final String base = _categoryId != null
        ? '고른 카테고리의 상품'
        : (group?.description ?? '전체 카테고리의 상품');
    return '$base · $count개';
  }
}

class _GroupChips extends StatelessWidget {
  const _GroupChips({
    required this.groups,
    required this.selectedId,
    required this.onSelected,
  });

  final List<CategoryGroup> groups;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.sm,
        AppSpacing.screen,
        0,
      ),
      child: ChipWrap(
        children: <Widget>[
          SelectableChip(
            label: '전체',
            selected: selectedId == null,
            onTap: () => onSelected(null),
          ),
          for (final CategoryGroup group in groups)
            SelectableChip(
              label: group.label,
              selected: selectedId == group.id,
              onTap: () => onSelected(selectedId == group.id ? null : group.id),
            ),
        ],
      ),
    );
  }
}

class _SubCategoryChips extends StatelessWidget {
  const _SubCategoryChips({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  final List<({String id, String label})> categories;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.md,
          AppSpacing.screen,
          0,
        ),
        children: <Widget>[
          for (final ({String id, String label}) category in categories)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: SelectableChip(
                label: category.label,
                selected: selectedId == category.id,
                onTap: () =>
                    onSelected(selectedId == category.id ? null : category.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _SortRow extends StatelessWidget {
  const _SortRow({required this.sort, required this.onChanged});

  final ProductSort sort;
  final ValueChanged<ProductSort> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.sm,
        AppSpacing.screen,
        AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          const Spacer(),
          PopupMenuButton<ProductSort>(
            initialValue: sort,
            onSelected: onChanged,
            tooltip: '정렬 기준',
            itemBuilder: (BuildContext context) => ProductSort.values
                .map(
                  (ProductSort value) => PopupMenuItem<ProductSort>(
                    value: value,
                    child: Text(value.label),
                  ),
                )
                .toList(growable: false),
            child: Semantics(
              button: true,
              label: '정렬 기준 ${sort.label}',
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      sort.label,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const Icon(
                      Icons.expand_more,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
