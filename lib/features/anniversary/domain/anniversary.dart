import '../../gift_finder/domain/gift_intent.dart';

/// 로컬에만 저장되는 기념일. MVP에서는 알림을 보내지 않는다.
class Anniversary {
  const Anniversary({
    required this.id,
    required this.displayName,
    required this.relationship,
    required this.situation,
    required this.date,
  });

  final String id;
  final String displayName;
  final RelationshipType relationship;
  final GiftSituation situation;
  final DateTime date;

  /// 오늘 기준 남은 일수. 지난 기념일은 내년 같은 날짜로 계산한다.
  int daysUntil(DateTime now) {
    final DateTime today = DateTime(now.year, now.month, now.day);
    DateTime next = DateTime(today.year, date.month, date.day);
    if (next.isBefore(today)) {
      next = DateTime(today.year + 1, date.month, date.day);
    }
    return next.difference(today).inDays;
  }

  String dDayLabel(DateTime now) {
    final int days = daysUntil(now);
    return days == 0 ? 'D-DAY' : 'D-$days';
  }
}

abstract interface class AnniversaryRepository {
  Future<List<Anniversary>> loadAll();

  Future<void> save(Anniversary anniversary);

  Future<void> delete(String id);

  Future<void> clear();
}
