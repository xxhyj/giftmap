/// 선물 상황.
enum GiftSituation {
  birthday('birthday', '생일'),
  anniversary('anniversary', '기념일'),
  promotion('promotion', '승진'),
  thanks('thanks', '감사'),
  housewarming('housewarming', '집들이'),
  birth('birth', '출산'),
  holiday('holiday', '명절'),
  support('support', '응원'),
  other('other', '기타');

  const GiftSituation(this.wireName, this.label);

  final String wireName;
  final String label;

  static GiftSituation? fromWire(String? value) {
    for (final GiftSituation item in GiftSituation.values) {
      if (item.wireName == value) return item;
    }
    return null;
  }
}

/// 받는 사람과의 관계.
enum RelationshipType {
  partner('partner', '연인'),
  friend('friend', '친구'),
  family('family', '가족'),
  colleague('colleague', '직장 동료'),
  manager('manager', '상사'),
  acquaintance('acquaintance', '지인');

  const RelationshipType(this.wireName, this.label);

  final String wireName;
  final String label;

  static RelationshipType? fromWire(String? value) {
    for (final RelationshipType item in RelationshipType.values) {
      if (item.wireName == value) return item;
    }
    return null;
  }
}

/// 연령대. 선택 사항이므로 `unspecified`가 기본값이다.
enum AgeBand {
  teens('teens', '10대'),
  twenties('twenties', '20대'),
  thirties('thirties', '30대'),
  fortiesPlus('fortiesPlus', '40대+'),
  unspecified('unspecified', '선택 안 함');

  const AgeBand(this.wireName, this.label);

  final String wireName;
  final String label;

  static AgeBand? fromWire(String? value) {
    for (final AgeBand item in AgeBand.values) {
      if (item.wireName == value) return item;
    }
    return null;
  }
}

/// 예산 구간. `custom`은 `GiftIntent.customBudget`과 함께 사용한다.
enum BudgetBand {
  under10k('under10k', '1만원 이하', 0, 10000),
  from10kTo30k('from10kTo30k', '1~3만원', 10000, 30000),
  from30kTo50k('from30kTo50k', '3~5만원', 30000, 50000),
  from50kTo100k('from50kTo100k', '5~10만원', 50000, 100000),
  over100k('over100k', '10만원 이상', 100000, 300000),
  custom('custom', '직접 입력', null, null);

  const BudgetBand(this.wireName, this.label, this.min, this.max);

  final String wireName;
  final String label;
  final int? min;
  final int? max;

  static const int customMin = 1000;
  static const int customMax = 10000000;

  static BudgetBand? fromWire(String? value) {
    for (final BudgetBand item in BudgetBand.values) {
      if (item.wireName == value) return item;
    }
    return null;
  }
}

/// 예산의 실제 하한/상한(KRW).
class BudgetRange {
  const BudgetRange(this.min, this.max);

  final int min;
  final int max;
}

enum RiskLevel {
  safe('safe', '부담 낮음'),
  caution('caution', '확인 필요'),
  avoid('avoid', '피하는 편이 좋음');

  const RiskLevel(this.wireName, this.label);

  final String wireName;
  final String label;

  static RiskLevel fromWire(String? value) {
    for (final RiskLevel item in RiskLevel.values) {
      if (item.wireName == value) return item;
    }
    return RiskLevel.caution;
  }
}

/// 회피 조건 태그. 카테고리 태그와 동일한 어휘를 사용한다.
abstract final class AvoidTags {
  static const String scent = 'scent';
  static const String food = 'food';
  static const String sizing = 'sizing';
  static const String strongTaste = 'strongTaste';

  static const Map<String, String> labels = <String, String>{
    scent: '향',
    food: '식품',
    sizing: '사이즈',
    strongTaste: '취향 강함',
  };

  static const List<String> all = <String>[scent, food, sizing, strongTaste];
}

/// 추천 엔진에 전달되는 확정된 사용자 의도.
class GiftIntent {
  const GiftIntent({
    required this.situation,
    required this.relationship,
    required this.ageBand,
    required this.budget,
    required this.preference,
    this.customBudget,
    this.avoidTags = const <String>[],
    this.rawQuery,
  });

  final GiftSituation situation;
  final RelationshipType relationship;
  final AgeBand ageBand;
  final BudgetBand budget;

  /// 0.0 = 실용적, 1.0 = 감성적.
  final double preference;
  final int? customBudget;
  final List<String> avoidTags;

  /// 원문 검색어. 분석 동의 전에는 저장·전송하지 않는다.
  final String? rawQuery;

  /// 직접 입력 예산은 ±20% 범위를 탐색 구간으로 사용한다.
  BudgetRange get budgetRange {
    if (budget == BudgetBand.custom) {
      final int value = customBudget ?? BudgetBand.customMin;
      return BudgetRange((value * 0.8).round(), (value * 1.2).round());
    }
    return BudgetRange(budget.min ?? 0, budget.max ?? BudgetBand.customMax);
  }

  String get budgetLabel {
    if (budget == BudgetBand.custom && customBudget != null) {
      return '${_thousands(customBudget!)}원 안팎';
    }
    return budget.label;
  }

  String get preferenceLabel {
    if (preference <= 0.35) return '실용적';
    if (preference >= 0.65) return '감성적';
    return '균형';
  }

  GiftIntent copyWith({
    GiftSituation? situation,
    RelationshipType? relationship,
    AgeBand? ageBand,
    BudgetBand? budget,
    double? preference,
    int? customBudget,
    List<String>? avoidTags,
    String? rawQuery,
  }) {
    return GiftIntent(
      situation: situation ?? this.situation,
      relationship: relationship ?? this.relationship,
      ageBand: ageBand ?? this.ageBand,
      budget: budget ?? this.budget,
      preference: preference ?? this.preference,
      customBudget: customBudget ?? this.customBudget,
      avoidTags: avoidTags ?? this.avoidTags,
      rawQuery: rawQuery ?? this.rawQuery,
    );
  }

  static String _thousands(int value) {
    final String digits = value.toString();
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}
