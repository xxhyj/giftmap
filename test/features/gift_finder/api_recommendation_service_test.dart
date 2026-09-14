import 'package:flutter_test/flutter_test.dart';
import 'package:giftmap/core/config/api_bootstrap.dart';
import 'package:giftmap/core/config/api_config.dart';
import 'package:giftmap/core/net/json_http_client.dart';
import 'package:giftmap/features/gift_finder/data/api_recommendation_service.dart';
import 'package:giftmap/features/gift_finder/data/product_recommendation_engine.dart';
import 'package:giftmap/features/gift_finder/domain/gift_intent.dart';
import 'package:giftmap/features/products/data/api_product_data_source.dart';
import 'package:giftmap/features/products/domain/product.dart';
import 'package:giftmap/features/products/domain/product_catalog.dart';

const ApiConfig _config = ApiConfig(
  baseUrl: 'https://giftmap.example.app',
  useMock: false,
);

Product _product(String id) => Product.fromJson(<String, Object?>{
  'id': id,
  'productName': '상품 $id',
  'category': 'living',
  'categoryLabel': '홈·리빙',
  'price': 12000,
  'productUrl': 'https://shop.test/$id',
  'isDemo': false,
});

ProductCatalog _catalog() => ProductCatalog(
  products: <Product>[_product('a'), _product('b'), _product('c')],
  version: 'api',
  disclaimer: '',
);

const GiftIntent _intent = GiftIntent(
  situation: GiftSituation.birthday,
  relationship: RelationshipType.friend,
  ageBand: AgeBand.twenties,
  budget: BudgetBand.from10kTo30k,
  preference: 0.6,
);

final class _FakeClient implements JsonHttpClient {
  _FakeClient(this._respond);

  final Object? Function(Map<String, Object?> body) _respond;
  final List<Map<String, Object?>> posted = <Map<String, Object?>>[];
  Uri? lastUrl;

  @override
  Future<Object?> getJson(Uri url) async => throw UnimplementedError();

  @override
  Future<Object?> postJson(Uri url, Map<String, Object?> body) async {
    lastUrl = url;
    posted.add(body);
    return _respond(body);
  }

  @override
  void close() {}
}

/// GET 만 답하는 대역. 상품 한 건 조회에 쓴다.
final class _FakeGetClient implements JsonHttpClient {
  _FakeGetClient(this._respond);

  final Object? Function(Uri url) _respond;

  @override
  Future<Object?> getJson(Uri url) async => _respond(url);

  @override
  Future<Object?> postJson(Uri url, Map<String, Object?> body) async =>
      throw UnimplementedError();

  @override
  void close() {}
}

