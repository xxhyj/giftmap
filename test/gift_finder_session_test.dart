import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/app_harness.dart';

/// 1단계에서 상황만 고른 뒤 2단계로 넘어간다.
Future<void> _startAndAdvance(WidgetTester tester) async {
  await goToTab(tester, '선물추천');
  await tapText(tester, '생일');
  await tapText(tester, '다음');
  expect(find.text('누구에게 주나요?'), findsOneWidget);
}

void main() {
  testWidgets('다른 탭에 다녀와도 진행 단계와 선택값이 유지된다', (WidgetTester tester) async {
    await bootApp(tester);
    await _startAndAdvance(tester);

    await goToTab(tester, '홈');
    await goToTab(tester, '선물추천');

    // 2단계 그대로이며 1단계 선택도 남아 있다.
    expect(find.text('누구에게 주나요?'), findsOneWidget);
    expect(find.text('02 / 05'), findsOneWidget);

    await tester.tap(find.byTooltip('이전 단계'));
    await tester.pumpAndSettle();
    expect(find.text('어떤 상황인가요?'), findsOneWidget);
    // 선택했던 상황이 그대로 선택 상태다.
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('처음부터를 누르면 선택값이 지워지고 1단계로 돌아간다', (WidgetTester tester) async {
    await bootApp(tester);
    await _startAndAdvance(tester);

    await tapText(tester, '처음부터');

    expect(find.text('어떤 상황인가요?'), findsOneWidget);
    expect(find.text('01 / 05'), findsOneWidget);
    // 선택 표시가 남아 있지 않다.
    expect(find.byIcon(Icons.check_circle), findsNothing);
  });

  testWidgets('아무것도 고르지 않았으면 처음부터 버튼은 비활성이다', (WidgetTester tester) async {
    await bootApp(tester);
    await goToTab(tester, '선물추천');

    final TextButton restart = tester.widget<TextButton>(
      find.widgetWithText(TextButton, '처음부터'),
    );
    expect(restart.onPressed, isNull);
  });

  testWidgets('추천을 마친 뒤 선물추천 탭에 다시 들어가면 1단계로 시작한다', (
    WidgetTester tester,
  ) async {
    await bootApp(tester);
    await runWizard(tester);
    expect(find.text('이런 선물을 추천해요'), findsOneWidget);

    // 결과 화면을 닫고 다른 탭을 거쳐 선물추천 탭으로 다시 들어온다.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await goToTab(tester, '홈');
    await goToTab(tester, '선물추천');

    expect(find.text('어떤 상황인가요?'), findsOneWidget);
    expect(find.text('01 / 05'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);
  });

  testWidgets('새로 시작해도 완료된 추천은 기록에 남아 있다', (WidgetTester tester) async {
    await bootApp(tester);
    await runWizard(tester);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await goToTab(tester, '선물추천');
    expect(find.text('01 / 05'), findsOneWidget);

    await goToTab(tester, '기록');
    await tapText(tester, '추천 기록');
    expect(find.text('친구 · 생일'), findsWidgets);
  });

  testWidgets('결과에서 조건 수정을 누르면 선택값이 남아 있다', (WidgetTester tester) async {
    await bootApp(tester);
    await runWizard(tester);

    await tapText(tester, '조건 수정');

    expect(find.text('어떤 상황인가요?'), findsOneWidget);
    // 조건 수정은 초기화가 아니므로 선택이 유지된다.
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });
}
