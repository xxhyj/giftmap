import 'package:flutter/foundation.dart';

import '../../features/gift_finder/data/ai_recommendation_service.dart';
import '../../features/gift_finder/data/api_recommendation_service.dart';
import '../../features/products/data/api_product_data_source.dart';
import '../../features/products/data/bundled_product_data_source.dart';
import '../net/json_http_client.dart';
import 'api_config.dart';

/// Vercel API 경로를 준비한다.
///
/// Supabase 를 직접 읽는 예전 경로([SupabaseBootstrap])와 나란히 둔다.
/// 둘 중 하나만 켜지며, 서로의 코드를 건드리지 않는다.
/// 되돌릴 일이 생기면 `USE_MOCK` 을 주지 않는 것만으로 예전 경로로 돌아간다.
///
/// 고르는 규칙은 하나다.
/// - `USE_MOCK=false` 이고 `API_BASE_URL` 이 https 주소면 → API 경로
/// - 그 밖에는 → 예전 경로(Supabase 값이 있으면 Supabase, 없으면 번들 Mock)
abstract final class ApiBootstrap {
  static ApiConfig _config = const ApiConfig(baseUrl: '', useMock: true);
  static JsonHttpClient? _client;

  /// 추천 전용. 서버가 모델을 기다리는 시간(45초)보다 넉넉해야 한다.
  /// 앱이 먼저 포기하면 서버가 잘 고르고 있어도 로컬 엔진으로 떨어진다.
  static JsonHttpClient? _slowClient;

  /// `main()` 에서 한 번 호출한다. 통신은 여기서 하지 않는다.
  static void configure(ApiConfig config, {JsonHttpClient? client}) {
    _config = config;
    if (!config.isRemoteMode) {
      if (!config.useMock && config.baseUrl.trim().isNotEmpty) {
        // 주소가 잘못된 채로 조용히 Mock 으로 떨어지면 원인을 찾기 어렵다.
        debugPrint('[Giftmap] API_BASE_URL 이 https 주소가 아니어서 API 경로를 켜지 않았습니다.');
      }
      return;
    }
    _client = client ?? HttpJsonHttpClient();
    _slowClient =
        client ?? HttpJsonHttpClient(timeout: const Duration(seconds: 60));
    debugPrint('[Giftmap] Vercel API 경로로 실행합니다.');
  }

  /// API 경로로 동작 중인지.
  static bool get isRemoteMode => _config.isRemoteMode && _client != null;

  /// 상품 데이터 소스. API 경로가 아니면 null 이고, 부르는 쪽이 예전 경로를 쓴다.
  static ProductDataSource? productDataSource() {
    final JsonHttpClient? client = _client;
    if (!_config.isRemoteMode || client == null) return null;
    return ApiProductDataSource(_config, client);
  }

  /// 서버 추천. API 경로가 아니면 null 이고, 추천은 로컬 엔진이 맡는다.
  static AiRecommendationService? aiRecommendationService() {
    final JsonHttpClient? client = _slowClient;
    if (!_config.isRemoteMode || client == null) return null;
    return ApiRecommendationService(
      _config,
      client,
      // 서버가 고른 상품이 아직 앱 손에 없을 때 한 건씩 확인하는 통로.
      products: ApiProductDataSource(_config, client),
    );
  }

  /// 테스트에서 상태를 초기화할 때 쓴다.
  @visibleForTesting
  static void resetForTest() {
    _client?.close();
    if (!identical(_slowClient, _client)) _slowClient?.close();
    _client = null;
    _slowClient = null;
    _config = const ApiConfig(baseUrl: '', useMock: true);
  }
}
