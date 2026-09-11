import '../../gift_finder/domain/gift_intent.dart';
import '../../gift_finder/domain/recommendation_result.dart';

/// 로컬에만 저장되는 과거 추천 기록.
class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.intent,
    required this.result,
    required this.createdAt,
  });

  final String id;
  final GiftIntent intent;
  final RecommendationResult result;
  final DateTime createdAt;

  /// "20대 친구 · 생일" 형태의 제목.
  String get title {
    final String age = intent.ageBand == AgeBand.unspecified
        ? ''
        : '${intent.ageBand.label} ';
    return '$age${intent.relationship.label} · ${intent.situation.label}';
  }

  String get summary {
    if (result.items.isEmpty) return '추천 없음';
    final String first = result.items.first.title;
    if (result.items.length == 1) return first;
    return '$first 외 ${result.items.length - 1}개';
  }
}

abstract interface class HistoryRepository {
  Future<List<HistoryEntry>> loadAll();

  Future<void> save(HistoryEntry entry);

  Future<void> delete(String id);

  Future<void> clear();
}
