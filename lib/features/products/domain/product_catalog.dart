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
    this.searchSuggestions = const <String>[],
  });

  final List<Product> products;

  /// 어떤 데이터를 쓰고 있는지 나타낸다(`supabase` 또는 번들 카탈로그 버전).
  final String version;

  /// 데모 데이터 고지 문구.
  final String disclaimer;

  /// 검색 화면의 추천 검색어. 비어 있으면 화면이 기본 목록을 쓴다.
  final List<String> searchSuggestions;

  /// 원격(Supabase)에서 받아온 카탈로그인지.
  bool get isRemote => version == 'supabase';

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
    return interleave(_sorted(matched, ProductSort.recommended), limit: limit);
  }

  /// 상황별 큐레이션.
  List<Product> byOccasion(GiftSituation situation, {int limit = 10}) {
    final List<Product> matched = products
        .where((Product p) => p.occasions.contains(situation))
        .toList();
    return interleave(_sorted(matched, ProductSort.recommended), limit: limit);
  }

  /// 관계별 큐레이션.
  List<Product> byRecipient(RelationshipType relationship, {int limit = 10}) {
    final List<Product> matched = products
        .where((Product p) => p.recipientTypes.contains(relationship))
        .toList();
    return interleave(_sorted(matched, ProductSort.recommended), limit: limit);
  }

  /// 할인 중인 상품.
  List<Product> get discounted => interleave(
    _sorted(
      products.where((Product p) => p.hasDiscount).toList(),
      ProductSort.discount,
    ),
    limit: 20,
  );

  /// 홈의 "지금 많이 찾는 선물" 자리를 채우는 고정 목록.
  /// 랜덤을 쓰지 않아 실행할 때마다 같은 순서를 보여준다.
  List<Product> get popular {
    List<Product> matched = products
        .where((Product p) => p.occasions.length >= 3)
        .toList();
    // 수집 상품은 상황 태그가 2개인 경우가 많다. 비어 보이지 않게 기준을 낮춘다.
    if (matched.length < 10) {
      matched = products.where((Product p) => p.occasions.length >= 2).toList();
    }
    return interleave(_sorted(matched, ProductSort.recommended), limit: 12);
  }

  /// 한 출처·한 분류가 목록을 뒤덮지 않도록 번갈아 뽑는다.
  ///
  /// 수집 상품은 공급원마다 양이 크게 달라(문구가 많은 곳 하나가 대부분)
  /// 그대로 정렬하면 목록이 한쪽으로 쏠린다.
  ///
  /// 두 단계로 섞는다.
  /// 1. 출처 안에서 분류를 번갈아 뽑아 출처별 줄을 만든다.
  /// 2. 그 줄들을 출처끼리 번갈아 가며 합친다.
  ///
  /// 출처를 바깥 고리에 두는 것이 중요하다. 분류를 바깥에 두면 상품이 많은
  /// 출처가 모든 분류를 선점해 앞자리를 다 가져간다.
  /// 순서가 모두 고정이라 같은 카탈로그면 항상 같은 결과가 나온다.
  static List<Product> interleave(List<Product> items, {int? limit}) {
    // 1단계: 출처 → 분류 → 상품
    final Map<String, Map<String, List<Product>>> bySource =
        <String, Map<String, List<Product>>>{};
    for (final Product product in items) {
      final String source = product.source ?? 'bundle';
      bySource
          .putIfAbsent(source, () => <String, List<Product>>{})
          .putIfAbsent(product.category, () => <Product>[])
          .add(product);
    }

    // 출처마다 분류를 번갈아 뽑아 한 줄로 만든다.
    final List<List<Product>> lines = <List<Product>>[];
    for (final String source in bySource.keys.toList()..sort()) {
      final Map<String, List<Product>> byCategory = bySource[source]!;
      final List<String> categories = byCategory.keys.toList()..sort();
      final List<Product> line = <Product>[];
      for (int round = 0; ; round += 1) {
        bool tookAny = false;
        for (final String category in categories) {
          final List<Product> group = byCategory[category]!;
          if (round >= group.length) continue;
          line.add(group[round]);
          tookAny = true;
        }
        if (!tookAny) break;
      }
      lines.add(line);
    }

    // 2단계: 출처별 줄을 번갈아 합친다.
    final List<Product> out = <Product>[];
    final int max = limit ?? items.length;
    for (int round = 0; out.length < max; round += 1) {
      bool tookAny = false;
      for (final List<Product> line in lines) {
        if (round >= line.length) continue;
        out.add(line[round]);
        tookAny = true;
        if (out.length >= max) break;
      }
      if (!tookAny) break;
    }
    return out;
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
