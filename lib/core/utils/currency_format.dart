/// 통화 표기 유틸. 패키지 추가 없이 KRW 한 가지 형식만 다룬다.
abstract final class CurrencyFormat {
  /// 1000 단위 구분 기호를 넣은 원화 문자열.
  static String won(int amount) {
    final bool negative = amount < 0;
    final String digits = amount.abs().toString();
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return '${negative ? '-' : ''}$buffer원';
  }

  /// 만원 단위 요약(예: 3.9만원). 카드의 좁은 영역에서 사용한다.
  static String manwon(int amount) {
    final double value = amount / 10000;
    final String text = value >= 10
        ? value.round().toString()
        : value.toStringAsFixed(1);
    return '$text만원';
  }
}