void main() {
  test('서버가 고른 상품을 추천으로 바꾼다', () async {
    final _FakeClient client = _FakeClient(
      (Map<String, Object?> body) => <String, Object?>{
        'fallback': false,
        'picks': <Object?>[
          <String, Object?>{'productId': 'a', 'reason': '이유1'},
          <String, Object?>{'productId': 'b', 'reason': '이유2'},
          <String, Object?>{'productId': 'c', 'reason': '이유3'},
        ],
      },
    );

    final List<ProductPick>? picks = await ApiRecommendationService(
      _config,
      client,
    ).recommend(_intent, catalog: _catalog());

    expect(picks, isNotNull);
    expect(picks!.length, 3);
    expect(picks.first.product.id, 'a');
    expect(picks.first.reason, '이유1');
    expect(picks.first.badge, 'AI 추천');
    expect(client.lastUrl?.path, '/api/recommend');
  });

  test('사용자가 고른 조건만 보낸다', () async {
    final _FakeClient client = _FakeClient(
      (Map<String, Object?> body) => <String, Object?>{'fallback': true},
    );

    await ApiRecommendationService(
      _config,
      client,
    ).recommend(_intent, catalog: _catalog());

    final Map<String, Object?> sent = client.posted.single;
    expect(sent['relationship'], 'friend');
    expect(sent['situation'], 'birthday');
    expect(sent['ageBand'], 'twenties');
    // 키나 사용자 식별값은 보내지 않는다.
    expect(sent.containsKey('apiKey'), isFalse);
    expect(sent.containsKey('userId'), isFalse);
  });

  test('서버도 모르는 id 는 버린다', () async {
    // 모델이 지어낸 id 는 상품 조회에서 걸러진다.
    final _FakeClient client = _FakeClient(
      (Map<String, Object?> body) => <String, Object?>{
        'fallback': false,
        'picks': <Object?>[
          <String, Object?>{'productId': 'a'},
          <String, Object?>{'productId': '지어낸상품'},
          <String, Object?>{'productId': 'b'},
        ],
      },
    );

    final List<ProductPick>? picks = await ApiRecommendationService(
      _config,
      client,
    ).recommend(_intent, catalog: _catalog());

    // 남은 것이 3개 미만이면 로컬 엔진에 맡긴다.
    expect(picks, isNull);
  });

  test('아직 안 받은 상품은 서버에 하나씩 물어본다', () async {
    // 앱은 첫 화면 몫만 들고 있는데 서버는 전체에서 고른다. 이걸 안 하면
    // 고른 상품이 매번 버려져 추천이 로컬 엔진으로 떨어진다(실제로 그랬다).
    final List<Uri> fetched = <Uri>[];
    final _FakeGetClient getClient = _FakeGetClient((Uri url) {
      fetched.add(url);
      final String id = url.pathSegments.last;
      return <String, Object?>{
        'product': <String, Object?>{
          'id': id,
          'productName': '나중에 받은 상품 $id',
          'category': 'living',
          'categoryLabel': '홈·리빙',
          'price': 20000,
          'productUrl': 'https://shop.test/$id',
          'isDemo': false,
        },
      };
    });
    final _FakeClient client = _FakeClient(
      (Map<String, Object?> body) => <String, Object?>{
        'fallback': false,
        'picks': <Object?>[
          <String, Object?>{'productId': 'a', 'reason': '손에 있는 것'},
          <String, Object?>{'productId': 'far-1', 'reason': '아직 안 받은 것'},
          <String, Object?>{'productId': 'far-2', 'reason': '이것도'},
        ],
      },
    );

    final List<ProductPick>? picks = await ApiRecommendationService(
      _config,
      client,
      products: ApiProductDataSource(_config, getClient),
    ).recommend(_intent, catalog: _catalog());

    expect(picks, isNotNull);
    expect(picks!.length, 3);
    expect(picks[1].product.id, 'far-1');
    // 이미 들고 있는 상품은 다시 묻지 않는다.
    expect(fetched.length, 2);
  });

  test('서버가 fallback 을 주면 로컬 엔진에 맡긴다', () async {
    final _FakeClient client = _FakeClient(
      (Map<String, Object?> body) => <String, Object?>{
        'fallback': true,
        'reason': '후보 없음',
      },
    );

    expect(
      await ApiRecommendationService(
        _config,
        client,
      ).recommend(_intent, catalog: _catalog()),
      isNull,
    );
  });

  test('호출이 실패해도 예외를 밖으로 내지 않는다', () async {
    final _FakeClient client = _FakeClient((Map<String, Object?> body) {
      throw const ApiException('서버에 연결하지 못했습니다.');
    });

    expect(
      await ApiRecommendationService(
        _config,
        client,
      ).recommend(_intent, catalog: _catalog()),
      isNull,
    );
  });

  test('모양이 다른 응답도 조용히 넘긴다', () async {
    final _FakeClient client = _FakeClient(
      (Map<String, Object?> body) => <String, Object?>{'picks': '목록이 아님'},
    );

    expect(
      await ApiRecommendationService(
        _config,
        client,
      ).recommend(_intent, catalog: _catalog()),
      isNull,
    );
  });

  group('경로 고르기', () {
    tearDown(ApiBootstrap.resetForTest);

    test('USE_MOCK=false 와 https 주소가 있어야 API 경로를 쓴다', () {
      ApiBootstrap.configure(_config, client: _FakeClient((_) => null));

      expect(ApiBootstrap.isRemoteMode, isTrue);
      expect(ApiBootstrap.productDataSource(), isA<ApiProductDataSource>());
      expect(
        ApiBootstrap.aiRecommendationService(),
        isA<ApiRecommendationService>(),
      );
    });

    test('추천은 상품 조회보다 오래 기다리는 클라이언트를 쓴다', () {
      // 서버가 모델을 45초까지 기다린다. 앱이 20초에 포기하면 서버가 잘 고르고
      // 있어도 매번 로컬 엔진으로 떨어진다(실제로 그랬다).
      ApiBootstrap.configure(_config);

      final Object? service = ApiBootstrap.aiRecommendationService();
      expect(service, isA<ApiRecommendationService>());
      expect(
        (service! as ApiRecommendationService).client,
        isA<HttpJsonHttpClient>().having(
          (HttpJsonHttpClient c) => c.timeout,
          'timeout',
          greaterThan(const Duration(seconds: 45)),
        ),
      );
    });

    test('Mock 모드면 예전 경로가 그대로 쓰이도록 null 을 돌려준다', () {
      ApiBootstrap.configure(
        const ApiConfig(baseUrl: 'https://giftmap.example.app', useMock: true),
        client: _FakeClient((_) => null),
      );

      expect(ApiBootstrap.isRemoteMode, isFalse);
      expect(ApiBootstrap.productDataSource(), isNull);
      expect(ApiBootstrap.aiRecommendationService(), isNull);
    });

    test('주소가 잘못되면 API 경로를 켜지 않는다', () {
      ApiBootstrap.configure(
        const ApiConfig(baseUrl: 'http://평문주소', useMock: false),
        client: _FakeClient((_) => null),
      );

      expect(ApiBootstrap.isRemoteMode, isFalse);
      expect(ApiBootstrap.productDataSource(), isNull);
    });
  });
}
