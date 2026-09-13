import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../domain/product.dart';
import 'product_collections.dart';

/// 상품이 많을 때 조금씩 늘려 보여 주는 그리드.
///
/// 수집한 실제 상품은 수백 건이라 한 번에 다 그리면 느려진다.
/// 목록 끝에 가까워지면 다음 묶음을 이어 붙이고, 스크롤이 닿지 않는 상황을
/// 대비해 "더 보기" 버튼도 함께 둔다.
///
/// 자신이 스크롤을 갖지 않고 감싸고 있는 스크롤 화면에 얹혀 동작한다.
class PagedProductGrid extends StatefulWidget {
  const PagedProductGrid({
    required this.products,
    required this.onOpen,
    this.badgeOf,
    this.pageSize = 30,
    super.key,
  });

  final List<Product> products;
  final void Function(Product product) onOpen;
  final String? Function(Product product)? badgeOf;

  /// 한 번에 더 보여 줄 개수.
  final int pageSize;

  @override
  State<PagedProductGrid> createState() => _PagedProductGridState();
}

class _PagedProductGridState extends State<PagedProductGrid> {
  late int _visible = widget.pageSize;
  ScrollPosition? _position;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 감싸고 있는 스크롤 화면의 위치를 듣는다.
    final ScrollPosition? position = Scrollable.maybeOf(context)?.position;
    if (identical(position, _position)) return;
    _position?.removeListener(_onScroll);
    _position = position;
    _position?.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(PagedProductGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 필터·정렬이 바뀌어 목록이 달라지면 처음부터 다시 보여 준다.
    if (!identical(oldWidget.products, widget.products)) {
      _visible = widget.pageSize;
    }
  }

  @override
  void dispose() {
    _position?.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    final ScrollPosition? position = _position;
    if (position == null || !position.hasContentDimensions) return;
    // 끝에서 한 화면쯤 남았을 때 미리 이어 붙인다.
    if (position.pixels >= position.maxScrollExtent - 600) _showMore();
  }

  void _showMore() {
    if (_visible >= widget.products.length) return;
    setState(() {
      _visible = (_visible + widget.pageSize).clamp(0, widget.products.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final int total = widget.products.length;
    final int visible = _visible.clamp(0, total);
    final List<Product> shown = widget.products.take(visible).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ProductGrid(
          products: shown,
          onOpen: widget.onOpen,
          badgeOf: widget.badgeOf,
        ),
        if (visible < total) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: OutlinedButton(
              onPressed: _showMore,
              child: Text('더 보기 ($visible / $total)'),
            ),
          ),
        ],
      ],
    );
  }
}
