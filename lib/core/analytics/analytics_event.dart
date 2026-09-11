import 'package:flutter/foundation.dart';

/// 허용된 이벤트만 정의한다. 원문 검색어와 식별자 원문은 담지 않는다.
sealed class AnalyticsEvent {
  const AnalyticsEvent();

  String get name;
}

final class FinderStarted extends AnalyticsEvent {
  const FinderStarted({required this.entryPoint});

  /// 'home_cta' | 'home_search' | 'preset' | 'history_reuse' | 'anniversary'
  final String entryPoint;

  @override
  String get name => 'finder_started';
}

final class StepCompleted extends AnalyticsEvent {
  const StepCompleted({required this.step});

  final int step;

  @override
  String get name => 'step_completed';
}

final class RecommendationViewed extends AnalyticsEvent {
  const RecommendationViewed({
    required this.sessionId,
    required this.usedFallback,
    required this.durationMs,
  });

  final String sessionId;
  final bool usedFallback;
  final int durationMs;

  @override
  String get name => 'recommendation_viewed';
}

final class DetailOpened extends AnalyticsEvent {
  const DetailOpened({required this.categoryId});

  final String categoryId;

  @override
  String get name => 'detail_opened';
}

final class QueryCopied extends AnalyticsEvent {
  const QueryCopied({required this.categoryId});

  final String categoryId;

  @override
  String get name => 'query_copied';
}

/// `disclosureShown`이 false면 기록도 이동도 허용하지 않는다.
final class CommerceClicked extends AnalyticsEvent {
  const CommerceClicked({
    required this.categoryId,
    required this.destinationHost,
    required this.disclosureShown,
  });

  final String categoryId;
  final String destinationHost;
  final bool disclosureShown;

  @override
  String get name => 'commerce_clicked';
}

final class HistoryReused extends AnalyticsEvent {
  const HistoryReused();

  @override
  String get name => 'history_reused';
}

/// 수집 동의 전에는 아무것도 기록하지 않는 인메모리 수집기.
///
/// 서버 전송은 Phase 2의 `/v1/events`에서 같은 이벤트 목록으로 연결한다.
class AnalyticsRecorder {
  AnalyticsRecorder({this.consentGranted = false});

  /// 분석 동의 기본값은 false다.
  bool consentGranted;

  final List<AnalyticsEvent> _events = <AnalyticsEvent>[];

  List<AnalyticsEvent> get events => List<AnalyticsEvent>.unmodifiable(_events);

  void record(AnalyticsEvent event) {
    if (event is CommerceClicked && !event.disclosureShown) {
      assert(false, 'disclosure 없이 commerce_clicked를 기록할 수 없다');
      return;
    }
    if (!consentGranted) return;
    _events.add(event);
    if (kDebugMode) {
      debugPrint('analytics: ${event.name}');
    }
  }

  void clear() => _events.clear();
}
