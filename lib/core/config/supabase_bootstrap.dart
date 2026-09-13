import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/gift_finder/data/ai_recommendation_service.dart';
import '../../features/products/data/bundled_product_data_source.dart';
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
  /// - 연결됨(실제 상품 모드): Supabase의 실제 상품만 읽는다.
  ///   실패하면 데모로 감추지 않고 오류를 그대로 올려 재시도 화면을 띄운다.
  /// - 연결 안 됨(데모 모드): 번들 Mock 데이터를 읽는다.
  static ProductDataSource productDataSource({
    ProductDataSource fallback = const BundledProductDataSource(),
  }) {
    if (!_initialized) return fallback;
    return SupabaseProductDataSource(Supabase.instance.client, realOnly: true);
  }

  /// 실제 상품 모드인지. 데모 상품과 Mock fallback을 감출지 판단에 쓴다.
  static bool get isRealProductMode => _initialized;

  /// 서버가 실제 상품 중에서 골라 주는 추천.
  ///
  /// OpenAI 호출은 Edge Function 안에서만 일어나고 앱에는 키가 없다.
  /// 연결이 없으면 null이고, 추천은 로컬 엔진이 그대로 맡는다.
  static AiRecommendationService? aiRecommendationService() {
    if (!_initialized) return null;
    return SupabaseAiRecommendationService(Supabase.instance.client);
  }

  /// 테스트에서 상태를 초기화할 때 쓴다.
  @visibleForTesting
  static void resetForTest() => _initialized = false;
}
