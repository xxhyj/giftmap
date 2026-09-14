import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:giftmap/core/config/api_bootstrap.dart';
import 'package:giftmap/core/config/api_config.dart';
import 'package:giftmap/core/net/json_http_client.dart';
import 'package:giftmap/features/products/data/api_product_data_source.dart';
import 'package:giftmap/features/products/data/bundled_product_data_source.dart';
import 'package:giftmap/features/products/domain/product.dart';
import 'package:giftmap/features/products/domain/product_catalog.dart';

const ApiConfig _config = ApiConfig(
  baseUrl: 'https://giftmap.example.app',
  useMock: false,
);

Map<String, Object?> _productJson(String id) => <String, Object?>{
  'id': id,
  'brandName': '브랜드',
  'productName': '상품 $id',
  'category': 'living',
  'categoryLabel': '홈·리빙',
  'price': 12000,
  'imageUrl': 'https://img.test/$id.jpg',
  'productUrl': 'https://shop.test/$id',
  'source': 'seller',
  'isDemo': false,
  'availability': 'in_stock',
};

/// 정해 둔 응답을 돌려주는 대역. 네트워크를 쓰지 않는다.
final class _FakeClient implements JsonHttpClient {
  _FakeClient(this._respond);

  final Object? Function(Uri url, Map<String, Object?>? body) _respond;
  final List<Uri> requested = <Uri>[];
  final List<Map<String, Object?>> posted = <Map<String, Object?>>[];
  bool closed = false;

  @override
  Future<Object?> getJson(Uri url) async {
    requested.add(url);
    return _respond(url, null);
  }

  @override
  Future<Object?> postJson(Uri url, Map<String, Object?> body) async {
    requested.add(url);
    posted.add(body);
    return _respond(url, body);
  }

  @override
  void close() => closed = true;
}

