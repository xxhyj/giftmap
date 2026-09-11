import '../../gift_finder/domain/gift_intent.dart';
import 'product.dart';

/// 정렬 기준.
enum ProductSort {
  recommended('추천순'),
  priceLow('낮은 가격순'),
  priceHigh('높은 가격순'),
  discount('할인율순');

  const ProductSort(this.label);

  final String label;
}

/// 로컬 Mock 상품 카탈로그.
///
/// 네트워크 없이 메모리 위에서 검색·필터·큐레이션을 수행한다.
/// 모든 결과는 결정론적이다(동점은 상품 id 오름차순).
class ProductCatalog {
  ProductCatalog({
    required this.products,
    required this.version,
    required this.disclaimer,
  });

  final List<Product> products;
  final String version;

  /// 데모 데이터 고지 문구.
  final String disclaimer;

  bool get isEmpty => products.isEmpty;

  Product? byId(String id) {
    for (final Product product in products) {
      if (product.id == id) return product;
    }
    return null;
  }

  List<Product> byIds(Iterable<String> ids) =>
      ids.map(byId).nonNulls.toList(growable: false);

  /// 카탈로그에 존재하는 카테고리 목록(라벨 기준 중복 제거).
  List<({String id, String label})> get categories {
    final Map<String, String> found = <String, String>{};
    for (final Product product in products) {
      found.putIfAbsent(product.category, () => product.categoryLabel);
    }
    final List<({String id, String label})> list = found.entries
        .map((MapEntry<String, String> e) => (id: e.key, label: e.value))
        .toList();
    list.sort(
      (({String id, String label}) a, ({String id, String label}) b) =>
          a.id.compareTo(b.id),
    );
    return list;
  }

  /// 키워드 검색. 대소문자와 공백을 무시하고 부분 일치로 찾는다.
  List<Product> search(
    String rawQuery, {
    String? category,
    BudgetBand? priceRange,
    ProductSort sort = ProductSort.recommended,
  }) {
    final String query = _normalize(rawQuery);
    final List<Product> matched = products.where((Product product) {
      if (category != null && product.category != category) return false;
      if (priceRange != null && !_inBand(product, priceRange)) return false;
      if (query.isEmpty) return true;
      return _normalize(product.searchIndex).contains(query);
    }).toList();

    return _sorted(matched, sort);
  }

  /// 가격 구간으로 거른 목록. 가격을 모르는 상품은 제외한다.
  List<Product> byPriceUnder(int maxPrice, {int limit = 10}) {
    final List<Product> matched = products
        .where((Product p) => p.price != null && p.price! <= maxPrice)
        .toList();
    return _sorted(matched, ProductSort.recommended).take(limit).toList();
  }

  /// 상황별 큐레이션.
  List<Product> byOccasion(GiftSituation situation, {int limit = 10}) {
    final List<Product> matched = products
        .where((Product p) => p.occasions.contains(situation))
        .toList();
    return _sorted(matched, ProductSort.recommended).take(limit).toList();
  }

  /// 관계별 큐레이션.
  List<Product> byRecipient(RelationshipType relationship, {int limit = 10}) {
    final List<Product> matched = products
        .where((Product p) => p.recipientTypes.contains(relationship))
        .toList();
    return _sorted(matched, ProductSort.recommended).take(limit).toList();
  }

  /// 할인 중인 상품.
  List<Product> get discounted => _sorted(
    products.where((Product p) => p.hasDiscount).toList(),
    ProductSort.discount,
  );

  /// 홈의 "지금 많이 찾는 선물" 자리를 채우는 고정 목록.
  /// 랜덤을 쓰지 않아 실행할 때마다 같은 순서를 보여준다.
  List<Product> get popular {
    final List<Product> matched = products
        .where((Product p) => p.occasions.length >= 3)
        .toList();
    return _sorted(matched, ProductSort.recommended).take(10).toList();
  }

  List<Product> _sorted(List<Product> list, ProductSort sort) {
    final List<Product> copy = List<Product>.of(list);
    copy.sort((Product a, Product b) {
      final int primary = switch (sort) {
        ProductSort.recommended => _coverage(b).compareTo(_coverage(a)),
        // 가격을 모르는 상품은 정렬에서 뒤로 보낸다.
        ProductSort.priceLow => a.sortPrice.compareTo(b.sortPrice),
        ProductSort.priceHigh => b.sortPrice.compareTo(a.sortPrice),
        ProductSort.discount => (b.discountRate ?? 0).compareTo(
          a.discountRate ?? 0,
        ),
      };
      return primary != 0 ? primary : a.id.compareTo(b.id);
    });
    return copy;
  }

  /// 추천순의 기준: 다양한 상황·관계를 커버하는 상품이 앞에 온다.
  static int _coverage(Product p) =>
      p.occasions.length * 2 + p.recipientTypes.length;

  static bool _inBand(Product product, BudgetBand band) {
    final int? price = product.price;
    if (price == null) return false;
    final int min = band.min ?? 0;
    final int max = band.max ?? BudgetBand.customMax;
    return price >= min && price <= max;
  }

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'\s+'), '');
}
