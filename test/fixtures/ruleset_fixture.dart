import 'dart:convert';
import 'dart:io';

import 'package:giftmap/features/gift_finder/data/bundled_category_data_source.dart';
import 'package:giftmap/features/gift_finder/domain/gift_ruleset.dart';
import 'package:giftmap/features/products/data/bundled_product_data_source.dart';
import 'package:giftmap/features/products/domain/product_catalog.dart';

Map<String, Object?> _read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

/// 실제 번들 JSON을 파일에서 직접 읽어 테스트용 ruleset을 만든다.
/// 테스트가 출시 데이터와 같은 내용을 검증하도록 별도 fixture를 두지 않는다.
GiftRuleset loadBundledRuleset() {
  return GiftRuleset.fromJson(
    categoriesJson: _read('lib/data/gift_categories.json'),
    rulesJson: _read('lib/data/risk_rules.json'),
    queriesJson: _read('lib/data/search_queries.json'),
  );
}

/// 실제 번들 상품 카탈로그.
ProductCatalog loadBundledCatalog() =>
    BundledProductDataSource.parseCatalog(_read('lib/data/products.json'));

/// 위젯 테스트용 데이터 소스.
///
/// `rootBundle`은 테스트 간 Future를 캐시해 두 번째 테스트부터 부팅이 끝나지 않으므로,
/// 위젯 테스트에서는 번들 대신 같은 JSON을 파일에서 읽는 이 구현을 주입한다.
final class FixtureCategoryDataSource implements CategoryDataSource {
  const FixtureCategoryDataSource();

  @override
  Future<GiftRuleset> load() async => loadBundledRuleset();
}

/// 위젯 테스트용 상품 데이터 소스.
final class FixtureProductDataSource implements ProductDataSource {
  const FixtureProductDataSource();

  @override
  Future<ProductCatalog> load() async => loadBundledCatalog();
}
