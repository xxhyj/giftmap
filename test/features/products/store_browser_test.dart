import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftmap/features/products/domain/product.dart';
import 'package:giftmap/features/products/presentation/product_detail_screen.dart';
import 'package:giftmap/features/products/presentation/store_browser_screen.dart';

import '../../helpers/fake_webview.dart';
import '../../helpers/scope_harness.dart';

Product _product({
  String? productUrl =
      'https://www.10x10.co.kr/shopping/category_prd.asp?itemid=1',
  bool isDemo = false,
  String availability = 'in_stock',
}) => Product.fromJson(<String, Object?>{
  'id': 'p1',
  'brandName': '로이체',
  'productName': '곰돌이푸 USB 선풍기',
  'category': 'appliance',
  'categoryLabel': '가전·디지털',
  'price': 3200,
  'productUrl': productUrl,
  'imageUrl': 'https://example.test/a.jpg',
  'isDemo': isDemo,
  'availability': availability,
  'source': '10x10',
});

void main() {
  // 위젯 테스트에는 실제 웹뷰가 없다. 화면 자체를 검증하기 위해 대역을 꽂는다.
  setUpAll(FakeWebViewPlatform.install);

  testWidgets('상품 보러 가기를 누르면 앱 안에서 판매처 페이지를 연다', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrapWithScope(ProductDetailScreen(product: _product())),
    );
    await tester.pump();

    final Finder cta = find.widgetWithText(FilledButton, '상품 보러 가기');
    expect(cta, findsOneWidget);

    // 외부 브라우저로 던지지 않고 Giftmap 화면을 하나 더 쌓는다.
    await tester.ensureVisible(cta);
    await tester.tap(cta);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(StoreBrowserScreen), findsOneWidget);
  });

  testWidgets('인앱 브라우저에는 뒤로·닫기가 함께 있다', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrapWithScope(StoreBrowserScreen(product: _product())),
    );
    await tester.pump();

    // 구매하지 않기로 한 사람이 곧장 상품 상세로 돌아갈 수 있어야 한다.
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    // 앱 안이 답답할 때를 위한 탈출구.
    expect(find.byIcon(Icons.open_in_new), findsOneWidget);
    // 어느 판매처인지 알려 준다.
    expect(find.text('텐바이텐'), findsOneWidget);
  });

  testWidgets('닫기를 누르면 상품 상세로 돌아온다', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrapWithScope(ProductDetailScreen(product: _product())),
    );
    await tester.pump();

    final Finder cta = find.widgetWithText(FilledButton, '상품 보러 가기');
    await tester.ensureVisible(cta);
    await tester.tap(cta);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(StoreBrowserScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    // 화면을 닫는 전환이 끝날 때까지 기다린다.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(StoreBrowserScreen), findsNothing);
    expect(find.byType(ProductDetailScreen), findsOneWidget);
  });

  testWidgets('주소가 없는 상품은 CTA 가 잠겨 있다', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrapWithScope(ProductDetailScreen(product: _product(productUrl: null))),
    );
    await tester.pump();

    final FilledButton cta = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '상품 보러 가기'),
    );
    expect(cta.onPressed, isNull);
  });

  testWidgets('품절 상품은 CTA 가 잠기고 품절로 표시된다', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrapWithScope(
        ProductDetailScreen(product: _product(availability: 'out_of_stock')),
      ),
    );
    await tester.pump();

    final FilledButton cta = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '품절'),
    );
    expect(cta.onPressed, isNull);
  });
}
