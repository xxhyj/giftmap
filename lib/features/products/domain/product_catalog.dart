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

/// 한 줄 안에서 같은 판매처·같은 분류가 차지할 수 있는 몫.
///
/// 수집한 상품은 판매처마다 양이 크게 다르다. 책만 파는 곳 하나가 상품 수로는
/// 가장 많아, 그대로 뽑으면 홈이 책으로 뒤덮인다. 그렇다고 빼 버리면 책을
/// 찾는 사람이 못 본다. 그래서 홈에서는 몫을 정해 두고, 카테고리 화면에서는
/// 몫을 걸지 않아 책을 전부 탐색할 수 있게 한다.
class ExposureQuota {
  const ExposureQuota({
    required this.maxSourceShare,
    required this.maxCategoryShare,
    this.cappedCategories = const <String>{},
  });

  /// 한도를 걸지 않는다(카테고리·검색 화면).
  const ExposureQuota.none()
    : maxSourceShare = 1,
      maxCategoryShare = 1,
      cappedCategories = const <String>{};

  /// 홈에 쓰는 몫. 한 판매처 35%, 도서 15%.
  static const ExposureQuota home = ExposureQuota(
    maxSourceShare: 0.35,
    maxCategoryShare: 0.15,
    cappedCategories: <String>{'book'},
  );

  final double maxSourceShare;
  final double maxCategoryShare;

  /// 몫을 거는 분류. 비어 있으면 모든 분류에 [maxCategoryShare]를 적용한다.
  final Set<String> cappedCategories;

  /// 있는 것보다 많은 다양성을 요구할 수는 없다.
  ///
  /// 판매처가 둘뿐인데 한 곳을 35%로 묶으면 줄의 70%만 채워지고,
  /// 책만 있는 목록에 도서 한도를 걸면 줄이 통째로 사라진다.
  /// 목록이 실제로 가진 만큼으로 한도를 풀어 준다.
  ExposureQuota relaxedForPool(List<Product> pool, {required int sourceCount}) {
    if (pool.isEmpty) return this;
    final bool everythingCapped =
        cappedCategories.isNotEmpty &&
        pool.every((Product p) => cappedCategories.contains(p.category));

    // 어떤 판매처가 한도 걸린 분류만 판다면(알라딘은 책만 판다) 그곳은
    // 분류 한도까지밖에 못 채운다. 나머지 자리는 다른 판매처가 메워야 하므로
    // 판매처 한도를 그만큼 풀어 주지 않으면 어떤 목록도 조건을 만족할 수 없고,
    // 한도를 지키려다 홈이 텅 빈다.
    int cappedSources = 0;
    final Map<String, List<Product>> bySource = <String, List<Product>>{};
    for (final Product product in pool) {
      bySource
          .putIfAbsent(product.source ?? 'bundle', () => <Product>[])
          .add(product);
    }
    for (final List<Product> group in bySource.values) {
      if (group.every((Product p) => cappedCategories.contains(p.category))) {
        cappedSources += 1;
      }
    }
    final int free = sourceCount - cappedSources;
    final double neededPerFreeSource = free <= 0
        ? 1
        : (1 - maxCategoryShare * cappedSources) / free;

    double sourceShare = maxSourceShare;
    if (sourceCount > 0 && sourceShare < 1 / sourceCount) {
      sourceShare = 1 / sourceCount;
    }
    if (!everythingCapped && sourceShare < neededPerFreeSource) {
      sourceShare = neededPerFreeSource;
    }
    if (sourceShare > 1) sourceShare = 1;

    return ExposureQuota(
      maxSourceShare: sourceShare,
      maxCategoryShare: everythingCapped ? 1 : maxCategoryShare,
      cappedCategories: cappedCategories,
    );
  }

  ExposureQuota relaxedFor({
    required int sourceCount,
    required bool everythingCapped,
  }) => ExposureQuota(
    maxSourceShare: sourceCount <= 0
        ? 1
        : (maxSourceShare < 1 / sourceCount ? 1 / sourceCount : maxSourceShare),
    maxCategoryShare: everythingCapped ? 1 : maxCategoryShare,
    cappedCategories: cappedCategories,
  );

