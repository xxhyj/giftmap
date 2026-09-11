import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftmap/app/giftmap_app.dart';
import 'package:giftmap/features/library/data/in_memory_id_list_storage.dart';
import 'package:giftmap/features/products/domain/product_catalog.dart';
import 'package:giftmap/features/splash/presentation/splash_screen.dart';

import '../fixtures/ruleset_fixture.dart';

export '../fixtures/ruleset_fixture.dart' show loadBundledCatalog;

/// 위젯 테스트 공통 헬퍼.
///
/// `rootBundle`은 테스트 사이에 Future를 캐시해 두 번째 테스트부터 부팅이 끝나지
/// 않으므로, 번들 대신 같은 JSON을 파일에서 읽는 fixture 데이터 소스를 주입한다.
/// 찜·최근 본 상품 저장소도 테스트마다 새 인메모리 구현을 쓴다.
Future<void> bootApp(WidgetTester tester) async {
  await tester.pumpWidget(
    GiftmapApp(
      dataSource: const FixtureCategoryDataSource(),
      productDataSource: const FixtureProductDataSource(),
      storage: InMemoryIdListStorage(),
    ),
  );
  // Splash의 로딩 인디케이터는 무한 회전하므로 부팅이 끝날 때까지 프레임만 돌린다.
  for (
    int i = 0;
    i < 20 && find.byType(SplashScreen).evaluate().isNotEmpty;
    i++
  ) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).first);
  await tester.pumpAndSettle();
}

/// 첫 번째(홈 탭) 스크롤 영역을 목표 위젯이 보일 때까지 끌어올린다.
/// IndexedStack이 세 탭을 모두 만들기 때문에 Scrollable을 명시적으로 골라야 한다.
Future<void> scrollHome(WidgetTester tester, Finder target) =>
    scrollUntil(tester, find.byType(Scrollable).first, target);

/// 가장 마지막에 열린 스크롤 영역(바텀시트, 새 화면)을 끌어올린다.
///
/// 화면 안에는 실제로 스크롤되지 않는 내부 GridView도 있으므로,
/// 스크롤 여지가 있는 마지막 Scrollable을 골라서 끈다.
Future<void> scrollLastList(WidgetTester tester, Finder target) async {
  final Finder candidates = find.byType(Scrollable);
  final int count = candidates.evaluate().length;
  for (int i = count - 1; i >= 0; i--) {
    final Finder candidate = candidates.at(i);
    final ScrollableState state = tester.state<ScrollableState>(candidate);
    if (!state.position.hasContentDimensions ||
        state.position.maxScrollExtent <= 0) {
      continue;
    }
    await scrollUntil(tester, candidate, target);
    if (target.evaluate().isNotEmpty) return;
  }
}

Future<void> scrollUntil(
  WidgetTester tester,
  Finder scrollable,
  Finder target, {
  int maxDrags = 14,
}) async {
  for (int i = 0; i < maxDrags && target.evaluate().isEmpty; i++) {
    await tester.drag(scrollable, const Offset(0, -260));
    await tester.pumpAndSettle();
  }
}

/// 홈에서 시작해 위저드 5단계를 끝내고 추천 결과 화면까지 이동한다.
Future<void> runWizard(
  WidgetTester tester, {
  String situation = '생일',
  String relationship = '친구',
  String budget = '3~5만원',
}) async {
  await tapText(tester, '추천받기');
  await tapText(tester, situation);
  await tapText(tester, '다음');
  await tapText(tester, relationship);
  await tapText(tester, '다음');
  await tapText(tester, budget);
  await tapText(tester, '다음');
  await tapText(tester, '다음');
  await tapText(tester, '추천 상품 보기');
}

/// 특정 화면 크기에서의 회귀를 확인할 때 쓴다.
Future<void> setScreenSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// 바텀 탭으로 이동한다.
Future<void> goToTab(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip(label).last);
  await tester.pumpAndSettle();
}

/// 테스트에서 화면에 표시된 개수와 카탈로그 개수를 비교할 때 쓴다.
ProductCatalog loadCatalogForTest() => loadBundledCatalog();

/// 홈 목록을 세로로 끌어 캐러셀이 화면 안에 들어오게 한다.
/// 화면 밖 위젯에 제스처를 보내면 아무 일도 일어나지 않으므로 필요하다.
Future<void> bringIntoView(WidgetTester tester, {double dy = -260}) async {
  await tester.drag(find.byType(Scrollable).first, Offset(0, dy));
  await tester.pumpAndSettle();
}
