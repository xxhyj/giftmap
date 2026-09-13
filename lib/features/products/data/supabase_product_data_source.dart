import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/product.dart';
import '../domain/product_catalog.dart';
import 'bundled_product_data_source.dart';

/// Supabase에서 상품·카테고리·추천 검색어를 읽어 카탈로그를 만든다.
///
/// 읽기 전용이며 anon(publishable) 키만 사용한다. RLS 정책에 따라
/// `is_active = true`인 행만 내려온다.
final class SupabaseProductDataSource implements ProductDataSource {
  const SupabaseProductDataSource(this._client, {this.realOnly = false});

  final SupabaseClient _client;

  /// true면 수집한 실제 상품(`is_demo = false`)만 읽는다.
  /// 실제 상품 모드에서 데모 데이터가 섞이지 않게 한다.
  final bool realOnly;

  /// 한 번에 가져오는 행 수. 전부 받을 때까지 이어서 요청한다.
  static const int _pageSize = 1000;

  /// 카테고리 라벨을 붙이기 위해 함께 읽는다.
  static const String _productColumns = '''
id, brand_name, product_name, category_id, sub_category,
price, original_price, discount_rate, image_asset, image_url, product_url,
in_stock, availability, last_verified_at, source,
tags, occasions, recipient_types, gender_target, age_range,
price_range, recommendation_keywords, description,
recommendation_reason, is_demo, sort_order, created_at
''';

  @override
  Future<ProductCatalog> load() async {
    final List<Map<String, dynamic>> categoryRows = await _client
        .from('categories')
        .select('id, label')
        .order('sort_order');

    final Map<String, String> labels = <String, String>{
      for (final Map<String, dynamic> row in categoryRows)
        row['id'].toString(): row['label']?.toString() ?? row['id'].toString(),
    };

    final List<Map<String, dynamic>> productRows = await _loadProductRows();

    final List<Product> products = <Product>[];
    for (final Map<String, dynamic> row in productRows) {
      try {
        products.add(Product.fromJson(_toProductJson(row, labels)));
      } on FormatException {
        // 한 상품이 잘못돼도 나머지는 보여준다.
        continue;
      }
    }

    final List<Map<String, dynamic>> suggestionRows = await _client
        .from('search_suggestions')
        .select('keyword')
        .order('sort_order');

    return ProductCatalog(
      products: List<Product>.unmodifiable(products),
      version: 'supabase',
      disclaimer: defaultProductDisclaimer,
      searchSuggestions: List<String>.unmodifiable(
        suggestionRows
            .map((Map<String, dynamic> row) => row['keyword']?.toString())
            .nonNulls
            .where((String keyword) => keyword.trim().isNotEmpty),
      ),
    );
  }

  /// 상품을 페이지 단위로 끝까지 읽는다.
  ///
  /// Supabase는 한 번에 돌려주는 행 수에 상한이 있어, 상품이 많아지면
  /// 나눠 받아야 뒤쪽 상품이 사라지지 않는다.
  Future<List<Map<String, dynamic>>> _loadProductRows() async {
    final List<Map<String, dynamic>> all = <Map<String, dynamic>>[];
    for (int from = 0; ; from += _pageSize) {
      PostgrestFilterBuilder<List<Map<String, dynamic>>> query = _client
          .from('products')
          .select(_productColumns);
      if (realOnly) query = query.eq('is_demo', false);

      final List<Map<String, dynamic>> page = await query
          .order('sort_order')
          .order('id')
          .range(from, from + _pageSize - 1);

      all.addAll(page);
      if (page.length < _pageSize) return all;
    }
  }

  /// Supabase의 snake_case 행을 앱 모델이 읽는 형태로 바꾼다.
  static Map<String, Object?> _toProductJson(
    Map<String, dynamic> row,
    Map<String, String> categoryLabels,
  ) {
    final String? categoryId = row['category_id']?.toString();
    return <String, Object?>{
      'id': row['id'],
      'brandName': row['brand_name'],
      'productName': row['product_name'],
      'category': categoryId,
      'categoryLabel': categoryId == null ? null : categoryLabels[categoryId],
      'subCategory': row['sub_category'],
      'price': row['price'],
      'originalPrice': row['original_price'],
      'discountRate': row['discount_rate'],
      'imageAsset': row['image_asset'],
      'imageUrl': row['image_url'],
      'inStock': row['in_stock'],
      'availability': row['availability'],
      'lastVerifiedAt': row['last_verified_at'],
      'source': row['source'],
      'productUrl': row['product_url'],
      'tags': _stringList(row['tags']),
      'occasions': _stringList(row['occasions']),
      'recipientTypes': _stringList(row['recipient_types']),
      'genderTarget': row['gender_target'],
      'ageRange': _stringList(row['age_range']),
      'priceRange': row['price_range'],
      'recommendationKeywords': _stringList(row['recommendation_keywords']),
      'description': row['description'],
      'recommendationReason': row['recommendation_reason'],
      'isDemo': row['is_demo'],
      'createdAt': row['created_at'],
    };
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const <String>[];
    return value
        .map((Object? e) => e?.toString())
        .nonNulls
        .toList(growable: false);
  }
}
