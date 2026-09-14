import '../../../core/config/api_config.dart';
import '../../../core/net/json_http_client.dart';
import '../domain/product.dart';
import '../domain/product_catalog.dart';
import 'bundled_product_data_source.dart';

/// Vercel API 에서 상품을 읽는 데이터 소스.
///
/// 서버가 이미 앱이 읽는 모양(camelCase)으로 바꿔 주므로 여기서는 받은 것을
/// [Product.fromJson]에 넘기기만 한다. 상품 하나가 잘못돼도 나머지는 보여 준다.
///
/// Supabase 를 직접 읽는 [SupabaseProductDataSource] 와 나란히 존재하며 서로
/// 건드리지 않는다. 어느 쪽을 쓸지는 `ApiBootstrap` 이 정한다.
final class ApiProductDataSource implements PagedProductDataSource {
  const ApiProductDataSource(this._config, this._client);

  final ApiConfig _config;
  final JsonHttpClient _client;

  /// 서버가 한 번에 내줄 수 있는 최대치. 전량 로드에 쓴다.
  static const int _fullPageSize = 200;

  @override
  Future<ProductPage> loadPage({
    required int offset,
    required int limit,
  }) async {
    // 서버는 쪽 번호로 말한다. 앱의 offset 을 쪽으로 바꿔 부른다.
    final int page = limit <= 0 ? 1 : (offset ~/ limit) + 1;
    final Object? body = await _client.getJson(
      _config.resolve('/api/products', <String, String>{
        'page': '$page',
        'limit': '$limit',
      }),
    );
    return _toPage(body);
  }

  /// 전량이 필요한 자리(테스트·예전 경로)를 위해 끝까지 이어 받는다.
  @override
  Future<ProductCatalog> load() async {
    final List<Product> all = <Product>[];
    String disclaimer = collectedProductDisclaimer;
    List<String> suggestions = const <String>[];

    for (int offset = 0; ; offset += _fullPageSize) {
      final ProductPage page = await loadPage(
        offset: offset,
        limit: _fullPageSize,
      );
      all.addAll(page.products);
      if (offset == 0) {
        disclaimer = page.disclaimer;
        suggestions = page.searchSuggestions;
      }
      if (!page.hasMore || page.products.isEmpty) break;
    }

    return ProductCatalog(
      products: List<Product>.unmodifiable(all),
      version: 'api',
      disclaimer: disclaimer,
      searchSuggestions: suggestions,
    );
  }

  /// 상품 하나. 없으면 null.
  ///
  /// 목록에 아직 안 실린 상품(찜·최근 본 상품)을 한 건만 확인할 때 쓴다.
  Future<Product?> fetchProduct(String id) async {
    final Object? body;
    try {
      body = await _client.getJson(_config.resolve('/api/products/$id'));
    } on ApiException catch (error) {
      // 없는 상품은 오류가 아니다. 지워졌거나 아직 안 들어온 것이다.
      if (error.statusCode == 404) return null;
      rethrow;
    }
    if (body is! Map) return null;
    final Object? product = body['product'];
    if (product is! Map) return null;
    return _toProduct(product);
  }

  ProductPage _toPage(Object? body) {
    if (body is! Map) {
      throw const ApiException('상품 목록을 읽지 못했습니다.');
    }
    final Object? rawProducts = body['products'];
    if (rawProducts is! List) {
      throw const ApiException('상품 목록이 비어 있는 모양입니다.');
    }

    final List<Product> products = <Product>[];
    for (final Object? item in rawProducts) {
      if (item is! Map) continue;
      final Product? product = _toProduct(item);
      if (product != null) products.add(product);
    }

    return ProductPage(
      products: List<Product>.unmodifiable(products),
      hasMore: body['hasMore'] == true,
      version: 'api',
      disclaimer: body['disclaimer']?.toString() ?? '',
      searchSuggestions: _stringList(body['searchSuggestions']),
    );
  }

  static Product? _toProduct(Map<Object?, Object?> json) {
    try {
      return Product.fromJson(<String, Object?>{
        for (final MapEntry<Object?, Object?> e in json.entries)
          e.key.toString(): e.value,
      });
    } on FormatException {
      // 한 상품이 잘못돼도 나머지는 보여 준다.
      return null;
    }
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const <String>[];
    return List<String>.unmodifiable(
      value
          .map((Object? e) => e?.toString())
          .nonNulls
          .where((String s) => s.isNotEmpty),
    );
  }
}
