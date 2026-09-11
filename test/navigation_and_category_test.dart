import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftmap/features/products/presentation/widgets/carousel_navigation_button.dart';
import 'package:giftmap/features/products/presentation/widgets/product_card.dart';

import 'helpers/app_harness.dart';

void main() {
  testWidgets('하단 내비게이션은 홈·카테고리·선물추천·찜·기록 5개다', (WidgetTester tester) async {
    await bootApp(tester);

    final NavigationBar bar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(bar.destinations.length, 5);

    for (final String label in <String>['홈', '카테고리', '선물추천', '찜', '기록']) {
      expect(find.text(label), findsWidgets, reason: '$label 탭이 있어야 한다');
    }
    // 검색은 탭이 아니라 홈 검색창으로 들어간다.
    expect(find.text('검색'), findsNothing);
  });

  testWidgets('각 탭으로 이동하면 해당 화면이 나온다', (WidgetTester tester) async {
    await bootApp(tester);

    await goToTab(tester, '카테고리');
    expect(find.text('전체 상품'), findsOneWidget);

    await goToTab(tester, '선물추천');
    expect(find.text('어떤 상황인가요?'), findsOneWidget);

    await goToTab(tester, '찜한 상품');
    expect(find.text('아직 찜한 상품이 없어요'), findsOneWidget);

    await goToTab(tester, '기록');
    expect(find.text('최근 본 상품이 없어요'), findsOneWidget);

    await goToTab(tester, '홈');
    expect(find.text('무엇을 줄지 고민된다면'), findsOneWidget);
  });

  testWidgets('카테고리를 고르면 해당 상품만 남고 전체로 돌아올 수 있다', (WidgetTester tester) async {
    await bootApp(tester);
    await goToTab(tester, '카테고리');

    final String allCount = _countLabel(tester);

    await tapText(tester, '푸드·디저트');
    final String filteredCount = _countLabel(tester);
    expect(filteredCount, isNot(allCount));
    expect(find.text('푸드·디저트'), findsWidgets);

    await tapText(tester, '전체');
    expect(_countLabel(tester), allCount);
    expect(find.text('전체 상품'), findsOneWidget);

    // 목록을 내리면 상품 카드가 실제로 그려진다.
    await scrollLastList(tester, find.byType(ProductGridCard));
    expect(find.byType(ProductGridCard), findsWidgets);
  });

  testWidgets('카테고리 화면은 상품 수를 하드코딩하지 않고 목록 길이를 따른다', (
    WidgetTester tester,
  ) async {
    await bootApp(tester);
    await goToTab(tester, '카테고리');

    // 카탈로그가 돌려준 개수와 화면에 표시된 개수가 일치해야 한다.
    final int catalogCount = loadCatalogForTest().products.length;
    expect(find.textContaining('· $catalogCount개'), findsOneWidget);
  });

  testWidgets('캐러셀은 첫 화면에서 이전 버튼이 비활성이고 다음으로 넘길 수 있다', (
    WidgetTester tester,
  ) async {
    await bootApp(tester);
    await bringIntoView(tester);

    final Finder previous = find.byWidgetPredicate(
      (Widget w) =>
          w is CarouselNavigationButton && w.direction == AxisDirection.left,
    );
    final Finder next = find.byWidgetPredicate(
      (Widget w) =>
          w is CarouselNavigationButton && w.direction == AxisDirection.right,
    );

    expect(previous, findsWidgets);
    expect(next, findsWidgets);

    // 첫 페이지에서는 이전 버튼이 비활성이다.
    final CarouselNavigationButton first = tester
        .widgetList<CarouselNavigationButton>(previous)
        .first;
    expect(first.onPressed, isNull);

    // 다음 버튼을 누르면 캐러셀이 이동하고 이전 버튼이 활성화된다.
    await tester.tap(next.first);
    await tester.pumpAndSettle();

    final CarouselNavigationButton afterMove = tester
        .widgetList<CarouselNavigationButton>(previous)
        .first;
    expect(afterMove.onPressed, isNotNull);
  });

  testWidgets('캐러셀은 손가락으로 넘길 수 있다', (WidgetTester tester) async {
    await bootApp(tester);
    await bringIntoView(tester);

    final Finder previous = find.byWidgetPredicate(
      (Widget w) =>
          w is CarouselNavigationButton && w.direction == AxisDirection.left,
    );
    expect(
      tester.widgetList<CarouselNavigationButton>(previous).first.onPressed,
      isNull,
    );

    await tester.fling(find.byType(PageView).first, const Offset(-300, 0), 800);
    await tester.pumpAndSettle();

    // swipe 이후 화살표 상태가 함께 갱신된다.
    expect(
      tester.widgetList<CarouselNavigationButton>(previous).first.onPressed,
      isNotNull,
    );
  });
}

/// "전체 카테고리의 상품 · N개" 형태의 라벨을 읽는다.
String _countLabel(WidgetTester tester) {
  final Finder finder = find.textContaining('개', findRichText: false);
  final Iterable<Text> texts = tester.widgetList<Text>(finder);
  return texts
      .map((Text t) => t.data ?? '')
      .firstWhere((String s) => s.contains('· ') && s.endsWith('개'));
}
