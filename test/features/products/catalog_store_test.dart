import 'package:flutter_test/flutter_test.dart';
import 'package:giftmap/features/products/application/catalog_store.dart';
import 'package:giftmap/features/products/data/bundled_product_data_source.dart';
import 'package:giftmap/features/products/domain/product.dart';
import 'package:giftmap/features/products/domain/product_catalog.dart';

Product _product(int index) => Product.fromJson(<String, Object?>{
  'id': 'p${index.toString().padLeft(4, '0')}',
  'productName': '상품 $index',
  'category': 'stationery',
  'categoryLabel': '문구',
  'price': 10000 + index,
  'isDemo': false,
});

/// 서버를 흉내 내는 소스. 몇 번 요청했는지 센다.
final class _FakePagedSource implements PagedProductDataSource {
  _FakePagedSource(this.total);

  final int total;
  final List<(int, int)> requests = <(int, int)>[];

  @override
  Future<ProductPage> loadPage({
    required int offset,
    required int limit,
  }) async {
    requests.add((offset, limit));
    final List<Product> slice = <Product>[
      for (int i = offset; i < offset + limit && i < total; i += 1) _product(i),
    ];
    return ProductPage(
      products: slice,
      hasMore: offset + slice.length < total,
      version: 'supabase',
      disclaimer: '실제 상품',
      searchSuggestions: offset == 0 ? const <String>['향수'] : const <String>[],
    );
  }

  @override
  Future<ProductCatalog> load() async =>
      throw StateError('나눠 받는 소스에서는 전량 로드를 쓰지 않는다');
}

/// 나눠 받을 수 없는 소스(번들 JSON처럼).
final class _WholeSource implements ProductDataSource {
  int calls = 0;

  @override
  Future<ProductCatalog> load() async {
    calls += 1;
    return ProductCatalog(
      products: <Product>[_product(0), _product(1)],
      version: 'bundle',
      disclaimer: '데모',
    );
  }
}

void main() {
  test('첫 화면에는 첫 묶음만 받는다', () async {
    final _FakePagedSource source = _FakePagedSource(1800);
    final CatalogStore store = CatalogStore(source: source, firstPageSize: 120);

    await store.loadFirstPage();

    // 1,800건을 한 번에 받지 않는다.
    expect(store.catalog.products.length, 120);
    expect(source.requests, <(int, int)>[(0, 120)]);
    expect(store.hasMore, isTrue);
    // 첫 묶음에 화면에 필요한 값이 함께 온다.
    expect(store.catalog.searchSuggestions, <String>['향수']);
    expect(store.catalog.disclaimer, '실제 상품');
  });

  test('더 요청하면 뒤에 이어 붙는다', () async {
    final _FakePagedSource source = _FakePagedSource(1800);
    final CatalogStore store = CatalogStore(
      source: source,
      firstPageSize: 120,
      pageSize: 200,
    );
    await store.loadFirstPage();

    await store.loadMore();

    expect(store.catalog.products.length, 320);
    expect(source.requests.last, (120, 200));
    // 앞서 받은 상품이 사라지지 않는다.
    expect(store.catalog.products.first.id, 'p0000');
    expect(store.catalog.products.last.id, 'p0319');
  });

  test('끝까지 받으면 더 요청하지 않는다', () async {
    final _FakePagedSource source = _FakePagedSource(150);
    final CatalogStore store = CatalogStore(
      source: source,
      firstPageSize: 120,
      pageSize: 200,
    );
    await store.loadFirstPage();
    await store.loadMore();

    expect(store.catalog.products.length, 150);
    expect(store.hasMore, isFalse);

    final int before = source.requests.length;
    await store.loadMore();
    expect(source.requests.length, before, reason: '더 없는데 또 요청했다');
  });

  test('상품이 늘어나면 알림을 보낸다', () async {
    final _FakePagedSource source = _FakePagedSource(1800);
    final CatalogStore store = CatalogStore(source: source, firstPageSize: 10);
    int notified = 0;
    store.addListener(() => notified += 1);

    await store.loadFirstPage();
    expect(notified, greaterThan(0));

    final int afterFirst = notified;
    await store.loadMore();
    expect(notified, greaterThan(afterFirst));
  });

  test('나눠 받을 수 없는 소스는 한 번에 읽고 끝낸다', () async {
    final _WholeSource source = _WholeSource();
    final CatalogStore store = CatalogStore(source: source);

    await store.loadFirstPage();
    expect(store.catalog.products.length, 2);
    expect(store.hasMore, isFalse);

    await store.loadMore();
    expect(source.calls, 1, reason: '더 받을 수 없는데 또 읽었다');
  });

  test('더 받다 실패해도 이미 받은 상품은 남는다', () async {
    final _FailingSource source = _FailingSource();
    final CatalogStore store = CatalogStore(source: source, firstPageSize: 5);

    await store.loadFirstPage();
    expect(store.catalog.products.length, 5);

    // 두 번째 요청은 실패한다. 예외가 밖으로 나오지 않아야 한다.
    await store.loadMore();
    expect(store.catalog.products.length, 5);
    expect(store.isLoadingMore, isFalse);
  });
}

/// 첫 묶음만 주고 그다음부터 실패하는 소스.
final class _FailingSource implements PagedProductDataSource {
  int calls = 0;

  @override
  Future<ProductPage> loadPage({
    required int offset,
    required int limit,
  }) async {
    calls += 1;
    if (calls > 1) throw StateError('네트워크 실패');
    return ProductPage(
      products: <Product>[for (int i = 0; i < limit; i += 1) _product(i)],
      hasMore: true,
    );
  }

  @override
  Future<ProductCatalog> load() async => throw StateError('쓰지 않는다');
}
