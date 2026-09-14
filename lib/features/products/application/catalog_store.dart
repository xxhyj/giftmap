import 'package:flutter/foundation.dart';

import '../data/bundled_product_data_source.dart';
import '../domain/product.dart';
import '../domain/product_catalog.dart';

/// 상품 카탈로그를 나눠 받아 들고 있는 곳.
///
/// 상품이 수천 건이 되면서, 앱을 켤 때 전부 받아 그리면 첫 화면이 나오기까지
/// 수십 초가 걸리고 그 사이 화면이 멈춘다(ANR). 그래서 첫 화면에 필요한 만큼만
/// 먼저 받고, 목록 끝에 닿으면 다음 묶음을 이어 받는다.
///
/// 나눠 받을 수 없는 데이터 소스(번들 JSON)는 한 번에 다 읽고 [hasMore]가 false가 된다.
class CatalogStore extends ChangeNotifier {
  CatalogStore({
    required ProductDataSource source,
    this.firstPageSize = 120,
    this.pageSize = 200,
  }) : // 이름 있는 매개변수는 private 이름을 쓸 수 없어 초기화 목록으로 대입한다.
       // ignore: prefer_initializing_formals
       _source = source;

  final ProductDataSource _source;

  /// 첫 화면을 띄우기 위해 받는 개수. 홈의 큐레이션을 채울 만큼이면 된다.
  final int firstPageSize;

  /// 이후 이어 받는 묶음 크기.
  final int pageSize;

  ProductCatalog _catalog = ProductCatalog(
    products: const <Product>[],
    version: 'loading',
    disclaimer: '',
  );

  /// 지금까지 받은 상품으로 만든 카탈로그.
  ProductCatalog get catalog => _catalog;

  bool _hasMore = true;

  /// 아직 받을 상품이 남아 있는지.
  bool get hasMore => _hasMore;

  /// 이미 받은 상품. 같은 상품이 두 번 붙는 것을 막는다.
  final Set<String> _loadedIds = <String>{};

  /// 서버에서 받아 온 행 수. 다음 요청의 시작 위치다.
  ///
  /// 화면에 남은 상품 수와 다를 수 있다(겹쳐 온 상품을 버리기 때문).
  /// 남은 수를 시작 위치로 쓰면 버린 만큼 뒤로 돌아가 같은 구간을 또 받는다.
  int _fetched = 0;

  bool _loading = false;

  /// 지금 더 받는 중인지. 같은 요청이 겹치지 않게 하는 데도 쓴다.
  bool get isLoadingMore => _loading;

  /// 첫 묶음을 받는다. 실패하면 예외를 그대로 올려 재시도 화면이 뜨게 한다.
  Future<void> loadFirstPage() async {
    final ProductDataSource source = _source;
    if (source is! PagedProductDataSource) {
      // 나눠 받을 수 없는 소스는 한 번에 읽는다(번들 데모 데이터).
      _catalog = await source.load();
      _hasMore = false;
      notifyListeners();
      return;
    }

    final ProductPage page = await source.loadPage(
      offset: 0,
      limit: firstPageSize,
    );
    _loadedIds
      ..clear()
      ..addAll(page.products.map((Product p) => p.id));
    _fetched = page.products.length;
    _catalog = ProductCatalog(
      products: page.products,
      version: page.version,
      disclaimer: page.disclaimer,
      searchSuggestions: page.searchSuggestions,
    );
    _hasMore = page.hasMore;
    notifyListeners();
  }

  /// 다음 묶음을 이어 받는다.
  ///
  /// 목록을 내리다 끝에 닿으면 호출된다. 이미 받는 중이거나 더 없으면 아무것도 하지 않는다.
  /// 실패해도 예외를 밖으로 던지지 않는다. 지금까지 받은 상품은 그대로 보여 준다.
  Future<void> loadMore() async {
    if (_loading || !_hasMore) return;
    final ProductDataSource source = _source;
    if (source is! PagedProductDataSource) return;

    _loading = true;
    notifyListeners();
    try {
      final ProductPage page = await source.loadPage(
        offset: _fetched,
        limit: pageSize,
      );
      // 서버가 같은 상품을 다시 보내도(정렬이 흔들리거나 그사이 상품이 늘면
      // 페이지가 겹친다) 목록에 두 번 붙이지 않는다.
      _fetched += page.products.length;
      final List<Product> fresh = page.products
          .where((Product p) => _loadedIds.add(p.id))
          .toList();
      _catalog = ProductCatalog(
        products: List<Product>.unmodifiable(<Product>[
          ..._catalog.products,
          ...fresh,
        ]),
        version: _catalog.version,
        disclaimer: _catalog.disclaimer,
        searchSuggestions: _catalog.searchSuggestions,
      );
      _hasMore = page.hasMore && page.products.isNotEmpty;
    } on Object catch (error) {
      // 더 받지 못했을 뿐이다. 화면을 무너뜨리지 않는다.
      debugPrint('[Giftmap] 상품을 더 불러오지 못했습니다: $error');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
