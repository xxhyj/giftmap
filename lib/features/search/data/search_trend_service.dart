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

/// 저장하기 전에 검색어를 다듬는다. 남길 수 없는 입력이면 null 이다.
///
/// 앞뒤 공백을 없애고 길이를 제한한다. 20자를 넘거나 단어 셋을 넘는 입력은
/// 문장일 가능성이 높고, 문장에는 개인적인 내용이 담기기 쉬워 아예 남기지 않는다.
/// 서버도 같은 기준으로 한 번 더 거른다.
String? normalizeSearchKeyword(String raw) {
  final String value = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (value.isEmpty || value.length > 20) return null;
  if (value.split(' ').length > 3) return null;
  return value.toLowerCase();
}

/// 기록을 남기지 않는 구현. 서버가 없을 때 쓴다.
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