void main() {
  group('주소 만들기', () {
    test('끝의 슬래시가 있어도 경로가 겹치지 않는다', () {
      const ApiConfig config = ApiConfig(
        baseUrl: 'https://giftmap.example.app/',
        useMock: false,
      );

      expect(
        config.resolve('/api/health').toString(),
        'https://giftmap.example.app/api/health',
      );
    });

    test('https 주소가 아니면 원격 모드로 보지 않는다', () {
      // 평문은 Android 9+ 에서 막히고 주소가 새기도 한다.
      expect(
        const ApiConfig(baseUrl: 'http://x.test', useMock: false).isRemoteMode,
        isFalse,
      );
      expect(
        const ApiConfig(baseUrl: '없는주소', useMock: false).isRemoteMode,
        isFalse,
      );
      expect(
        const ApiConfig(baseUrl: '', useMock: false).isRemoteMode,
        isFalse,
      );
    });

    test('USE_MOCK 이 true 면 주소가 있어도 서버를 부르지 않는다', () {
      expect(
        const ApiConfig(
          baseUrl: 'https://giftmap.example.app',
          useMock: true,
        ).isRemoteMode,
        isFalse,
      );
    });
  });

  group('이미지 주소', () {
    tearDown(ApiBootstrap.resetForTest);

    test('안드로이드에서는 판매처 주소를 그대로 쓴다', () {
      // 앱에는 CORS 가 없다. 서버를 거치면 대역폭만 더 쓴다.
      ApiBootstrap.configure(_config);

      expect(
        ApiBootstrap.imageUrl('https://thumbnail.10x10.co.kr/a.jpg'),
        'https://thumbnail.10x10.co.kr/a.jpg',
      );
    });

    test('API 경로가 아니면 그대로 쓴다', () {
      expect(
        ApiBootstrap.imageUrl('https://thumbnail.10x10.co.kr/a.jpg'),
        'https://thumbnail.10x10.co.kr/a.jpg',
      );
    });
  });

  group('상품 목록', () {
    test('offset 을 쪽 번호로 바꿔 부른다', () async {
      final _FakeClient client = _FakeClient(
        (Uri url, Map<String, Object?>? body) => <String, Object?>{
          'products': <Object?>[_productJson('a')],
          'hasMore': true,
        },
      );
      final ApiProductDataSource source = ApiProductDataSource(_config, client);

      await source.loadPage(offset: 240, limit: 120);

      final Uri url = client.requested.single;
      expect(url.path, '/api/products');
      expect(url.queryParameters['page'], '3');
      expect(url.queryParameters['limit'], '120');
    });

    test('받은 상품을 그대로 카탈로그에 쓴다', () async {
      final _FakeClient client = _FakeClient(
        (Uri url, Map<String, Object?>? body) => <String, Object?>{
          'products': <Object?>[_productJson('a'), _productJson('b')],
          'hasMore': false,
          'disclaimer': collectedProductDisclaimer,
          'searchSuggestions': <Object?>['텀블러', '', null],
        },
      );

      final ProductPage page = await ApiProductDataSource(
        _config,
        client,
      ).loadPage(offset: 0, limit: 60);

      expect(page.products.length, 2);
      expect(page.products.first.productName, '상품 a');
      expect(page.products.first.productUrl, 'https://shop.test/a');
      expect(page.products.first.isDemo, isFalse);
      expect(page.hasMore, isFalse);
      expect(page.disclaimer, collectedProductDisclaimer);
      // 빈 값은 추천 검색어로 쓰지 않는다.
      expect(page.searchSuggestions, <String>['텀블러']);
    });

    test('상품 하나가 잘못돼도 나머지는 보여 준다', () async {
      final _FakeClient client = _FakeClient(
        (Uri url, Map<String, Object?>? body) => <String, Object?>{
          'products': <Object?>[
            <String, Object?>{'id': 'broken'}, // 이름이 없다
            _productJson('ok'),
            '상품이 아닌 값',
          ],
          'hasMore': false,
        },
      );

      final ProductPage page = await ApiProductDataSource(
        _config,
        client,
      ).loadPage(offset: 0, limit: 60);

      expect(page.products.length, 1);
      expect(page.products.single.id, 'ok');
    });

    test('상품 목록이 없는 응답은 오류로 올린다', () async {
      // 조용히 빈 화면을 보여 주면 서버가 죽은 것을 알 수 없다.
      final _FakeClient client = _FakeClient(
        (Uri url, Map<String, Object?>? body) => <String, Object?>{'ok': true},
      );

      expect(
        () => ApiProductDataSource(
          _config,
          client,
        ).loadPage(offset: 0, limit: 10),
        throwsA(isA<ApiException>()),
      );
    });

    test('JSON 이 아닌 응답도 오류로 올린다', () async {
      final _FakeClient client = _FakeClient(
        (Uri url, Map<String, Object?>? body) => '<html>502</html>',
      );

      expect(
        () => ApiProductDataSource(
          _config,
          client,
        ).loadPage(offset: 0, limit: 10),
        throwsA(isA<ApiException>()),
      );
    });

    test('끝까지 이어 받아 카탈로그를 만든다', () async {
      int page = 0;
      final _FakeClient client = _FakeClient((
        Uri url,
        Map<String, Object?>? body,
      ) {
        page += 1;
        return <String, Object?>{
          'products': <Object?>[_productJson('p$page')],
          'hasMore': page < 3,
          'disclaimer': collectedProductDisclaimer,
        };
      });

      final ProductCatalog catalog = await ApiProductDataSource(
        _config,
        client,
      ).load();

      expect(catalog.products.length, 3);
      expect(catalog.version, 'api');
      expect(catalog.disclaimer, collectedProductDisclaimer);
    });
  });

  group('상품 하나', () {
    test('id 로 한 건을 받아 온다', () async {
      final _FakeClient client = _FakeClient(
        (Uri url, Map<String, Object?>? body) => <String, Object?>{
          'product': _productJson('seller-1'),
        },
      );

      final Product? product = await ApiProductDataSource(
        _config,
        client,
      ).fetchProduct('seller-1');

      expect(product?.id, 'seller-1');
      expect(client.requested.single.path, '/api/products/seller-1');
    });

    test('없는 상품은 오류가 아니라 null 이다', () async {
      final _FakeClient client = _FakeClient((
        Uri url,
        Map<String, Object?>? body,
      ) {
        throw const ApiException('없음', statusCode: 404, code: 'not_found');
      });

      expect(
        await ApiProductDataSource(_config, client).fetchProduct('seller-404'),
        isNull,
      );
    });

    test('그 밖의 오류는 그대로 올린다', () async {
      final _FakeClient client = _FakeClient((
        Uri url,
        Map<String, Object?>? body,
      ) {
        throw const ApiException('서버 오류', statusCode: 500);
      });

      expect(
        () => ApiProductDataSource(_config, client).fetchProduct('seller-1'),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('응답 해석', () {
    test('오류 응답에서 서버가 준 코드와 문구를 읽는다', () {
      expect(
        () => decodeResponse(
          status: 429,
          body: jsonEncode(<String, Object?>{
            'error': <String, Object?>{
              'code': 'rate_limited',
              'message': '너무 잦습니다.',
            },
          }),
        ),
        throwsA(
          isA<ApiException>()
              .having((ApiException e) => e.code, 'code', 'rate_limited')
              .having((ApiException e) => e.message, 'message', '너무 잦습니다.')
              .having((ApiException e) => e.statusCode, 'status', 429),
        ),
      );
    });

    test('빈 응답은 오류로 본다', () {
      expect(
        () => decodeResponse(status: 200, body: '   '),
        throwsA(isA<ApiException>()),
      );
    });

    test('깨진 JSON 은 오류로 본다', () {
      expect(
        () => decodeResponse(status: 200, body: '{이건 JSON 이 아니다'),
        throwsA(isA<ApiException>()),
      );
    });

    test('오류 본문이 JSON 이 아니어도 상태 코드는 남긴다', () {
      expect(
        () => decodeResponse(status: 502, body: '<html>bad gateway</html>'),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.statusCode,
            'status',
            502,
          ),
        ),
      );
    });

    test('제대로 된 응답은 그대로 돌려준다', () {
      final Object? decoded = decodeResponse(
        status: 200,
        body: jsonEncode(<String, Object?>{'hasMore': true}),
      );
      expect((decoded! as Map<String, dynamic>)['hasMore'], isTrue);
    });
  });
}
