import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftmap/features/products/presentation/widgets/product_card.dart';

import 'helpers/app_harness.dart';

void main() {
  testWidgets('홈은 상품 큐레이션과 선물추천 진입점을 보여준다', (WidgetTester tester) async {
    await bootApp(tester);

    expect(find.text('Giftmap'), findsOneWidget);
    expect(find.text('무엇을 줄지 고민된다면'), findsOneWidget);
    expect(find.text('추천받기'), findsOneWidget);
    expect(find.text('요즘 눈여겨볼 선물'), findsOneWidget);

    // 텍스트 목록이 아니라 상품 카드가 노출된다.
    expect(find.byType(ProductTileCard), findsWidgets);
  });

  testWidgets('홈에는 검색창이 하나이고 최근 본 상품 섹션이 없다', (WidgetTester tester) async {
    await bootApp(tester);

    expect(find.text('브랜드, 상품, 카테고리 검색'), findsOneWidget);

    // 최근 본 상품은 기록 탭에서만 보여준다.
    await scrollHome(tester, find.text('전체 카테고리 둘러보기'));
    expect(find.text('최근 본 상품'), findsNothing);
  });

  testWidgets('홈 하단에 데모 데이터 고지 문구가 없다', (WidgetTester tester) async {
    await bootApp(tester);

    await scrollHome(tester, find.text('기념일 미리 챙기기'));
    expect(find.textContaining('실시간 가격이 아닙니다'), findsNothing);
    expect(find.textContaining('데모 상품 데이터입니다'), findsNothing);
  });

  testWidgets('위저드 5단계를 마치면 상품 추천 결과가 나온다', (WidgetTester tester) async {
    await bootApp(tester);

    await tapText(tester, '추천받기');
    expect(find.text('어떤 상황인가요?'), findsOneWidget);
    expect(find.text('01 / 05'), findsOneWidget);

    await tapText(tester, '생일');
    await tapText(tester, '다음');
    expect(find.text('누구에게 주나요?'), findsOneWidget);

    await tapText(tester, '친구');
    await tapText(tester, '다음');
    expect(find.text('예산은 얼마인가요?'), findsOneWidget);

    await tapText(tester, '3~5만원');
    await tapText(tester, '다음');
    expect(find.text('어떤 느낌의 선물을 원하나요?'), findsOneWidget);

    await tapText(tester, '다음');
    expect(find.text('피하고 싶은 것이 있나요?'), findsOneWidget);

    await tapText(tester, '추천 상품 보기');
    expect(find.text('이런 선물을 추천해요'), findsOneWidget);
    expect(find.byType(ProductGridCard), findsWidgets);
  });

  testWidgets('추천 결과에서 상품 상세로 이동하고 돌아온다', (WidgetTester tester) async {
    await bootApp(tester);
    await runWizard(tester);

    await tester.tap(find.byType(ProductGridCard).first);
    await tester.pumpAndSettle();

    // 상세 본문은 스크롤 아래에 있으므로 끌어올려 확인한다.
    final Finder reason = find.text('왜 이 상품을 추천했나요?');
    await scrollLastList(tester, reason);
    expect(reason, findsOneWidget);

    // 데모 상태라 판매 페이지로 이동하지 않는다.
    final Finder cta = find.widgetWithText(FilledButton, '상품 보러 가기');
    expect(tester.widget<FilledButton>(cta).onPressed, isNull);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('이런 선물을 추천해요'), findsOneWidget);
  });

  testWidgets('텍스트를 1.3배로 키워도 홈이 넘치지 않는다', (WidgetTester tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await bootApp(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('무엇을 줄지 고민된다면'), findsOneWidget);
  });

  testWidgets('작은 화면(320x568)에서도 홈이 넘치지 않는다', (WidgetTester tester) async {
    await setScreenSize(tester, const Size(320, 568));
    await bootApp(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Giftmap'), findsOneWidget);
  });

  testWidgets('넓은 화면(tablet)에서도 홈이 정상 렌더링된다', (WidgetTester tester) async {
    await setScreenSize(tester, const Size(1024, 768));
    await bootApp(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(ProductTileCard), findsWidgets);
  });

  testWidgets('주요 CTA는 최소 44dp 이상의 높이를 가진다', (WidgetTester tester) async {
    await bootApp(tester);

    final Size size = tester.getSize(
      find.widgetWithText(FilledButton, '추천받기').first,
    );
    expect(size.height, greaterThanOrEqualTo(44));
  });
}
