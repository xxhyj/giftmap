import '../domain/gift_intent.dart';

/// 파서가 추출한 개별 필드와 신뢰도.
class ParsedField<T> {
  const ParsedField(this.value, this.confidence);

  const ParsedField.unknown(this.value) : confidence = 0;

  final T value;

  /// 0.0~1.0. 0.7 미만이면 앱이 확정값으로 취급하지 않고 사용자에게 되묻는다.
  final double confidence;

  bool get isConfident => confidence >= confidenceThreshold;

  static const double confidenceThreshold = 0.7;
}

/// 자연어 검색어에서 추출한 조건 묶음.
class ParsedIntent {
  const ParsedIntent({
    required this.rawQuery,
    required this.situation,
    required this.relationship,
    required this.ageBand,
    required this.budget,
    required this.preference,
    this.customBudget,
  });

  final String rawQuery;
  final ParsedField<GiftSituation> situation;
  final ParsedField<RelationshipType> relationship;
  final ParsedField<AgeBand> ageBand;
  final ParsedField<BudgetBand> budget;
  final ParsedField<double> preference;
  final int? customBudget;

  /// 신뢰도가 낮아 사용자 확인이 필요한 필드가 하나라도 있는지.
  bool get needsReview =>
      !situation.isConfident ||
      !relationship.isConfident ||
      !budget.isConfident ||
      !preference.isConfident;

  GiftIntent toIntent() => GiftIntent(
    situation: situation.value,
    relationship: relationship.value,
    ageBand: ageBand.value,
    budget: budget.value,
    preference: preference.value,
    customBudget: customBudget,
    rawQuery: rawQuery,
  );
}

/// 로컬 키워드 기반 의도 파서.
///
/// 외부 AI를 호출하지 않으며, Phase 2의 `/v1/intents:parse`가 같은 결과 모양을
/// 돌려주도록 설계했다. 원문은 화면 표시에만 쓰고 저장·전송하지 않는다.
class LocalIntentParser {
  const LocalIntentParser();

  static const Map<String, GiftSituation> _situationKeywords =
      <String, GiftSituation>{
        '생일': GiftSituation.birthday,
        '생신': GiftSituation.birthday,
        '기념일': GiftSituation.anniversary,
        '결혼기념': GiftSituation.anniversary,
        '승진': GiftSituation.promotion,
        '취업': GiftSituation.promotion,
        '입사': GiftSituation.promotion,
        '감사': GiftSituation.thanks,
        '고마': GiftSituation.thanks,
        '집들이': GiftSituation.housewarming,
        '이사': GiftSituation.housewarming,
        '출산': GiftSituation.birth,
        '돌잔치': GiftSituation.birth,
        '명절': GiftSituation.holiday,
        '추석': GiftSituation.holiday,
        '설날': GiftSituation.holiday,
        '응원': GiftSituation.support,
        '시험': GiftSituation.support,
      };

  static const Map<String, RelationshipType> _relationshipKeywords =
      <String, RelationshipType>{
        '연인': RelationshipType.partner,
        '남친': RelationshipType.partner,
        '여친': RelationshipType.partner,
        '남자친구': RelationshipType.partner,
        '여자친구': RelationshipType.partner,
        '친구': RelationshipType.friend,
        '가족': RelationshipType.family,
        '부모': RelationshipType.family,
        '어머니': RelationshipType.family,
        '아버지': RelationshipType.family,
        '동생': RelationshipType.family,
        '동료': RelationshipType.colleague,
        '팀원': RelationshipType.colleague,
        '상사': RelationshipType.manager,
        '팀장': RelationshipType.manager,
        '부장': RelationshipType.manager,
        '대표': RelationshipType.manager,
        '지인': RelationshipType.acquaintance,
        '이웃': RelationshipType.acquaintance,
      };

  static const Map<String, AgeBand> _ageKeywords = <String, AgeBand>{
    '10대': AgeBand.teens,
    '20대': AgeBand.twenties,
    '30대': AgeBand.thirties,
    '40대': AgeBand.fortiesPlus,
    '50대': AgeBand.fortiesPlus,
    '60대': AgeBand.fortiesPlus,
  };

  ParsedIntent parse(String rawQuery) {
    final String query = rawQuery.trim();

    final GiftSituation? situation = _firstMatch(query, _situationKeywords);
    final RelationshipType? relationship = _firstMatch(
      query,
      _relationshipKeywords,
    );
    final AgeBand? ageBand = _firstMatch(query, _ageKeywords);
    final (BudgetBand?, int?) budget = _parseBudget(query);
    final double? preference = _parsePreference(query);

    return ParsedIntent(
      rawQuery: query,
      situation: situation == null
          ? const ParsedField<GiftSituation>.unknown(GiftSituation.birthday)
          : ParsedField<GiftSituation>(situation, 0.9),
      relationship: relationship == null
          ? const ParsedField<RelationshipType>.unknown(RelationshipType.friend)
          : ParsedField<RelationshipType>(relationship, 0.9),
      ageBand: ageBand == null
          ? const ParsedField<AgeBand>.unknown(AgeBand.unspecified)
          : ParsedField<AgeBand>(ageBand, 0.9),
      budget: budget.$1 == null
          ? const ParsedField<BudgetBand>.unknown(BudgetBand.from30kTo50k)
          : ParsedField<BudgetBand>(budget.$1!, 0.85),
      customBudget: budget.$2,
      preference: preference == null
          ? const ParsedField<double>.unknown(0.5)
          : ParsedField<double>(preference, 0.8),
    );
  }

  /// 가장 먼저 등장하는 키워드를 채택해 같은 입력에 같은 결과를 보장한다.
  static T? _firstMatch<T>(String query, Map<String, T> keywords) {
    int bestIndex = -1;
    T? best;
    keywords.forEach((String keyword, T value) {
      final int index = query.indexOf(keyword);
      if (index < 0) return;
      if (bestIndex < 0 || index < bestIndex) {
        bestIndex = index;
        best = value;
      }
    });
    return best;
  }

  static (BudgetBand?, int?) _parseBudget(String query) {
    final RegExpMatch? manWon = RegExp(r'(\d{1,4})\s*만\s*원?').firstMatch(query);
    if (manWon != null) {
      final int value = int.parse(manWon.group(1)!) * 10000;
      return (_bandForAmount(value), value);
    }
    final RegExpMatch? won = RegExp(r'(\d{4,9})\s*원').firstMatch(query);
    if (won != null) {
      final int value = int.parse(won.group(1)!);
      return (_bandForAmount(value), value);
    }
    return (null, null);
  }

  static BudgetBand _bandForAmount(int amount) {
    if (amount <= 10000) return BudgetBand.under10k;
    if (amount <= 30000) return BudgetBand.from10kTo30k;
    if (amount <= 50000) return BudgetBand.from30kTo50k;
    if (amount <= 100000) return BudgetBand.from50kTo100k;
    return BudgetBand.over100k;
  }

  static double? _parsePreference(String query) {
    const List<String> practical = <String>['실용', '실속', '쓸모', '가성비'];
    const List<String> emotional = <String>['감성', '분위기', '예쁜', '특별'];
    if (practical.any(query.contains)) return 0.2;
    if (emotional.any(query.contains)) return 0.8;
    return null;
  }
}