  /// [total]은 지금까지 뽑은 수에 이번 하나를 더한 값이다.
  ///
  /// 줄 전체 길이가 아니라 그때그때의 길이로 보는 이유는, 한도에 걸려 줄이
  /// 짧아지면 남은 상품의 비중이 도로 올라가기 때문이다.
  bool allows({
    required String source,
    required String category,
    required int takenBySource,
    required int takenByCategory,
    required int total,
  }) {
    if (takenBySource >= _cap(maxSourceShare, total)) return false;
    final bool capped =
        cappedCategories.isEmpty || cappedCategories.contains(category);
    if (capped && takenByCategory >= _cap(maxCategoryShare, total)) {
      return false;
    }
    return true;
  }

  /// 몫이 아주 작은 줄에서도 한 자리는 남긴다. 아예 사라지면 탐색이 끊긴다.
  static int _cap(double share, int total) {
    if (share >= 1) return total;
    final int cap = (total * share).floor();
    return cap < 1 ? 1 : cap;
  }
}

/// 지금까지 몇 개를 어디에서 뽑았는지 세는 장부.
///
/// 홈은 줄이 여섯이라 줄마다 따로 세면 "홈 전체에서 15%" 같은 약속을 지킬 수
/// 없다. 장부 하나를 여섯 줄이 함께 쓴다.
class ExposureTally {
  final Map<String, int> bySource = <String, int>{};
  final Map<String, int> byCategory = <String, int>{};
  int placed = 0;

  void record(Product product) {
    final String source = product.source ?? 'bundle';
    bySource[source] = (bySource[source] ?? 0) + 1;
    byCategory[product.category] = (byCategory[product.category] ?? 0) + 1;
    placed += 1;
  }
}

/// 홈에 깔리는 줄들. 한 상품은 한 줄에만 들어간다.
class HomeSections {
  const HomeSections({
    required this.discounted,
    required this.recommended,
    required this.affordable,
    required this.forFriend,
    required this.housewarming,
    required this.light,
  });

  final List<Product> discounted;
  final List<Product> recommended;
  final List<Product> affordable;
  final List<Product> forFriend;
  final List<Product> housewarming;
  final List<Product> light;

  /// 홈에 실제로 깔리는 상품 전부(줄 순서대로).
  List<Product> get all => <Product>[
    ...discounted,
    ...recommended,
    ...affordable,
    ...forFriend,
    ...housewarming,
    ...light,
  ];
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

  /// 화면에 내보낼 상품.
  ///
  /// 품절이 확인된 상품은 홈·검색·카테고리·추천에서 뺀다. 행을 지우지는 않아
  /// 찜·최근 본 상품에서는 [byId]로 그대로 찾을 수 있고 품절 표시가 붙는다.
  late final List<Product> sellable = _dedupe(
    products.where((Product p) => p.isSellable),
  );

