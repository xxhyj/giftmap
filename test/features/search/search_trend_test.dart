import 'package:flutter_test/flutter_test.dart';
import 'package:giftmap/features/search/data/search_trend_service.dart';

/// 서버 응답을 흉내 내는 구현. 네트워크를 쓰지 않는다.
///
/// 진짜 구현과 같은 규칙을 따른다: 집계된 검색어가 모자라면 "인기"라고 부르지
/// 않고 추천 검색어로 내려간다.
final class FakeTrendService implements SearchTrendService {
  FakeTrendService(
    this.serverTrends, {
    this.minKeywords = 5,
    this.fails = false,
  });

  /// 서버가 돌려줬다고 가정하는 (검색어, 최근 7일, 이전 7일).
  final List<(String, int, int)> serverTrends;
  final int minKeywords;
  final bool fails;

  final List<String> recorded = <String>[];

  @override
  Future<void> recordSearch(String keyword) async {
    final String? value = SupabaseSearchTrendService.normalize(keyword);
    if (value != null) recorded.add('search:$value');
  }

  @override
  Future<void> recordClick(String keyword) async {
    final String? value = SupabaseSearchTrendService.normalize(keyword);
    if (value != null) recorded.add('click:$value');
  }

  @override
  Future<SearchTrendResult> topKeywords({
    required List<String> fallback,
    int limit = 8,
  }) async {
    if (fails || serverTrends.length < minKeywords) {
      return SearchTrendResult(
        keywords: fallback.take(limit).toList(growable: false),
        source: SearchTrendSource.curated,
      );
    }
    final List<SearchTrend> trends = serverTrends
        .map(
          ((String, int, int) row) =>
              SearchTrend(keyword: row.$1, recent: row.$2, previous: row.$3),
        )
        .toList();
    trends.sort((SearchTrend a, SearchTrend b) {
      final int byGrowth = (b.growth ?? 0).compareTo(a.growth ?? 0);
      return byGrowth != 0 ? byGrowth : b.recent.compareTo(a.recent);
    });
    return SearchTrendResult(
      keywords: trends
          .map((SearchTrend t) => t.keyword)
          .toList(growable: false),
      source: SearchTrendSource.measured,
    );
  }
}

const List<String> _fallback = <String>['핸드크림', '디퓨저', '텀블러'];

void main() {
  test('기록이 모자라면 인기라고 부르지 않는다', () async {
    final FakeTrendService service = FakeTrendService(<(String, int, int)>[
      ('향수', 9, 4),
      ('텀블러', 5, 5),
    ]);

    final SearchTrendResult result = await service.topKeywords(
      fallback: _fallback,
    );

    expect(result.source, SearchTrendSource.curated);
    expect(result.source.label, '추천 검색어');
    expect(result.keywords, _fallback);
  });

  test('기록이 충분하면 인기 검색어로 바뀐다', () async {
    final FakeTrendService service = FakeTrendService(<(String, int, int)>[
      ('향수', 10, 10),
      ('텀블러', 8, 8),
      ('핸드크림', 6, 6),
      ('디퓨저', 5, 5),
      ('머그컵', 4, 4),
    ]);

    final SearchTrendResult result = await service.topKeywords(
      fallback: _fallback,
    );

    expect(result.source, SearchTrendSource.measured);
    expect(result.source.label, '인기 검색어');
    expect(result.keywords.first, '향수');
  });

  test('지난주보다 많이 늘어난 검색어가 앞으로 온다', () async {
    final FakeTrendService service = FakeTrendService(<(String, int, int)>[
      ('안정적인검색어', 20, 20), // 증가율 0
      ('급상승검색어', 9, 3), // 증가율 200%
      ('보통검색어', 12, 10),
      ('디퓨저', 5, 5),
      ('머그컵', 4, 4),
    ]);

    final SearchTrendResult result = await service.topKeywords(
      fallback: _fallback,
    );

    expect(result.keywords.first, '급상승검색어');
  });

  test('서버가 실패하면 추천 검색어로 내려간다', () async {
    final FakeTrendService service = FakeTrendService(<(String, int, int)>[
      ('a', 9, 1),
      ('b', 8, 1),
      ('c', 7, 1),
      ('d', 6, 1),
      ('e', 5, 1),
    ], fails: true);

    final SearchTrendResult result = await service.topKeywords(
      fallback: _fallback,
    );
    expect(result.source, SearchTrendSource.curated);
    expect(result.keywords, _fallback);
  });

  group('검색어 정규화 — 개인적인 내용은 남기지 않는다', () {
    test('앞뒤 공백을 정리하고 소문자로 맞춘다', () {
      expect(SupabaseSearchTrendService.normalize('  Perfume  '), 'perfume');
      expect(SupabaseSearchTrendService.normalize('향수  선물'), '향수 선물');
    });

    test('빈 검색어는 남기지 않는다', () {
      expect(SupabaseSearchTrendService.normalize('   '), isNull);
    });

    test('문장처럼 긴 입력은 남기지 않는다', () {
      // 개인적인 내용이 담길 수 있어 아예 기록하지 않는다.
      expect(SupabaseSearchTrendService.normalize('내일 김민수 생일인데 뭐 사지'), isNull);
      expect(SupabaseSearchTrendService.normalize('아' * 25), isNull);
    });
  });

  test('검색과 클릭을 익명으로 센다', () async {
    final FakeTrendService service = FakeTrendService(<(String, int, int)>[]);

    await service.recordSearch('향수');
    await service.recordClick('향수');
    await service.recordSearch('   ');

    // 사용자 식별 정보 없이 검색어만 남는다.
    expect(service.recorded, <String>['search:향수', 'click:향수']);
  });

  test('기록하지 않는 구현은 항상 추천 검색어를 준다', () async {
    const NoopSearchTrendService service = NoopSearchTrendService();
    await service.recordSearch('향수');

    final SearchTrendResult result = await service.topKeywords(
      fallback: _fallback,
    );
    expect(result.source, SearchTrendSource.curated);
    expect(result.keywords, _fallback);
  });
}
