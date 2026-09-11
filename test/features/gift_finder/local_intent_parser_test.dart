import 'package:flutter_test/flutter_test.dart';
import 'package:giftmap/features/gift_finder/data/local_intent_parser.dart';
import 'package:giftmap/features/gift_finder/domain/gift_intent.dart';

void main() {
  const LocalIntentParser parser = LocalIntentParser();

  test('상황·관계·연령·예산·취향을 함께 추출한다', () {
    final ParsedIntent parsed = parser.parse('30대 팀장 승진 선물 5만원 실용적인 것');

    expect(parsed.situation.value, GiftSituation.promotion);
    expect(parsed.relationship.value, RelationshipType.manager);
    expect(parsed.ageBand.value, AgeBand.thirties);
    expect(parsed.budget.value, BudgetBand.from30kTo50k);
    expect(parsed.preference.value, lessThan(0.5));
    expect(parsed.needsReview, isFalse);
  });

  test('추출하지 못한 필드는 신뢰도가 낮아 확인을 요구한다', () {
    final ParsedIntent parsed = parser.parse('선물 추천해줘');

    expect(parsed.situation.isConfident, isFalse);
    expect(parsed.relationship.isConfident, isFalse);
    expect(parsed.budget.isConfident, isFalse);
    expect(parsed.needsReview, isTrue);
  });

  test('같은 입력은 같은 결과를 만든다', () {
    final ParsedIntent a = parser.parse('친구 생일 3만원 감성적인 선물');
    final ParsedIntent b = parser.parse('친구 생일 3만원 감성적인 선물');

    expect(a.situation.value, b.situation.value);
    expect(a.relationship.value, b.relationship.value);
    expect(a.budget.value, b.budget.value);
    expect(a.preference.value, b.preference.value);
  });

  test('원 단위 금액도 예산 구간으로 변환한다', () {
    final ParsedIntent parsed = parser.parse('동료 감사 선물 120000원');

    expect(parsed.budget.value, BudgetBand.over100k);
    expect(parsed.customBudget, 120000);
    expect(parsed.relationship.value, RelationshipType.colleague);
  });

  test('확정 의도로 변환하면 원문을 보존한다', () {
    final ParsedIntent parsed = parser.parse('연인 기념일 5만원');
    final GiftIntent intent = parsed.toIntent();

    expect(intent.rawQuery, '연인 기념일 5만원');
    expect(intent.situation, GiftSituation.anniversary);
    expect(intent.relationship, RelationshipType.partner);
  });
}
