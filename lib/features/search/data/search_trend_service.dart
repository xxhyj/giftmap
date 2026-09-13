import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 검색어 하나와 그 근거.
class SearchTrend {
  const SearchTrend({
    required this.keyword,
    required this.recent,
    required this.previous,
  });

  final String keyword;

  /// 최근 7일 발생 수.
  final int recent;

  /// 그 이전 7일 발생 수. 증가율 계산에 쓴다.
  final int previous;

  /// 이전 주 대비 증가율. 이전 주 기록이 없으면 null이다.
  double? get growth => previous == 0 ? null : (recent - previous) / previous;
}

/// 검색어 목록을 어디서 가져왔는지.
///
/// 데이터가 모자랄 때 "실시간 인기"라고 부르지 않기 위해 구분한다.
enum SearchTrendSource {
  /// 실제 검색 기록을 집계한 결과.
  measured('인기 검색어'),

  /// 기록이 모자라 카탈로그에서 고른 기본 목록.
  curated('추천 검색어');

  const SearchTrendSource(this.label);

  final String label;
}

class SearchTrendResult {
  const SearchTrendResult({required this.keywords, required this.source});

  final List<String> keywords;
  final SearchTrendSource source;
}

/// 검색 기록을 익명으로 남기고, 집계된 인기 검색어를 읽는다.
///
/// 개인을 식별할 수 있는 값은 보내지 않는다. 사용자 id·기기 id·시간대 없이
/// 정규화한 검색어 하나만 보낸다. 서버도 검색어와 시각만 저장하며,
/// 3회 미만 검색어는 집계에서 빠져 한두 사람의 입력이 드러나지 않는다.
abstract interface class SearchTrendService {
  /// 사용자가 검색했음을 익명으로 남긴다. 실패해도 화면은 그대로 진행한다.
  Future<void> recordSearch(String keyword);

  /// 검색 결과에서 상품을 열었음을 익명으로 남긴다.
  Future<void> recordClick(String keyword);

  /// 인기 검색어. 기록이 모자라면 [fallback]을 그대로 돌려준다.
  Future<SearchTrendResult> topKeywords({
    required List<String> fallback,
    int limit = 8,
  });
}

/// 기록을 남기지 않는 구현. Supabase 연결이 없을 때 쓴다.
final class NoopSearchTrendService implements SearchTrendService {
  const NoopSearchTrendService();

  @override
  Future<void> recordSearch(String keyword) async {}

  @override
  Future<void> recordClick(String keyword) async {}

  @override
  Future<SearchTrendResult> topKeywords({
    required List<String> fallback,
    int limit = 8,
  }) async => SearchTrendResult(
    keywords: fallback.take(limit).toList(growable: false),
    source: SearchTrendSource.curated,
  );
}

/// Supabase에 익명으로 남기고 집계 뷰를 읽는 구현.
final class SupabaseSearchTrendService implements SearchTrendService {
  const SupabaseSearchTrendService(
    this._client, {
    this.minKeywords = 5,
    this.timeout = const Duration(seconds: 5),
  });

  final SupabaseClient _client;

  /// 이 개수보다 적게 모이면 "인기"라고 부르지 않고 추천 검색어를 보여 준다.
  final int minKeywords;
  final Duration timeout;

  /// 저장하기 전에 다듬는다.
  ///
  /// 앞뒤 공백을 없애고 길이를 제한한다. 너무 길거나 문장 같은 입력은
  /// 개인적인 내용을 담을 수 있어 아예 남기지 않는다.
  static String? normalize(String raw) {
    final String value = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (value.isEmpty || value.length > 20) return null;
    // 검색어로 보기 어려운 긴 문장은 남기지 않는다.
    if (value.split(' ').length > 3) return null;
    return value.toLowerCase();
  }

  Future<void> _record(String keyword, String kind) async {
    final String? value = normalize(keyword);
    if (value == null) return;
    try {
      await _client
          .from('search_events')
          .insert(<String, Object?>{'keyword': value, 'kind': kind})
          .timeout(timeout);
    } on Object catch (error) {
      // 기록은 부가 기능이다. 실패해도 검색 자체는 계속된다.
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
      final List<Map<String, dynamic>> rows = await _client
          .from('search_trends')
          .select('keyword, recent, previous')
          .order('recent', ascending: false)
          .limit(limit)
          .timeout(timeout);

      final List<SearchTrend> trends = rows
          .map(
            (Map<String, dynamic> row) => SearchTrend(
              keyword: row['keyword']?.toString() ?? '',
              recent: (row['recent'] as num?)?.toInt() ?? 0,
              previous: (row['previous'] as num?)?.toInt() ?? 0,
            ),
          )
          .where((SearchTrend trend) => trend.keyword.isNotEmpty)
          .toList();

      // 기록이 모자라면 "인기"라고 부르지 않는다.
      if (trends.length < minKeywords) {
        return SearchTrendResult(
          keywords: fallback.take(limit).toList(growable: false),
          source: SearchTrendSource.curated,
        );
      }

      // 많이 찾은 순으로 두되, 지난주보다 늘어난 검색어를 앞으로 올린다.
      trends.sort((SearchTrend a, SearchTrend b) {
        final int byGrowth = (b.growth ?? 0).compareTo(a.growth ?? 0);
        return byGrowth != 0 ? byGrowth : b.recent.compareTo(a.recent);
      });

      return SearchTrendResult(
        keywords: trends
            .map((SearchTrend trend) => trend.keyword)
            .toList(growable: false),
        source: SearchTrendSource.measured,
      );
    } on Object catch (error) {
      debugPrint('[Giftmap] 인기 검색어를 불러오지 못했습니다: $error');
      return SearchTrendResult(
        keywords: fallback.take(limit).toList(growable: false),
        source: SearchTrendSource.curated,
      );
    }
  }
}
