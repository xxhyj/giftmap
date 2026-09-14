import 'package:flutter/foundation.dart';

import '../../../core/config/api_config.dart';
import '../../../core/net/json_http_client.dart';
import 'search_trend_service.dart';

/// Vercel API 로 검색 기록을 남기고 집계를 읽는 구현.
///
/// 개인을 식별할 수 있는 값은 보내지 않는다. 사용자 id·기기 id 없이 정규화한
/// 검색어 하나와 종류만 보낸다. 남길지 말지는 [normalizeSearchKeyword] 기준으로
/// 앱에서 한 번, 서버에서 한 번 더 거른다.
///
/// 기록은 부가 기능이다. 실패해도 검색 자체는 그대로 진행한다.
final class ApiSearchTrendService implements SearchTrendService {
  const ApiSearchTrendService(
    this._config,
    this._client, {
    this.minKeywords = 5,
  });

  final ApiConfig _config;
  final JsonHttpClient _client;

  /// 이 개수보다 적게 모이면 "인기"라고 부르지 않고 추천 검색어를 보여 준다.
  final int minKeywords;

  Future<void> _record(String keyword, String kind) async {
    final String? value = normalizeSearchKeyword(keyword);
    if (value == null) return;
    try {
      await _client.postJson(
        _config.resolve('/api/search-events'),
        <String, Object?>{'keyword': value, 'kind': kind},
      );
    } on Object catch (error) {
      debugPrint('[Giftmap] 검색 기록 실패: $error');
    }
  }

  @override
  Future<void> recordSearch(String keyword) => _record(keyword, 'search');

  @override
  Future<void> recordClick(String keyword) => _record(keyword, 'click');

  @override
  Future<SearchTrendResult> topKeywords({
    required List<String> fallback,
    int limit = 8,
  }) async {
    try {
      final Object? body = await _client.getJson(
        _config.resolve('/api/search-events', <String, String>{
          'limit': '$limit',
        }),
      );
      if (body is! Map) return _curated(fallback, limit);

      final Object? rows = body['trends'];
      if (rows is! List) return _curated(fallback, limit);

      final List<SearchTrend> trends = <SearchTrend>[];
      for (final Object? row in rows) {
        if (row is! Map) continue;
        final String keyword = row['keyword']?.toString() ?? '';
        if (keyword.isEmpty) continue;
        trends.add(
          SearchTrend(
            keyword: keyword,
            recent: _int(row['recent']),
            previous: _int(row['previous']),
          ),
        );
      }

      // 기록이 모자라면 "인기"라고 부르지 않는다.
      if (trends.length < minKeywords) return _curated(fallback, limit);

      // 많이 찾은 순으로 두되, 지난주보다 늘어난 검색어를 앞으로 올린다.
      trends.sort((SearchTrend a, SearchTrend b) {
        final int byGrowth = (b.growth ?? 0).compareTo(a.growth ?? 0);
        return byGrowth != 0 ? byGrowth : b.recent.compareTo(a.recent);
      });

      return SearchTrendResult(
        keywords: List<String>.unmodifiable(
          trends.take(limit).map((SearchTrend trend) => trend.keyword),
        ),
        source: SearchTrendSource.measured,
      );
    } on Object catch (error) {
      debugPrint('[Giftmap] 검색어 집계를 읽지 못했습니다: $error');
      return _curated(fallback, limit);
    }
  }

  static SearchTrendResult _curated(List<String> fallback, int limit) =>
      SearchTrendResult(
        keywords: fallback.take(limit).toList(growable: false),
        source: SearchTrendSource.curated,
      );

  static int _int(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
}
