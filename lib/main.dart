import 'package:flutter/material.dart';

import 'app/giftmap_app.dart';
import 'core/config/api_bootstrap.dart';
import 'core/config/api_config.dart';
import 'features/products/data/bundled_product_data_source.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 상품을 어디서 읽을지 고른다. 경로는 둘뿐이다.
  // 1. Vercel API : --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=https://...
  // 2. 번들 Mock  : 아무것도 주지 않았을 때(테스트가 쓰는 길이기도 하다)
  //
  // 앱은 Supabase 에 직접 붙지 않는다. 상품도 추천도 서버를 거치고,
  // 키는 서버 환경변수에만 있다.
  ApiBootstrap.configure(ApiConfig.fromEnvironment());

  runApp(
    GiftmapApp(
      productDataSource:
          ApiBootstrap.productDataSource() ?? const BundledProductDataSource(),
      aiService: ApiBootstrap.aiRecommendationService(),
      searchTrends: ApiBootstrap.searchTrendService(),
    ),
  );
}
