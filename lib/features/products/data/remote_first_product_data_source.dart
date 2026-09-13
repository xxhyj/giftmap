import 'package:flutter/foundation.dart';

import '../domain/product_catalog.dart';
import 'bundled_product_data_source.dart';

/// 원격을 먼저 시도하고, 실패하면 번들 Mock 데이터로 되돌아간다.
///
/// 원격이 비어 있거나(테이블이 아직 비었거나) 오류가 나도 앱은 늘 동작한다.
/// 어떤 데이터를 쓰고 있는지는 [ProductCatalog.version]으로 알 수 있다.
final class RemoteFirstProductDataSource implements ProductDataSource {
  const RemoteFirstProductDataSource({
    required this.remote,
    required this.fallback,
    this.timeout = const Duration(seconds: 6),
  });

  final ProductDataSource remote;
  final ProductDataSource fallback;

  /// 원격이 응답하지 않을 때 기다리는 시간.
  final Duration timeout;

  @override
  Future<ProductCatalog> load() async {
    try {
      final ProductCatalog catalog = await remote.load().timeout(timeout);
      if (catalog.products.isNotEmpty) return catalog;
      debugPrint('[Giftmap] 원격 상품이 비어 있어 번들 데이터를 사용합니다.');
    } on Object catch (error) {
      debugPrint('[Giftmap] 원격 상품을 불러오지 못해 번들 데이터를 사용합니다: $error');
    }
    return fallback.load();
  }
}
