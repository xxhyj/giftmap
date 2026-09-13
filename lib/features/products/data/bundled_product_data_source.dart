import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/product.dart';
import '../domain/product_catalog.dart';

/// 상품 카탈로그 제공자.
///
/// 구현체: [BundledProductDataSource](로컬 JSON),
/// `SupabaseProductDataSource`(원격), `RemoteFirstProductDataSource`(원격 우선).
abstract interface class ProductDataSource {
  Future<ProductCatalog> load();
}

/// 번들 데모 데이터에 붙는 고지.
const String defaultProductDisclaimer =
    '데모 상품 데이터입니다. 실제 판매 상품이나 실시간 가격이 아닙니다.';

/// 수집한 실제 상품에 붙는 고지.
///
/// 실제 판매 상품이지만 가격·재고는 수집 시점의 값이라 판매처와 다를 수 있다.
/// 데모가 아닌데 "데모 데이터"라고 알리면 사용자를 오해하게 만든다.
const String collectedProductDisclaimer =
    '판매처에 공개된 정보를 옮긴 실제 상품입니다. 가격과 재고는 판매처 기준으로 달라질 수 있습니다.';

/// `lib/data/products.json`을 읽어 카탈로그를 만든다.
///
/// 손상된 상품은 건너뛰고 나머지를 사용한다. 전부 실패하면 빈 카탈로그를
/// 돌려주고 화면이 빈 상태를 표시한다.
final class BundledProductDataSource implements ProductDataSource {
  // 이름 있는 매개변수는 private 이름을 쓸 수 없어 초기화 목록으로 대입한다.
  // ignore: prefer_initializing_formals
  const BundledProductDataSource({AssetBundle? bundle}) : _bundle = bundle;

  static const String asset = 'lib/data/products.json';

  final AssetBundle? _bundle;

  @override
  Future<ProductCatalog> load() async {
    try {
      final String raw = await (_bundle ?? rootBundle).loadString(asset);
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('catalog root must be a JSON object');
      }
      return parseCatalog(decoded);
    } on Object {
      return emptyCatalog;
    }
  }

  /// 테스트와 런타임이 같은 파싱 경로를 쓰도록 공개한다.
  static ProductCatalog parseCatalog(Map<String, Object?> json) {
    final List<Product> products = <Product>[];
    final Object? raw = json['products'];
    if (raw is List) {
      for (final Object? entry in raw) {
        if (entry is! Map<String, Object?>) continue;
        try {
          products.add(Product.fromJson(entry));
        } on FormatException {
          continue;
        }
      }
    }
    final Object? rawSuggestions = json['searchSuggestions'];
    return ProductCatalog(
      products: List<Product>.unmodifiable(products),
      version: json['catalogVersion'] is String
          ? json['catalogVersion']! as String
          : 'unknown',
      disclaimer: json['disclaimer'] is String
          ? json['disclaimer']! as String
          : defaultProductDisclaimer,
      searchSuggestions: rawSuggestions is List
          ? List<String>.unmodifiable(
              rawSuggestions
                  .map((Object? e) => e?.toString())
                  .nonNulls
                  .where((String keyword) => keyword.trim().isNotEmpty),
            )
          : const <String>[],
    );
  }
}

/// 카탈로그를 읽지 못했을 때 쓰는 빈 카탈로그.
final ProductCatalog emptyCatalog = ProductCatalog(
  products: const <Product>[],
  version: 'empty',
  disclaimer: defaultProductDisclaimer,
);
