/// 날짜 표기 유틸. intl 패키지를 추가하지 않고 한국어 표기만 직접 만든다.
abstract final class DateFormatKo {
  /// "오늘" / "어제" / "9월 8일" / "2025년 9월 8일".
  static String relativeDay(DateTime value, {DateTime? now}) {
    final DateTime today = _dateOnly(now ?? DateTime.now());
    final DateTime target = _dateOnly(value);
    final int diff = today.difference(target).inDays;
    if (diff == 0) return '오늘';
    if (diff == 1) return '어제';
    if (target.year == today.year) return '${target.month}월 ${target.day}일';
    return '${target.year}년 ${target.month}월 ${target.day}일';
  }

  /// "2026.09.11".
  static String dotted(DateTime value) {
    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    return '${value.year}.$month.$day';
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
