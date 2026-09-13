import 'package:flutter_test/flutter_test.dart';
import 'package:giftmap/features/gift_finder/domain/gift_intent.dart';
import 'package:giftmap/features/products/data/bundled_product_data_source.dart';
import 'package:giftmap/features/products/data/remote_first_product_data_source.dart';
import 'package:giftmap/features/products/domain/product.dart';
import 'package:giftmap/features/products/domain/product_catalog.dart';

import '../../fixtures/ruleset_fixture.dart';

/// 번들 JSON을 그대로 돌려주는 fallback.
final class _BundledFixtureSource implements ProductDataSource {
  const _BundledFixtureSource();

  @override
  Future<ProductCatalog> load() async => loadBundledCatalog();
}

final class _RemoteSource implements ProductDataSource {
  const _RemoteSource(this.catalog);

  final ProductCatalog catalog;

  @override
  Future<ProductCatalog> load() async => catalog;
}

final class _FailingSource implements ProductDataSource {
  const _FailingSource();

  @override
  Future<ProductCatalog> load() async => throw StateError('network down');
}

final class _HangingSource implements ProductDataSource {
  const _HangingSource();

  @override
  Future<ProductCatalog> load() async {
    await Future<void>.delayed(const Duration(seconds: 30));
    return loadBundledCatalog();
  }
}

ProductCatalog catalogOf(List<Product> products) => ProductCatalog(
  products: products,
  version: 'supabase',
  disclaimer: defaultProductDisclaimer,
  searchSuggestions: const <String>['원격 검색어'],
);

Product productOf(String id) => Product(
  id: id,
  productName: '원격 상품 $id',
  category: 'perfume',
  categoryLabel: '향수',
  subCategory: '',
  price: 30000,
  tags: const <String>[],
  occasions: const <GiftSituation>[],
  recipientTypes: const <RelationshipType>[],
  ageRange: const <AgeBand>[],
  priceRange: BudgetBand.from10kTo30k,
  recommendationKeywords: const <String>[],
  description: '',
  recommendationReason: '',
  createdAt: DateTime(2026),
);

void main() {
  test('원격이 상품을 주면 원격 카탈로그를 쓴다', () async {
    final RemoteFirstProductDataSource source = RemoteFirstProductDataSource(
      remote: _RemoteSource(catalogOf(<Product>[productOf('r1')])),
      fallback: const _BundledFixtureSource(),
    );

    final ProductCatalog catalog = await source.load();
    expect(catalog.isRemote, isTrue);
    expect(catalog.products.single.id, 'r1');
    expect(catalog.searchSuggestions, <String>['원격 검색어']);
  });

  test('원격이 실패하면 번들 데이터로 되돌아간다', () async {
    final RemoteFirstProductDataSource source = RemoteFirstProductDataSource(
      remote: const _FailingSource(),
      fallback: const _BundledFixtureSource(),
    );

    final ProductCatalog catalog = await source.load();
    expect(catalog.isRemote, isFalse);
    expect(catalog.products, isNotEmpty);
  });

  test('원격이 비어 있으면 번들 데이터로 되돌아간다', () async {
    final RemoteFirstProductDataSource source = RemoteFirstProductDataSource(
      remote: _RemoteSource(catalogOf(const <Product>[])),
      fallback: const _BundledFixtureSource(),
    );

    final ProductCatalog catalog = await source.load();
    expect(catalog.isRemote, isFalse);
    expect(catalog.products, isNotEmpty);
  });

  test('원격이 응답하지 않으면 시간 안에 번들 데이터로 넘어간다', () async {
    final RemoteFirstProductDataSource source = RemoteFirstProductDataSource(
      remote: const _HangingSource(),
      fallback: const _BundledFixtureSource(),
      timeout: const Duration(milliseconds: 50),
    );

    final ProductCatalog catalog = await source.load();
    expect(catalog.isRemote, isFalse);
    expect(catalog.products, isNotEmpty);
  });
}
