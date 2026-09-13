import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftmap/features/products/presentation/widgets/product_card.dart';

import 'helpers/app_harness.dart';

/// 홈 최상단의 검색창으로 검색 화면에 들어간다.
Future<void> _openSearch(WidgetTester tester) async {
  await tapText(tester, '브랜드, 상품, 카테고리 검색');
}

Future<void> _search(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField).last, query);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('검색으로 상품을 찾고 상세까지 이동한다', (WidgetTester tester) async {
    await bootApp(tester);
    await _openSearch(tester);

    expect(find.text('추천 검색어'), findsOneWidget);

    await _search(tester, '디퓨저');
    expect(find.textContaining('검색 결과'), findsOneWidget);
    expect(find.byType(ProductGridCard), findsWidgets);

    await tester.tap(find.byType(ProductGridCard).first);
    await tester.pumpAndSettle();
    expect(find.text('상품 보러 가기'), findsOneWidget);
  });

  testWidgets('검색 화면에 최근 검색어가 저장되지 않는다', (WidgetTester tester) async {
    await bootApp(tester);
    await _openSearch(tester);
    await _search(tester, '텀블러');

    // 검색어를 지워도 최근 검색어 목록은 남지 않는다.
    await tester.enterText(find.byType(TextField).last, '');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('최근 검색어'), findsNothing);
    expect(find.text('추천 검색어'), findsOneWidget);
  });

  testWidgets('검색 화면에 카테고리 영역이 없고 추천 검색어만 남는다', (WidgetTester tester) async {
    await bootApp(tester);
    await _openSearch(tester);

    expect(find.text('추천 검색어'), findsOneWidget);
    expect(find.text('카테고리로 찾기'), findsNothing);
    expect(find.text('카테고리별로 보기'), findsNothing);
    expect(find.text('인기 카테고리'), findsNothing);
  });

  testWidgets('추천 검색어 pill을 누르면 해당 키워드로 검색한다', (WidgetTester tester) async {
    await bootApp(tester);
    await _openSearch(tester);

    await tapText(tester, '디퓨저');
    expect(find.textContaining('검색 결과'), findsOneWidget);
    expect(find.byType(ProductGridCard), findsWidgets);
  });

  testWidgets('추천 검색어 pill은 두 줄을 넘지 않는다', (WidgetTester tester) async {
    await bootApp(tester);
    await _openSearch(tester);

    // Wrap 한 줄에 들어가는 높이를 기준으로 두 줄 이내인지 확인한다.
    final Size wrapSize = tester.getSize(find.byType(Wrap).first);
    expect(wrapSize.height, lessThanOrEqualTo(96));
  });

  testWidgets('검색 결과가 없으면 빈 상태와 추천 검색어를 보여준다', (WidgetTester tester) async {
    await bootApp(tester);
    await _openSearch(tester);
    await _search(tester, '존재하지않는상품명123');

    expect(find.textContaining('검색 결과가 없어요'), findsOneWidget);
    expect(find.byType(ProductGridCard), findsNothing);
  });

  testWidgets('상품을 찜하면 찜 탭에 모이고 해제하면 비워진다', (WidgetTester tester) async {
    await bootApp(tester);
    await _openSearch(tester);
    await _search(tester, '텀블러');

    await tester.tap(find.byTooltip('찜하기').first);
    await tester.pumpAndSettle();
    expect(find.byTooltip('찜 해제'), findsWidgets);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await goToTab(tester, '찜한 상품');

    expect(find.textContaining('찜했어요'), findsOneWidget);
    expect(find.byType(ProductGridCard), findsWidgets);

    // 찜 탭에서 해제하면 즉시 빈 상태가 된다.
    await tester.tap(find.byTooltip('찜 해제').first);
    await tester.pumpAndSettle();
    expect(find.text('아직 찜한 상품이 없어요'), findsOneWidget);
  });

  testWidgets('같은 상품을 다시 찜해도 중복되지 않는다', (WidgetTester tester) async {
    await bootApp(tester);
    await _openSearch(tester);
    await _search(tester, '텀블러');

    await tester.tap(find.byTooltip('찜하기').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('찜 해제').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('찜하기').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await goToTab(tester, '찜한 상품');

    expect(find.text('1개의 상품을 찜했어요'), findsOneWidget);
  });

  testWidgets('상품 상세를 열면 기록 탭의 최근 본 상품에 쌓인다', (WidgetTester tester) async {
    await bootApp(tester);
    await _openSearch(tester);
    await _search(tester, '핸드크림');

    await tester.tap(find.byType(ProductGridCard).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    await goToTab(tester, '기록');

    expect(find.byType(ProductRowCard), findsWidgets);
    expect(find.text('최근 본 상품이 없어요'), findsNothing);
  });

  testWidgets('기록 탭은 최근 본 상품과 추천 기록만 보여준다', (WidgetTester tester) async {
    await bootApp(tester);
    await goToTab(tester, '기록');

    expect(find.text('최근 본 상품'), findsWidgets);
    expect(find.text('추천 기록'), findsWidgets);
    // 검색 키워드 기록은 어디에도 없다.
    expect(find.text('검색 기록'), findsNothing);
    expect(find.text('최근 검색어'), findsNothing);

    expect(find.text('최근 본 상품이 없어요'), findsOneWidget);
    await tapText(tester, '추천 기록');
    expect(find.text('아직 추천 기록이 없어요'), findsOneWidget);
  });

  testWidgets('추천을 마치면 기록 탭의 추천 기록에 조건과 결과가 남는다', (WidgetTester tester) async {
    await bootApp(tester);
    await runWizard(tester, situation: '집들이', relationship: '가족');

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await goToTab(tester, '기록');
    await tapText(tester, '추천 기록');

    expect(find.text('가족 · 집들이'), findsWidgets);
    expect(find.textContaining('추천 방향'), findsWidgets);

    await tapText(tester, '가족 · 집들이');
    expect(find.text('당시 추천'), findsOneWidget);
    expect(find.byType(ProductGridCard), findsWidgets);
  });
}
