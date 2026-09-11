import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/app_harness.dart';

void main() {
  testWidgets('기록은 확인 후에만 삭제된다', (WidgetTester tester) async {
    await bootApp(tester);
    await runWizard(tester, situation: '집들이', relationship: '가족');

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tapText(tester, '보관함');
    await tapText(tester, '추천 기록');
    await tapText(tester, '가족 · 집들이');

    // 취소하면 기록이 남는다.
    await scrollLastList(tester, find.text('기록 삭제'));
    await tapText(tester, '기록 삭제');
    expect(find.text('기록을 삭제할까요?'), findsOneWidget);
    await tapText(tester, '취소');
    // 취소하면 다이얼로그만 닫히고 기록 상세는 그대로 남는다.
    expect(find.text('기록을 삭제할까요?'), findsNothing);
    expect(find.text('기록 삭제'), findsOneWidget);

    await scrollLastList(tester, find.text('기록 삭제'));
    await tapText(tester, '기록 삭제');
    await tapText(tester, '삭제');
    expect(find.text('아직 추천 기록이 없어요'), findsOneWidget);
  });

  testWidgets('기념일을 추가하고 확인 후 삭제할 수 있다', (WidgetTester tester) async {
    await bootApp(tester);

    final Finder anniversaryEntry = find.text('기념일 미리 챙기기');
    await scrollHome(tester, anniversaryEntry);
    await tapText(tester, '기념일 미리 챙기기');
    expect(find.text('등록된 기념일이 없어요'), findsOneWidget);

    await tapText(tester, '기념일 추가');
    await tester.enterText(find.byType(TextField).last, '민지');
    await tester.pumpAndSettle();

    // 입력 시트가 길어 날짜/저장 버튼은 스크롤해서 눌러야 한다.
    await scrollLastList(tester, find.text('날짜 선택'));
    await tapText(tester, '날짜 선택');
    await tapText(tester, 'OK');
    await scrollLastList(tester, find.text('저장'));
    await tapText(tester, '저장');

    expect(find.textContaining('민지'), findsWidgets);

    await tester.tap(find.byTooltip('삭제').first);
    await tester.pumpAndSettle();
    await tapText(tester, '삭제');
    expect(find.text('등록된 기념일이 없어요'), findsOneWidget);
  });

  testWidgets('설정에서 로컬 데이터를 모두 삭제한다', (WidgetTester tester) async {
    await bootApp(tester);
    await runWizard(tester);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tapText(tester, '홈');

    await tester.tap(find.byTooltip('설정'));
    await tester.pumpAndSettle();

    await scrollLastList(tester, find.text('데이터 전체 삭제'));
    await tapText(tester, '데이터 전체 삭제');
    expect(find.text('데이터를 모두 삭제할까요?'), findsOneWidget);
    await tapText(tester, '삭제');

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tapText(tester, '보관함');
    await tapText(tester, '추천 기록');
    expect(find.text('아직 추천 기록이 없어요'), findsOneWidget);
  });

  testWidgets('설정에서 문의와 고지를 확인할 수 있다', (WidgetTester tester) async {
    await bootApp(tester);
    await tester.tap(find.byTooltip('설정'));
    await tester.pumpAndSettle();

    await scrollLastList(tester, find.text('문의'));
    await tapText(tester, '문의');
    expect(find.textContaining('출시 준비 단계에서 연결할 예정'), findsOneWidget);
    await tapText(tester, '확인');
  });
}
