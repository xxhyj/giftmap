/// 앱 전역에서 사용하는 실패 표현. 사용자에게 보여줄 문구만 담고
/// 내부 stack trace나 원문 입력은 담지 않는다.
sealed class AppFailure implements Exception {
  const AppFailure(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// 번들 데이터 손상 등 로컬 데이터 준비 실패.
final class DataUnavailableFailure extends AppFailure {
  const DataUnavailableFailure([super.message = '선물 데이터를 불러오지 못했어요.']);
}

/// 추천 계산 자체가 불가능한 경우.
final class RecommendationFailure extends AppFailure {
  const RecommendationFailure([super.message = '추천을 만들지 못했어요. 조건을 조금 바꿔볼까요?']);
}

/// 입력 값 검증 실패.
final class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message);
}
