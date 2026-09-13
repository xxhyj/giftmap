import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/products/data/bundled_product_data_source.dart';
import '../../features/products/data/remote_first_product_data_source.dart';
import '../../features/products/data/supabase_product_data_source.dart';
import 'supabase_config.dart';

/// Supabase 연결을 준비한다.
///
/// - `--dart-define` 값이 없으면 아무것도 하지 않고 Mock 데이터로 동작한다.
/// - 초기화가 실패해도 앱을 멈추지 않는다. 상품은 번들 데이터로 채워진다.
abstract final class SupabaseBootstrap {
  static bool _initialized = false;

  /// 연결이 준비됐는지. 앱 시작 후에 의미가 있다.
  static bool get isConnected => _initialized;

  /// `main()`에서 `runApp` 전에 한 번 호출한다.
  static Future<void> ensureInitialized(SupabaseConfig config) async {
    if (_initialized) return;

    if (!config.isConfigured) {
      debugPrint(
        '[Giftmap] SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY 가 없어 '
        '번들 Mock 데이터로 실행합니다.',
      );
      return;
    }
    if (config.looksLikeServiceRoleKey) {
      // 비밀 키가 앱에 들어오는 것을 막는다.
      debugPrint(
        '[Giftmap] service_role 키로 보이는 값이 전달되어 연결을 중단했습니다. '
        'Publishable(anon) 키를 사용하세요.',
      );
      return;
    }

    try {
      await Supabase.initialize(
        url: config.url.trim(),
        publishableKey: config.publishableKey.trim(),
      );
      _initialized = true;
      debugPrint('[Giftmap] Supabase 연결 준비 완료');
    } on Object catch (error) {
      debugPrint('[Giftmap] Supabase 초기화 실패, 번들 데이터로 실행합니다: $error');
    }
  }

  /// 상황에 맞는 상품 데이터 소스를 돌려준다.
  ///
  /// 연결이 준비됐으면 원격 우선(실패 시 번들 fallback), 아니면 번들 전용이다.
  static ProductDataSource productDataSource({
    ProductDataSource fallback = const BundledProductDataSource(),
  }) {
    if (!_initialized) return fallback;
    return RemoteFirstProductDataSource(
      remote: SupabaseProductDataSource(Supabase.instance.client),
      fallback: fallback,
    );
  }

  /// 테스트에서 상태를 초기화할 때 쓴다.
  @visibleForTesting
  static void resetForTest() => _initialized = false;
}
