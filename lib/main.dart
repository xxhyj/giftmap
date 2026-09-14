import 'package:flutter/material.dart';

import 'app/giftmap_app.dart';
import 'core/config/api_bootstrap.dart';
import 'core/config/api_config.dart';
import 'core/config/supabase_bootstrap.dart';
import 'core/config/supabase_config.dart';
import 'features/products/data/bundled_product_data_source.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 상품을 어디서 읽을지 고른다. 경로는 셋이고 서로 섞이지 않는다.
  // 1. Vercel API  : --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=https://...
  // 2. Supabase 직접: --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...
  // 3. 번들 Mock    : 아무것도 주지 않았을 때
  final ApiConfig apiConfig = ApiConfig.fromEnvironment();
  ApiBootstrap.configure(apiConfig);

  ProductDataSource? source = ApiBootstrap.productDataSource();
  if (source == null) {
    // API 경로가 아니면 예전 경로를 그대로 쓴다(되돌릴 자리).
    await SupabaseBootstrap.ensureInitialized(SupabaseConfig.fromEnvironment());
    source = SupabaseBootstrap.productDataSource();
  }

  runApp(
    GiftmapApp(
      productDataSource: source,
      aiService: ApiBootstrap.aiRecommendationService(),
      searchTrends: ApiBootstrap.searchTrendService(),
    ),
  );
}