  /// 같은 상품을 가리키는 카드를 하나로 합친다.
  ///
  /// 판매처가 다르거나(같은 책을 두 곳에서 판다), 같은 판매처가 주소를 두 벌
  /// 갖고 있으면 목록에 같은 상품이 여러 장 깔린다. 대표 한 장만 남기고
  /// 나머지는 [offersOf]로 찾을 수 있게 둔다.
  ///
  /// 대표는 이미지와 구매 주소가 모두 있는 것을 먼저 고르고, 그다음은 상품
  /// id 오름차순이라 실행할 때마다 같은 카드가 남는다.
  List<Product> _dedupe(Iterable<Product> input) {
    // 열쇠를 하나라도 공유하면 같은 상품으로 묶는다. 판매처가 다르면 주소는
    // 다르지만 브랜드·상품명이 같고, 같은 판매처라면 주소가 같다.
    final Map<String, String> groupOfKey = <String, String>{};
    final Map<String, List<Product>> groups = <String, List<Product>>{};
    for (final Product product in input) {
      final List<String> keys = keysOf(product);
      final String group =
          keys.map((String key) => groupOfKey[key]).nonNulls.firstOrNull ??
          keys.first;
      for (final String key in keys) {
        groupOfKey[key] = group;
      }
      groups.putIfAbsent(group, () => <Product>[]).add(product);
    }
    final List<Product> out = <Product>[];
    for (final MapEntry<String, List<Product>> entry in groups.entries) {
      final List<Product> group = List<Product>.of(entry.value)
        ..sort((Product a, Product b) {
          final int rank = _representativeRank(a)
              .compareTo(_representativeRank(b));
          return rank != 0 ? rank : a.id.compareTo(b.id);
        });
      out.add(group.first);
      if (group.length > 1) {
        final List<Product> offers = List<Product>.unmodifiable(group);
        for (final String key in keysOf(group.first)) {
          _offers[key] = offers;
        }
      }
    }
    out.sort((Product a, Product b) => a.id.compareTo(b.id));
    return List<Product>.unmodifiable(out);
  }

  /// 합쳐진 상품의 판매처별 정보. 대표 카드도 첫 번째로 들어 있다.
  final Map<String, List<Product>> _offers = <String, List<Product>>{};

  /// [product]와 같은 상품을 파는 곳들. 합쳐진 것이 없으면 자기 자신 하나다.
  List<Product> offersOf(Product product) {
    for (final String key in keysOf(product)) {
      final List<Product>? found = _offers[key];
      if (found != null) return found;
    }
    return <Product>[product];
  }

  /// 대표로 세우기 좋은 순서(작을수록 먼저). 보여 줄 수 있는 카드를 앞세운다.
  static int _representativeRank(Product p) {
    int rank = 0;
    if (p.imageUrl == null && p.imageAsset == null) rank += 4;
    if (!p.canOpenStore) rank += 2;
    if (p.price == null) rank += 1;
    return rank;
  }

  /// 같은 상품인지 가리는 열쇠.
  ///
  /// 판매처가 붙인 상품 번호가 같으면 같은 상품이고, 그렇지 않으면 브랜드와
  /// 상품명을 정규화해 비교한다. 책은 같은 제목이라도 출판사·번역이 다르면
  /// 다른 상품이므로 브랜드를 함께 본다.
  static List<String> keysOf(Product product) {
    final String url = _canonicalUrl(product.productUrl);
    final String brand = _key(product.brandName ?? '');
    final String name = _key(product.productName);
    return <String>[
      if (url.isNotEmpty) 'url:$url',
      if (name.isNotEmpty) 'name:$brand|$name',
    ];
  }

  /// 대표 열쇠 하나. 기록·비교용이며 묶을 때는 [keysOf]를 모두 본다.
  static String canonicalKey(Product product) =>
      keysOf(product).firstOrNull ?? 'id:${product.id}';

  /// 주소에서 상품을 가리키는 부분만 남긴다(추적 파라미터·호스트 표기 차이 제거).
  static String _canonicalUrl(String? raw) {
    if (raw == null) return '';
    final Uri? uri = Uri.tryParse(raw);
    if (uri == null || uri.host.isEmpty) return '';
    final String host = uri.host.toLowerCase().replaceFirst(
      RegExp(r'^(www|m|mobile)\.'),
      '',
    );
    final Map<String, String> kept = <String, String>{
      for (final MapEntry<String, String> e in uri.queryParameters.entries)
        if (!_trackingParams.contains(e.key.toLowerCase()))
          e.key.toLowerCase(): e.value,
    };
    final List<String> pairs = kept.keys.toList()..sort();
    final String query = pairs
        .map((String k) => '$k=${kept[k]}')
        .join('&')
        .toLowerCase();
    final String path = uri.path.toLowerCase().replaceAll(RegExp(r'/+$'), '');
    return query.isEmpty ? '$host$path' : '$host$path?$query';
  }

