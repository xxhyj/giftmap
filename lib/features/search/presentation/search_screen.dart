import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/selectable_chip.dart';
import '../../gift_finder/domain/gift_intent.dart';
import '../../products/domain/product.dart';
import '../../products/domain/product_catalog.dart';
import '../../products/presentation/product_detail_screen.dart';
import '../../products/presentation/widgets/product_collections.dart';

/// 로컬 카탈로그를 검색하는 화면. 네트워크 요청은 없다.
class SearchScreen extends StatefulWidget {
  const SearchScreen({this.initialQuery, super.key});

  final String? initialQuery;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialQuery ?? '',
  );
  String _query = '';
  String? _category;
  BudgetBand? _priceRange;
  ProductSort _sort = ProductSort.recommended;
  bool _searching = false;

  static const List<String> _suggestions = <String>[
    '집들이 선물',
    '핸드크림',
    '디퓨저',
    '텀블러',
    '차 선물세트',
    '데스크 정리',
  ];

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery?.trim() ?? '';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit(String raw) async {
    final String query = raw.trim();
    // 검색 키워드는 저장하지 않는다(검색 기록 미수집).
    setState(() {
      _query = query;
      _searching = true;
    });
    // 로컬 검색은 즉시 끝나지만 결과가 바뀌는 순간을 인지할 수 있게 한 프레임 둔다.
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (mounted) setState(() => _searching = false);
  }

  void _openProduct(Product product) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            ProductDetailScreen(product: product),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppDependencies deps = AppScope.of(context);
    final ProductCatalog catalog = deps.catalog;
    final bool hasQuery = _query.isNotEmpty;
    final List<Product> results = catalog.search(
      _query,
      category: _category,
      priceRange: _priceRange,
      sort: _sort,
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.md),
          child: TextField(
            controller: _controller,
            autofocus: widget.initialQuery == null,
            textInputAction: TextInputAction.search,
            onSubmitted: _submit,
            decoration: InputDecoration(
              hintText: '어떤 선물을 찾고 있나요?',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '지우기',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _controller.clear();
                        _submit('');
                      },
                    ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.bottomAction),
          children: <Widget>[
            if (!hasQuery) ...<Widget>[
              const _Padded(child: SectionHeader(title: '추천 검색어')),
              _Padded(
                child: ChipWrap(
                  children: _suggestions
                      .map(
                        (String q) => SelectableChip(
                          label: q,
                          selected: false,
                          onTap: () {
                            _controller.text = q;
                            _submit(q);
                          },
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _Padded(child: SectionHeader(title: '카테고리로 찾기')),
              _Padded(
                child: ChipWrap(
                  children: catalog.categories
                      .map(
                        (({String id, String label}) c) => SelectableChip(
                          label: c.label,
                          selected: _category == c.id,
                          onTap: () {
                            setState(() => _category = c.id);
                            _submit(_controller.text);
                          },
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ],
            if (hasQuery || _category != null) ...<Widget>[
              _FilterBar(
                category: _category,
                priceRange: _priceRange,
                sort: _sort,
                categories: catalog.categories,
                onCategory: (String? value) =>
                    setState(() => _category = value),
                onPrice: (BudgetBand? value) =>
                    setState(() => _priceRange = value),
                onSort: (ProductSort value) => setState(() => _sort = value),
              ),
              _Padded(
                child: Text(
                  '검색 결과 ${results.length}개',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_searching)
                const _Padded(child: ProductGridSkeleton())
              else if (results.isEmpty)
                _EmptyResult(
                  query: _query,
                  suggestions: _suggestions,
                  onSuggestion: (String q) {
                    _controller.text = q;
                    setState(() {
                      _category = null;
                      _priceRange = null;
                    });
                    _submit(q);
                  },
                )
              else
                _Padded(
                  child: ProductGrid(products: results, onOpen: _openProduct),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Padded extends StatelessWidget {
  const _Padded({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
    child: child,
  );
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.category,
    required this.priceRange,
    required this.sort,
    required this.categories,
    required this.onCategory,
    required this.onPrice,
    required this.onSort,
  });

  final String? category;
  final BudgetBand? priceRange;
  final ProductSort sort;
  final List<({String id, String label})> categories;
  final ValueChanged<String?> onCategory;
  final ValueChanged<BudgetBand?> onPrice;
  final ValueChanged<ProductSort> onSort;

  static const List<BudgetBand> _bands = <BudgetBand>[
    BudgetBand.from10kTo30k,
    BudgetBand.from30kTo50k,
    BudgetBand.from50kTo100k,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
            children: <Widget>[
              SelectableChip(
                label: '전체',
                selected: category == null && priceRange == null,
                onTap: () {
                  onCategory(null);
                  onPrice(null);
                },
              ),
              const SizedBox(width: AppSpacing.sm),
              for (final BudgetBand band in _bands) ...<Widget>[
                SelectableChip(
                  label: band.label,
                  selected: priceRange == band,
                  onTap: () => onPrice(priceRange == band ? null : band),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              for (final ({String id, String label}) c
                  in categories) ...<Widget>[
                SelectableChip(
                  label: c.label,
                  selected: category == c.id,
                  onTap: () => onCategory(category == c.id ? null : c.id),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
          child: Row(
            children: <Widget>[
              const Spacer(),
              PopupMenuButton<ProductSort>(
                initialValue: sort,
                onSelected: onSort,
                tooltip: '정렬 기준',
                itemBuilder: (BuildContext context) => ProductSort.values
                    .map(
                      (ProductSort value) => PopupMenuItem<ProductSort>(
                        value: value,
                        child: Text(value.label),
                      ),
                    )
                    .toList(growable: false),
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
                      color: AppColors.inkMuted,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyResult extends StatelessWidget {
  const _EmptyResult({
    required this.query,
    required this.suggestions,
    required this.onSuggestion,
  });

  final String query;
  final List<String> suggestions;
  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        EmptyStateView(
          icon: Icons.search_off,
          title: '"$query" 검색 결과가 없어요',
          message: '다른 키워드로 찾아보거나 아래 추천 검색어를 눌러보세요.',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
          child: ChipWrap(
            children: suggestions
                .take(4)
                .map(
                  (String q) => SelectableChip(
                    label: q,
                    selected: false,
                    onTap: () => onSuggestion(q),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ],
    );
  }
}
