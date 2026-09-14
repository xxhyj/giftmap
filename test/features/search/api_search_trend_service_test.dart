import 'package:flutter_test/flutter_test.dart';
import 'package:giftmap/core/config/api_config.dart';
import 'package:giftmap/core/net/json_http_client.dart';
import 'package:giftmap/features/search/data/api_search_trend_service.dart';
import 'package:giftmap/features/search/data/search_trend_service.dart';

const ApiConfig _config = ApiConfig(
  baseUrl: 'https://giftmap.example.app',
  useMock: false,
);

final class _FakeClient implements JsonHttpClient {
  _FakeClient({this.onGet, this.onPost});

  final Object? Function(Uri url)? onGet;
  final Object? Function(Uri url, Map<String, Object?> body)? onPost;
  final List<Map<String, Object?>> posted = <Map<String, Object?>>[];
  Uri? lastUrl;

  @override
  Future<Object?> getJson(Uri url) async {
    lastUrl = url;
    final Object? Function(Uri url)? handler = onGet;
    if (handler == null) throw const ApiException('GET 을 기대하지 않았다');
    return handler(url);
  }

  @override
  Future<Object?> postJson(Uri url, Map<String, Object?> body) async {
    lastUrl = url;
    posted.add(body);
    return onPost?.call(url, body) ?? <String, Object?>{'recorded': true};
  }

  @override
  void close() {}
}

void main() {
  group('검색 기록', () {
    test('검색어와 종류만 보낸다', () async {
      final _FakeClient client = _FakeClient();

      await ApiSearchTrendService(_config, client).recordSearch('  텀블러 ');

      expect(client.lastUrl?.path, '/api/search-events');
      expect(client.posted.single, <String, Object?>{
        'keyword': '텀블러',
        'kind': 'search',
      });
    });

    test('문장처럼 긴 입력은 아예 보내지 않는다', () async {
      // 개인적인 내용이 담길 수 있어 기기 밖으로 내보내지 않는다.
      final _FakeClient client = _FakeClient();

      await ApiSearchTrendService(
        _config,
        client,
      ).recordSearch('여자친구 생일 선물 뭐가 좋을까');

      expect(client.posted, isEmpty);
    });

    test('기록이 실패해도 예외를 밖으로 내지 않는다', () async {
      // 기록은 부가 기능이다. 검색 자체를 막으면 안 된다.
      final _FakeClient client = _FakeClient(
        onPost: (Uri url, Map<String, Object?> body) {
          throw const ApiException('서버에 연결하지 못했습니다.');
        },
      );

      await expectLater(
        ApiSearchTrendService(_config, client).recordClick('디퓨저'),
        completes,
      );
    });
  });

  group('집계 읽기', () {
    Map<String, Object?> trend(String keyword, int recent, int previous) =>
        <String, Object?>{
          'keyword': keyword,
          'recent': recent,
          'previous': previous,
        };

    test('충분히 모이면 인기 검색어로 부른다', () async {
      final _FakeClient client = _FakeClient(
        onGet: (Uri url) => <String, Object?>{
          'trends': <Object?>[
            trend('디퓨저', 10, 10),
            trend('텀블러', 9, 3),
            trend('핸드크림', 8, 8),
            trend('향수', 7, 7),
            trend('캔들', 6, 6),
          ],
        },
      );

      final SearchTrendResult result = await ApiSearchTrendService(
        _config,
        client,
      ).topKeywords(fallback: <String>['기본']);

      expect(result.source, SearchTrendSource.measured);
      // 지난주보다 늘어난 검색어가 앞에 온다.
      expect(result.keywords.first, '텀블러');
    });

    test('모자라면 추천 검색어로 부르고 준비된 목록을 쓴다', () async {
      final _FakeClient client = _FakeClient(
        onGet: (Uri url) => <String, Object?>{
          'trends': <Object?>[trend('텀블러', 5, 1)],
        },
      );

      final SearchTrendResult result = await ApiSearchTrendService(
        _config,
        client,
      ).topKeywords(fallback: <String>['디퓨저', '핸드크림']);

      expect(result.source, SearchTrendSource.curated);
      expect(result.keywords, <String>['디퓨저', '핸드크림']);
    });

    test('서버가 죽어도 화면은 추천 검색어로 채운다', () async {
      final _FakeClient client = _FakeClient(
        onGet: (Uri url) {
          throw const ApiException('서버가 502 를 돌려줬습니다.', statusCode: 502);
        },
      );

      final SearchTrendResult result = await ApiSearchTrendService(
        _config,
        client,
      ).topKeywords(fallback: <String>['디퓨저']);

      expect(result.source, SearchTrendSource.curated);
      expect(result.keywords, <String>['디퓨저']);
    });

    test('모양이 다른 응답도 추천 검색어로 넘긴다', () async {
      final _FakeClient client = _FakeClient(
        onGet: (Uri url) => <String, Object?>{'trends': '목록이 아님'},
      );

      final SearchTrendResult result = await ApiSearchTrendService(
        _config,
        client,
      ).topKeywords(fallback: <String>['디퓨저']);

      expect(result.source, SearchTrendSource.curated);
    });
  });
}
