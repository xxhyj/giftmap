import 'package:flutter_test/flutter_test.dart';
import 'package:giftmap/features/products/domain/product.dart';
import 'package:giftmap/features/products/domain/product_catalog.dart';

Product _p({
  required String id,
  required String category,
  required String source,
  String? brand,
  String? name,
  String? url,
  int price = 20000,
  int? originalPrice,
}) => Product.fromJson(<String, Object?>{
  'id': id,
  'brandName': brand,
  'productName': name ?? '상품 $id',
  'category': category,
  'categoryLabel': category,
  'price': price,
  'originalPrice': originalPrice,
  'productUrl': url ?? 'https://shop.test/$id',
  'imageUrl': 'https://img.test/$id.jpg',
  'source': source,
  'isDemo': false,
  'occasions': <String>['birthday', 'thanks'],
  'recipientTypes': <String>['friend'],
});

ProductCatalog _catalog(List<Product> products) =>
    ProductCatalog(products: products, version: 'supabase', disclaimer: '');

void main() {
  group('같은 상품 합치기', () {
    test('주소가 같으면 판매처가 달라도 카드는 하나다', () {
      // 추적 파라미터와 m. 호스트만 다른 같은 상품.
      final ProductCatalog catalog = _catalog(<Product>[
        _p(
          id: 'a-1',
          category: 'book',
          source: 'aladin',
          url: 'https://www.aladin.co.kr/shop/wproduct.aspx?ItemId=7',
        ),
        _p(
          id: 'b-1',
          category: 'book',
          source: '10x10',
          url:
              'https://m.aladin.co.kr/shop/wproduct.aspx?ItemId=7&utm_source=x',
        ),
      ]);

      expect(catalog.sellable.length, 1);
      // 빠진 판매처도 함께 들고 있는다.
      expect(catalog.offersOf(catalog.sellable.first).length, 2);
    });

    test('브랜드와 상품명이 같으면 같은 상품으로 본다', () {
      final ProductCatalog catalog = _catalog(<Product>[
        _p(
          id: 'a-2',
          category: 'book',
          source: 'aladin',
          brand: '민음사',
          name: '데미안',
          url: 'https://a.test/x',
        ),
        _p(
          id: 'b-2',
          category: 'book',
          source: '10x10',
          brand: '민음사 ',
          name: '데미안!',
          url: 'https://b.test/y',
        ),
      ]);

      expect(catalog.sellable.length, 1);
    });

    test('출판사가 다른 같은 제목은 다른 상품이다', () {
      final ProductCatalog catalog = _catalog(<Product>[
        _p(
          id: 'a-3',
          category: 'book',
          source: 'aladin',
          brand: '민음사',
          name: '싯다르타',
          url: 'https://a.test/1',
        ),
        _p(
          id: 'b-3',
          category: 'book',
          source: 'aladin',
          brand: '문학동네',
          name: '싯다르타',
          url: 'https://a.test/2',
        ),
      ]);

      expect(catalog.sellable.length, 2);
    });

    test('대표는 이미지와 구매 주소가 있는 쪽이다', () {
      final ProductCatalog catalog = _catalog(<Product>[
        Product.fromJson(<String, Object?>{
          'id': 'z-no-url',
          'brandName': '민음사',
          'productName': '데미안',
          'category': 'book',
          'categoryLabel': '도서',
          'price': 10000,
          'isDemo': false,
          'source': 'aladin',
        }),
        _p(
          id: 'z-full',
          category: 'book',
          source: 'aladin',
          brand: '민음사',
          name: '데미안',
          url: 'https://a.test/3',
        ),
      ]);

      expect(catalog.sellable.single.id, 'z-full');
      expect(catalog.sellable.single.canOpenStore, isTrue);
    });
  });

  group('홈 노출 몫', () {
    // 도서가 압도적으로 많고 판매처도 한쪽에 쏠린 카탈로그.
    ProductCatalog skewed() => _catalog(<Product>[
      for (int i = 0; i < 200; i += 1)
        _p(
          id: 'aladin-$i',
          category: 'book',
          source: 'aladin',
          brand: '출판사$i',
          originalPrice: 30000,
        ),
      for (int i = 0; i < 60; i += 1)
        _p(
          id: '10x10-$i',
          category: i.isEven ? 'living' : 'stationery',
          source: '10x10',
          brand: '브랜드$i',
          originalPrice: 30000,
        ),
      for (int i = 0; i < 60; i += 1)
        _p(
          id: 'musinsa-$i',
          category: i.isEven ? 'bag' : 'fashion_clothing',
          source: 'musinsa',
          brand: '무신사브랜드$i',
          originalPrice: 30000,
        ),
    ]);

    test('홈 전체에서 도서는 15%를 넘지 않는다', () {
      final List<Product> home = skewed().homeSections().all;

      expect(home, isNotEmpty);
      final int books = home.where((Product p) => p.category == 'book').length;
      expect(books / home.length, lessThanOrEqualTo(0.15));
      // 아예 사라지지는 않는다. 책을 찾는 사람도 홈에서 만날 수 있어야 한다.
      expect(books, greaterThan(0));
    });

    test('판매처는 남은 자리를 나눠 가지는 만큼까지만 차지한다', () {
      // 판매처가 셋인데 그중 하나가 책만 판다면, 그곳은 도서 한도인 15% 까지만
      // 채울 수 있다. 남은 85% 를 두 곳이 나누므로 한 곳의 몫은 42.5% 가 된다.
      // 35% 를 셋이 지키는 것은 합이 100% 에 못 미쳐 어떤 목록으로도 불가능하다.
      final List<Product> home = skewed().homeSections().all;

      for (final String source in <String>['aladin', '10x10', 'musinsa']) {
        final int count = home.where((Product p) => p.source == source).length;
        expect(
          count / home.length,
          lessThanOrEqualTo(0.43),
          reason: '$source 가 홈을 차지했다',
        );
      }
    });

    test('판매처가 넉넉하면 한 곳이 35% 를 넘지 않는다', () {
      // 책만 파는 곳이 없으면 한도가 그대로 걸린다.
      final ProductCatalog wide = _catalog(<Product>[
        for (int i = 0; i < 80; i += 1)
          _p(
            id: 'a-$i',
            category: i.isEven ? 'living' : 'book',
            source: 'a',
            brand: 'A$i',
            originalPrice: 30000,
          ),
        for (int i = 0; i < 80; i += 1)
          _p(
            id: 'b-$i',
            category: i.isEven ? 'bag' : 'beauty',
            source: 'b',
            brand: 'B$i',
            originalPrice: 30000,
          ),
        for (int i = 0; i < 80; i += 1)
          _p(
            id: 'c-$i',
            category: i.isEven ? 'tumbler' : 'candle',
            source: 'c',
            brand: 'C$i',
            originalPrice: 30000,
          ),
      ]);

      final List<Product> home = wide.homeSections().all;
      for (final String source in <String>['a', 'b', 'c']) {
        final int count = home.where((Product p) => p.source == source).length;
        expect(count / home.length, lessThanOrEqualTo(0.35), reason: source);
      }
    });

    test('같은 상품이 여러 줄에 겹쳐 나오지 않는다', () {
      final List<Product> home = skewed().homeSections().all;
      final Set<String> ids = home.map((Product p) => p.id).toSet();

      expect(ids.length, home.length);
    });

    test('도서만 있어도 홈이 비지 않는다', () {
      final ProductCatalog onlyBooks = _catalog(<Product>[
        for (int i = 0; i < 40; i += 1)
          _p(
            id: 'aladin-$i',
            category: 'book',
            source: 'aladin',
            brand: '출판사$i',
            originalPrice: 30000,
          ),
      ]);

      expect(onlyBooks.homeSections().discounted, isNotEmpty);
    });

    test('카테고리 화면에서는 몫을 걸지 않아 책을 모두 볼 수 있다', () {
      // 홈의 한도는 큐레이션에만 쓴다. 탐색을 막지 않는다.
      final List<Product> books = skewed().search('', category: 'book');

      expect(books.length, 200);
    });

    test('같은 카탈로그면 홈은 항상 같은 순서다', () {
      final List<String> first = skewed()
          .homeSections()
          .all
          .map((Product p) => p.id)
          .toList();
      final List<String> second = skewed()
          .homeSections()
          .all
          .map((Product p) => p.id)
          .toList();

      expect(first, second);
    });
  });
}
