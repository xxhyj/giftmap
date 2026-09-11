import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftmap/features/products/presentation/widgets/product_card.dart';

import 'helpers/app_harness.dart';

Future<void> _openSearch(WidgetTester tester) async {
  await tester.tap(find.byTooltip('상품 검색'));
  await tester.pumpAndSettle();
}

Future<void> _search(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField).last, query);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pumpAndSettle();
}

Future<void> _goLibrary(WidgetTester tester) async {
  await tapText(tester, '보관함');
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
    expect(find.text('상품 보러가기'), findsOneWidget);
  });

  testWidgets('검색 결과가 없으면 빈 상태와 추천 검색어를 보여준다', (WidgetTester tester) async {
    await bootApp(tester);
    await _openSearch(tester);
    await _search(tester, '존재하지않는상품명123');

    expect(find.textContaining('검색 결과가 없어요'), findsOneWidget);
    expect(find.byType(ProductGridCard), findsNothing);
  });

  testWidgets('상품을 찜하면 보관함에 모인다', (WidgetTester tester) async {
    await bootApp(tester);
    await _openSearch(tester);
    await _search(tester, '텀블러');

    // 카드의 찜 버튼을 누른다.
    await tester.tap(find.byTooltip('찜하기').first);
    await tester.pumpAndSettle();
    expect(find.byTooltip('찜 해제'), findsWidgets);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await _goLibrary(tester);

    expect(find.textContaining('찜했어요'), findsOneWidget);
    expect(find.byType(ProductGridCard), findsWidgets);
  });

  testWidgets('찜을 해제하면 보관함이 비워진다', (WidgetTester tester) async {
    await bootApp(tester);
    await _openSearch(tester);
    await _search(tester, '텀블러');
    await tester.tap(find.byTooltip('찜하기').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('찜 해제').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await _goLibrary(tester);

    expect(find.text('아직 찜한 상품이 없어요'), findsOneWidget);
  });

  testWidgets('상품 상세를 열면 최근 본 상품에 쌓인다', (WidgetTester tester) async {
    await bootApp(tester);
    await _openSearch(tester);
    await _search(tester, '핸드크림');

    await tester.tap(find.byType(ProductGridCard).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    await _goLibrary(tester);
    await tapText(tester, '최근 본 상품');

    expect(find.byType(ProductRowCard), findsWidgets);
    expect(find.text('최근 본 상품이 없어요'), findsNothing);
  });

  testWidgets('보관함의 빈 상태가 안내와 행동을 제공한다', (WidgetTester tester) async {
    await bootApp(tester);
    await _goLibrary(tester);

    expect(find.text('아직 찜한 상품이 없어요'), findsOneWidget);
    expect(find.text('선물 찾아보기'), findsOneWidget);

    await tapText(tester, '최근 본 상품');
    expect(find.text('최근 본 상품이 없어요'), findsOneWidget);

    await tapText(tester, '추천 기록');
    expect(find.text('아직 추천 기록이 없어요'), findsOneWidget);
  });

  testWidgets('추천을 마치면 보관함의 추천 기록에서 다시 볼 수 있다', (WidgetTester tester) async {
    await bootApp(tester);
    await runWizard(tester, situation: '집들이', relationship: '가족');

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await _goLibrary(tester);
    await tapText(tester, '추천 기록');

    expect(find.text('가족 · 집들이'), findsWidgets);

    await tapText(tester, '가족 · 집들이');
    expect(find.text('당시 추천'), findsOneWidget);
    expect(find.byType(ProductGridCard), findsWidgets);

    // 재추천 버튼은 상품 목록 아래에 있다.
    final Finder reuse = find.text('이 조건으로 다시 추천');
    await scrollLastList(tester, reuse);
    expect(reuse, findsOneWidget);
  });
}
