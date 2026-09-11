import 'package:flutter/material.dart';

import '../features/anniversary/presentation/anniversary_screen.dart';
import '../features/gift_finder/data/local_intent_parser.dart';
import '../features/gift_finder/presentation/analyzing_screen.dart';
import '../features/gift_finder/presentation/result_screen.dart';
import '../features/gift_finder/presentation/search_intent_review_screen.dart';
import '../features/history/domain/history_entry.dart';
import '../features/history/presentation/history_detail_screen.dart';
import '../features/settings/presentation/settings_screen.dart';

/// 라우팅 패키지 없이 Navigator/MaterialPageRoute만 사용한다.
abstract final class AppRouter {
  static const String searchReviewName = '/search-review';
  static const String analyzingName = '/analyzing';
  static const String resultName = '/result';
  static const String historyDetailName = '/history-detail';
  static const String anniversaryName = '/anniversary';
  static const String settingsName = '/settings';

  static Route<void> searchReview(ParsedIntent parsed) {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: searchReviewName),
      builder: (BuildContext context) =>
          SearchIntentReviewScreen(parsed: parsed),
    );
  }

  static Route<void> analyzing() {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: analyzingName),
      builder: (BuildContext context) => const AnalyzingScreen(),
    );
  }

  static Route<void> result() {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: resultName),
      builder: (BuildContext context) => const ResultScreen(),
    );
  }

  static Route<void> historyDetail(HistoryEntry entry) {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: historyDetailName),
      builder: (BuildContext context) => HistoryDetailScreen(entry: entry),
    );
  }

  static Route<void> anniversary() {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: anniversaryName),
      builder: (BuildContext context) => const AnniversaryScreen(),
    );
  }

  static Route<void> settings() {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: settingsName),
      builder: (BuildContext context) => const SettingsScreen(),
    );
  }
}
