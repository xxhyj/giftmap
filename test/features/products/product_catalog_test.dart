import 'package:flutter_test/flutter_test.dart';
import 'package:giftmap/features/gift_finder/domain/gift_intent.dart';
import 'package:giftmap/features/products/domain/product.dart';
import 'package:giftmap/features/products/domain/product_catalog.dart';

import '../../fixtures/ruleset_fixture.dart';

void main() {
  late ProductCatalog catalog;

  setUp(() {
    catalog = loadBundledCatalog();
  });

  test('번들 카탈로그는 추천 검색어를 함께 제공한다', () {
    expect(catalog.searchSuggestions, isNotEmpty);
    expect(catalog.isRemote, isFalse);
  });

  test('카탈로그는 30개 이상의 상품을 담는다', () {
    expect(catalog.products.length, greaterThanOrEqualTo(30));
    expect(catalog.categories.length, greaterThanOrEqualTo(10));
  });

  test('모든 상품은 데모 표시와 유효한 가격을 가진다', () {
    for (final Product product in catalog.products) {
      expect(product.isDemo, isTrue);
      expect(product.price, isNotNull);
      expect(product.price!, greaterThan(0));
      expect(product.productName, isNotEmpty);
      expect(product.brandName, isNotEmpty);
      expect(product.description, isNotEmpty);
    }
  });

  test('할인 상품은 정가가 판매가보다 높다', () {
    for (final Product product in catalog.discounted) {
      expect(product.originalPrice, isNotNull);
      expect(product.originalPrice! > product.price!, isTrue);
      expect(product.discountRate, greaterThan(0));
    }
  });

  test('키워드로 상품을 찾는다', () {
    final List<Product> results = catalog.search('핸드크림');
    expect(results, isNotEmpty);
    expect(
      results.every(
        (Product p) =>
            p.searchIndex.contains('핸드') || p.category == 'hand_care',
      ),
      isTrue,
    );
  });

  test('대소문자와 공백을 무시하고 검색한다', () {
    final List<Product> spaced = catalog.search('  디 퓨 저  ');
    final List<Product> plain = catalog.search('디퓨저');
    expect(plain, isNotEmpty);
    expect(
      spaced.map((Product p) => p.id).toList(),
      plain.map((Product p) => p.id).toList(),
    );
  });

  test('결과가 없는 검색어는 빈 목록을 돌려준다', () {
    expect(catalog.search('존재하지않는상품명123'), isEmpty);
  });

  test('카테고리 필터가 적용된다', () {
    final List<Product> results = catalog.search('', category: 'tumbler');
    expect(results, isNotEmpty);
    expect(results.every((Product p) => p.category == 'tumbler'), isTrue);
  });

  test('가격 구간 필터가 적용된다', () {
    final List<Product> results = catalog.search(
      '',
      priceRange: BudgetBand.from10kTo30k,
    );
    expect(results, isNotEmpty);
    expect(
      results.every(
        (Product p) => p.price != null && p.price! > 10000 && p.price! <= 30000,
      ),
      isTrue,
    );
  });

  test('정렬 기준이 결과 순서를 바꾼다', () {
    final List<Product> low = catalog.search('', sort: ProductSort.priceLow);
    final List<Product> high = catalog.search('', sort: ProductSort.priceHigh);
    expect(low.first.sortPrice, lessThanOrEqualTo(low.last.sortPrice));
    expect(high.first.sortPrice, greaterThanOrEqualTo(high.last.sortPrice));
  });

  test('같은 검색은 항상 같은 순서를 만든다', () {
    final List<String> first = catalog
        .search('선물')
        .map((Product p) => p.id)
        .toList();
    final List<String> second = catalog
        .search('선물')
        .map((Product p) => p.id)
        .toList();
    expect(second, first);
  });

  test('id로 상품을 찾고 없는 id는 무시한다', () {
    final Product any = catalog.products.first;
    expect(catalog.byId(any.id)?.id, any.id);
    expect(catalog.byId('unknown_id'), isNull);
    expect(catalog.byIds(<String>[any.id, 'unknown_id']).length, 1);
  });

  test('상황·관계·가격 큐레이션이 조건을 지킨다', () {
    expect(
      catalog
          .byOccasion(GiftSituation.housewarming)
          .every(
            (Product p) => p.occasions.contains(GiftSituation.housewarming),
          ),
      isTrue,
    );
    expect(
      catalog
          .byRecipient(RelationshipType.friend)
          .every(
            (Product p) => p.recipientTypes.contains(RelationshipType.friend),
          ),
      isTrue,
    );
    expect(
      catalog
          .byPriceUnder(30000)
          .every((Product p) => p.price != null && p.price! <= 30000),
      isTrue,
    );
  });
}
