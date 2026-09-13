import 'package:flutter/material.dart';

import 'app/giftmap_app.dart';
import 'core/config/supabase_bootstrap.dart';
import 'core/config/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --dart-define 값이 없으면 조용히 건너뛰고 번들 Mock 데이터로 실행한다.
  await SupabaseBootstrap.ensureInitialized(SupabaseConfig.fromEnvironment());

  runApp(GiftmapApp(productDataSource: SupabaseBootstrap.productDataSource()));
}