  static const Set<String> _trackingParams = <String>{
    'utm_source',
    'utm_medium',
    'utm_campaign',
    'utm_term',
    'utm_content',
    'ref',
    'reffer',
    'referer',
    'referrer',
    'from',
    'gclid',
    'fbclid',
  };

  static String _key(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^0-9a-z가-힣]'), '');

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
  /// 품절만 남은 카테고리는 고를 수 없으므로 보여 주지 않는다.
  List<({String id, String label})> get categories {
    final Map<String, String> found = <String, String>{};
    for (final Product product in sellable) {
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
    final List<Product> matched = sellable.where((Product product) {
      if (category != null && product.category != category) return false;
      if (priceRange != null && !_inBand(product, priceRange)) return false;
      if (query.isEmpty) return true;
      return _normalize(product.searchIndex).contains(query);
    }).toList();

    return _sorted(matched, sort);
  }

  /// 가격 구간으로 거른 목록. 가격을 모르는 상품은 제외한다.
  List<Product> byPriceUnder(int maxPrice, {int limit = 10}) {
    final List<Product> matched = sellable
        .where((Product p) => p.price != null && p.price! <= maxPrice)
        .toList();
    return interleave(_sorted(matched, ProductSort.recommended), limit: limit);
  }

  /// 상황별 큐레이션.
  List<Product> byOccasion(GiftSituation situation, {int limit = 10}) {
    final List<Product> matched = sellable
        .where((Product p) => p.occasions.contains(situation))
        .toList();
    return interleave(_sorted(matched, ProductSort.recommended), limit: limit);
  }

  /// 관계별 큐레이션.
  List<Product> byRecipient(RelationshipType relationship, {int limit = 10}) {
    final List<Product> matched = sellable
        .where((Product p) => p.recipientTypes.contains(relationship))
        .toList();
    return interleave(_sorted(matched, ProductSort.recommended), limit: limit);
  }

  /// 할인 중인 상품.
  List<Product> get discounted => interleave(
    _sorted(
      sellable.where((Product p) => p.hasDiscount).toList(),
      ProductSort.discount,
    ),
    limit: 20,
  );

  /// 홈의 "지금 많이 찾는 선물" 자리를 채우는 고정 목록.
  /// 랜덤을 쓰지 않아 실행할 때마다 같은 순서를 보여준다.
  List<Product> get popular {
    List<Product> matched = sellable
        .where((Product p) => p.occasions.length >= 3)
        .toList();
    // 수집 상품은 상황 태그가 2개인 경우가 많다. 비어 보이지 않게 기준을 낮춘다.
    if (matched.length < 10) {
      matched = sellable.where((Product p) => p.occasions.length >= 2).toList();
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
  static List<Product> interleave(
    List<Product> items, {
    int? limit,
    ExposureQuota quota = const ExposureQuota.none(),
    ExposureTally? tally,
  }) {
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

    // 목록이 가진 다양성에 맞춰 한도를 푼다.
    // 장부를 함께 쓰는 경우에는 부르는 쪽이 이미 풀어 둔 한도를 그대로 쓴다.
    final ExposureQuota effective = tally != null
        ? quota
        : quota.relaxedForPool(items, sourceCount: bySource.length);

    // 2단계: 출처별 줄을 번갈아 합치되 한도를 넘는 것은 미뤄 둔다.
    final List<Product> out = <Product>[];
    final List<Product> deferred = <Product>[];
    final int max = limit ?? items.length;
    final ExposureTally counts = tally ?? ExposureTally();

    for (int round = 0; out.length < max; round += 1) {
      bool tookAny = false;
      for (final List<Product> line in lines) {
        if (round >= line.length) continue;
        tookAny = true;
        final Product product = line[round];
        final String source = product.source ?? 'bundle';
        if (effective.allows(
          source: source,
          category: product.category,
          takenBySource: counts.bySource[source] ?? 0,
          takenByCategory: counts.byCategory[product.category] ?? 0,
          total: tally == null ? max : counts.placed + max,
        )) {
          out.add(product);
          counts.record(product);
          if (out.length >= max) break;
        } else {
          // 한도에 걸린 상품은 버리지 않는다. 다른 상품이 모자라면 다시 쓴다.
          deferred.add(product);
        }
      }
      if (!tookAny) break;
    }

    // 한도를 지키느라 줄이 통째로 비면 탐색이 끊긴다. 그때만 미뤄 둔 것으로 채운다.
    // 한 칸이라도 채웠다면 짧은 줄로 두고 한도를 지킨다.
    // 장부를 함께 쓰는 홈에서는 이 구제를 쓰지 않는다. 뒤쪽 줄에 한 분류만
    // 남는 일이 흔한데, 그때마다 채워 넣으면 홈 전체 한도가 무너진다.
    if (out.isEmpty && tally == null) {
      for (final Product product in deferred) {
        if (out.length >= max) break;
        out.add(product);
        counts.record(product);
      }
    }
    return out;
  }

  /// 홈에 깔리는 줄들을 한 번에 만든다.
  ///
  /// 줄마다 따로 뽑으면 같은 상품이 여러 줄에 겹쳐 나와 홈이 몇 개 상품만
  /// 반복하는 것처럼 보인다. 앞줄에 쓴 상품을 기억해 두고 다음 줄에서 뺀다.
  /// 줄마다 [ExposureQuota.home]을 적용해 한 분류·한 판매처가 홈을 뒤덮지 않게 한다.
  HomeSections homeSections() {
    final Set<String> used = <String>{};
    // 한도는 홈 전체를 기준으로 한 번만 정하고 여섯 줄이 함께 쓴다.
    final ExposureTally tally = ExposureTally();
    final ExposureQuota quota = ExposureQuota.home.relaxedForPool(
      sellable,
      sourceCount: sellable
          .map((Product p) => p.source ?? 'bundle')
          .toSet()
          .length,
    );

    List<Product> take(
      Iterable<Product> pool, {
      required int limit,
      ProductSort sort = ProductSort.recommended,
    }) {
      final List<Product> fresh = pool
          .where((Product p) => !used.contains(p.id))
          .toList();
      final List<Product> picked = interleave(
        _sorted(fresh, sort),
        limit: limit,
        quota: quota,
        tally: tally,
      );
      used.addAll(picked.map((Product p) => p.id));
      return List<Product>.unmodifiable(picked);
    }

    final HomeSections sections = HomeSections(
      discounted: take(
        sellable.where((Product p) => p.hasDiscount),
        limit: 20,
        sort: ProductSort.discount,
      ),
      recommended: take(_popularPool, limit: 12),
      affordable: take(
        sellable.where((Product p) => p.price != null && p.price! <= 50000),
        limit: 12,
      ),
      forFriend: take(
        sellable.where(
          (Product p) => p.recipientTypes.contains(RelationshipType.friend),
        ),
        limit: 10,
      ),
      housewarming: take(
        sellable.where(
          (Product p) => p.occasions.contains(GiftSituation.housewarming),
        ),
        limit: 10,
      ),
      light: take(
        sellable.where((Product p) => p.price != null && p.price! <= 30000),
        limit: 12,
      ),
    );
    return _trimToQuota(sections, quota);
  }

  /// 줄을 다 만든 뒤 홈 전체 비율을 다시 재고 넘치는 만큼 덜어 낸다.
  ///
  /// 뽑는 동안에는 줄이 얼마나 채워질지 알 수 없다. 한도에 걸려 줄이 짧아지면
  /// 남은 상품의 비중이 도로 올라가므로, 다 만든 뒤에 넘친 쪽의 마지막 상품부터
  /// 덜어 낸다. 덜어 낼 때마다 전체 수도 함께 줄어 반드시 끝난다.
  static HomeSections _trimToQuota(HomeSections sections, ExposureQuota quota) {
    final List<List<Product>> rows = <List<Product>>[
      List<Product>.of(sections.discounted),
      List<Product>.of(sections.recommended),
      List<Product>.of(sections.affordable),
      List<Product>.of(sections.forFriend),
      List<Product>.of(sections.housewarming),
      List<Product>.of(sections.light),
    ];

    for (;;) {
      final ExposureTally tally = ExposureTally();
      for (final List<Product> row in rows) {
        for (final Product product in row) {
          tally.record(product);
        }
      }
      if (tally.placed == 0) break;

      final String? over = _overflowingKey(tally, quota);
      if (over == null) break;
      if (!_removeLast(rows, over)) break;
    }

    return HomeSections(
      discounted: List<Product>.unmodifiable(rows[0]),
      recommended: List<Product>.unmodifiable(rows[1]),
      affordable: List<Product>.unmodifiable(rows[2]),
      forFriend: List<Product>.unmodifiable(rows[3]),
      housewarming: List<Product>.unmodifiable(rows[4]),
      light: List<Product>.unmodifiable(rows[5]),
    );
  }

  /// 한도를 넘은 곳. `source:<이름>` 또는 `category:<이름>` 형태로 돌려준다.
  ///
  /// 여기서는 몫을 실수 그대로 비교한다. 뽑을 때처럼 내림한 칸 수로 보면
  /// 세 판매처의 몫이 전체보다 작아져(내림 때문에) 누군가는 늘 한도를 넘은 것이
  /// 되고, 덜어 내기가 끝나지 않는다.
  /// 한 개짜리는 덜어 내지 않는다. 그 분류·판매처가 홈에서 아예 사라진다.
  static String? _overflowingKey(ExposureTally tally, ExposureQuota quota) {
    bool exceeds(int count, double share) =>
        count > 1 && count > share * tally.placed;

    for (final MapEntry<String, int> e in tally.bySource.entries) {
      if (exceeds(e.value, quota.maxSourceShare)) return 'source:${e.key}';
    }
    for (final MapEntry<String, int> e in tally.byCategory.entries) {
      final bool capped =
          quota.cappedCategories.isEmpty ||
          quota.cappedCategories.contains(e.key);
      if (capped && exceeds(e.value, quota.maxCategoryShare)) {
        return 'category:${e.key}';
      }
    }
    return null;
  }

  /// 넘친 쪽의 상품 하나를 덜어 낸다.
  ///
  /// 가장 긴 줄에서 덜어 낸다. 뒤에서부터 덜어 내면 마지막 줄들이 통째로
  /// 비어 홈에서 사라진다. 줄 안에서는 마지막 상품을 뺀다(앞자리가 유지된다).
  static bool _removeLast(List<List<Product>> rows, String key) {
    final List<String> parts = key.split(':');
    bool matches(Product p) => parts.first == 'source'
        ? (p.source ?? 'bundle') == parts.last
        : p.category == parts.last;

    int bestRow = -1;
    int bestIndex = -1;
    for (int r = 0; r < rows.length; r += 1) {
      if (bestRow >= 0 && rows[r].length <= rows[bestRow].length) continue;
      for (int i = rows[r].length - 1; i >= 0; i -= 1) {
        if (matches(rows[r][i])) {
          bestRow = r;
          bestIndex = i;
          break;
        }
      }
    }
    if (bestRow < 0) return false;
    rows[bestRow].removeAt(bestIndex);
    return true;
  }

  List<Product> get _popularPool {
    final List<Product> wide = sellable
        .where((Product p) => p.occasions.length >= 3)
        .toList();
    // 수집 상품은 상황 태그가 2개인 경우가 많다. 비어 보이지 않게 기준을 낮춘다.
    if (wide.length >= 10) return wide;
    return sellable.where((Product p) => p.occasions.length >= 2).toList();
  }

  List<Product> _sorted(List<Product> list, ProductSort sort) {
    final List<Product> copy = List<Product>.of(list);
    copy.sort((Product a, Product b) {
      // 품절이 확인된 상품은 어떤 정렬에서든 뒤로 보낸다.
      // 숨기지는 않는다. 공급원이 재고를 알려주지 않은 상품(null)은 그대로 둔다.
      if (a.isSoldOut != b.isSoldOut) return a.isSoldOut ? 1 : -1;

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
