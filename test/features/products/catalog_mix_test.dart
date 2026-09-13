import 'package:flutter_test/flutter_test.dart';
import 'package:giftmap/features/gift_finder/domain/gift_intent.dart';
import 'package:giftmap/features/products/domain/product.dart';
import 'package:giftmap/features/products/domain/product_catalog.dart';

Product _product({
  required String id,
  required String source,
  required String category,
  int price = 20000,
  List<String> occasions = const <String>['birthday', 'thanks', 'housewarming'],
  List<String> recipients = const <String>['friend'],
}) => Product.fromJson(<String, Object?>{
  'id': id,
  'productName': '$category 상품 $id',
  'category': category,
  'categoryLabel': category,
  'price': price,
  'productUrl': 'https://example.test/$id',
  'imageUrl': 'https://example.test/$id.jpg',
  'isDemo': false,
  'source': source,
  'occasions': occasions,
  'recipientTypes': recipients,
});

/// 한 출처(stationery)가 압도적으로 많은 상황을 만든다.
ProductCatalog _skewedCatalog() {
  final List<Product> products = <Product>[
    for (int i = 0; i < 40; i += 1)
      _product(id: 'a$i', source: '10x10', category: 'stationery'),
    for (int i = 0; i < 3; i += 1)
      _product(id: 'b$i', source: 'musinsa', category: 'fashion_clothing'),
    for (int i = 0; i < 3; i += 1)
      _product(id: 'c$i', source: 'aladin', category: 'book'),
    for (int i = 0; i < 3; i += 1)
      _product(id: 'd$i', source: '10x10', category: 'perfume'),
  ];
  return ProductCatalog(products: products, version: 'test', disclaimer: '');
}

void main() {
  test('한 출처·분류가 목록을 뒤덮지 않는다', () {
    final List<Product> mixed = _skewedCatalog().byPriceUnder(50000, limit: 12);

    expect(mixed.length, 12);
    final Set<String> sources = mixed.map((Product p) => p.source!).toSet();
    final Set<String> categories = mixed.map((Product p) => p.category).toSet();

    // 세 출처와 여러 분류가 모두 앞쪽에 섞여 들어온다.
    expect(sources, containsAll(<String>['10x10', 'musinsa', 'aladin']));
    expect(categories.length, greaterThanOrEqualTo(3));

    // 40개짜리 분류가 절반을 넘지 않는다.
    final int stationery = mixed
        .where((Product p) => p.category == 'stationery')
        .length;
    expect(stationery, lessThanOrEqualTo(6));

    // 상품이 많은 출처가 앞자리를 독차지하지 않는다.
    // (분류만 섞고 출처를 섞지 않으면 여기서 10x10 이 12칸을 다 가져간다)
    final int fromBiggest = mixed
        .where((Product p) => p.source == '10x10')
        .length;
    expect(fromBiggest, lessThanOrEqualTo(8));
    expect(mixed.take(3).map((Product p) => p.source).toSet().length, 3);
  });

  test('인기 상품도 출처를 섞어 보여 준다', () {
    final List<Product> popular = _skewedCatalog().popular;

    expect(popular, isNotEmpty);
    expect(popular.map((Product p) => p.source).toSet().length, greaterThan(1));
  });

  test('관계·상황별 큐레이션도 섞인다', () {
    final ProductCatalog catalog = _skewedCatalog();

    expect(
      catalog
          .byRecipient(RelationshipType.friend)
          .map((Product p) => p.source)
          .toSet()
          .length,
      greaterThan(1),
    );
    expect(
      catalog
          .byOccasion(GiftSituation.housewarming)
          .map((Product p) => p.category)
          .toSet()
          .length,
      greaterThan(1),
    );
  });

  test('섞어도 같은 카탈로그면 항상 같은 순서다', () {
    final ProductCatalog catalog = _skewedCatalog();
    final List<String> first = catalog
        .byPriceUnder(50000, limit: 12)
        .map((Product p) => p.id)
        .toList();
    final List<String> second = catalog
        .byPriceUnder(50000, limit: 12)
        .map((Product p) => p.id)
        .toList();

    expect(first, second);
  });

  test('품절이 확인된 상품은 목록에서 빠진다', () {
    final ProductCatalog catalog = ProductCatalog(
      products: <Product>[
        Product.fromJson(<String, Object?>{
          'id': 'sold',
          'productName': '품절 상품',
          'category': 'living',
          'categoryLabel': '생활용품',
          'price': 1000,
          'isDemo': false,
          'source': 'daiso',
          'inStock': false,
          'occasions': <String>['birthday', 'thanks', 'housewarming'],
        }),
        Product.fromJson(<String, Object?>{
          'id': 'ok',
          'productName': '판매 중 상품',
          'category': 'living',
          'categoryLabel': '생활용품',
          'price': 9000,
          'isDemo': false,
          'source': 'daiso',
          'inStock': true,
          'occasions': <String>['birthday'],
        }),
      ],
      version: 'test',
      disclaimer: '',
    );

    // 싸고 커버리지가 넓어도 품절이면 목록에 내보내지 않는다.
    expect(catalog.search('').map((Product p) => p.id), <String>['ok']);
    expect(catalog.sellable.map((Product p) => p.id), <String>['ok']);

    // 지우지는 않는다. 찜·최근 본 상품에서 다시 찾을 수 있어야 한다.
    expect(catalog.byId('sold'), isNotNull);
    expect(catalog.byId('sold')!.isSoldOut, isTrue);
    // 품절 상품은 사러 갈 수 없으므로 CTA 를 열지 않는다.
    expect(catalog.byId('sold')!.canOpenStore, isFalse);
  });

  test('재고를 모르는 상품은 밀지 않는다', () {
    final ProductCatalog catalog = ProductCatalog(
      products: <Product>[
        Product.fromJson(<String, Object?>{
          'id': 'unknown',
          'productName': '재고 모름',
          'category': 'living',
          'categoryLabel': '생활용품',
          'price': 1000,
          'isDemo': false,
        }),
        Product.fromJson(<String, Object?>{
          'id': 'instock',
          'productName': '판매 중',
          'category': 'living',
          'categoryLabel': '생활용품',
          'price': 9000,
          'isDemo': false,
          'inStock': true,
        }),
      ],
      version: 'test',
      disclaimer: '',
    );

    // 재고를 모르는 상품은 그대로 목록에 남는다.
    expect(catalog.search('', sort: ProductSort.priceLow).first.id, 'unknown');
    expect(catalog.sellable.length, 2);
  });

  test('상품이 적으면 있는 만큼만 돌려준다', () {
    final ProductCatalog small = ProductCatalog(
      products: <Product>[
        _product(id: 'x', source: '10x10', category: 'perfume'),
      ],
      version: 'test',
      disclaimer: '',
    );

    expect(small.byPriceUnder(50000, limit: 12).length, 1);
  });
}
