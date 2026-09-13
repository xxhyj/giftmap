import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftmap/features/products/domain/product.dart';
import 'package:giftmap/features/products/presentation/widgets/paged_product_grid.dart';

import '../../helpers/scope_harness.dart';

Product _product(int index) => Product.fromJson(<String, Object?>{
  'id': 'p${index.toString().padLeft(3, '0')}',
  'productName': '상품 $index',
  'category': 'stationery',
  'categoryLabel': '문구',
  'price': 10000 + index,
  'isDemo': false,
});

Widget _host(List<Product> products, {int pageSize = 30}) => wrapWithScope(
  ListView(
    children: <Widget>[
      PagedProductGrid(products: products, pageSize: pageSize, onOpen: (_) {}),
    ],
  ),
  products: products,
);

void main() {
  testWidgets('처음에는 한 페이지만 그린다', (WidgetTester tester) async {
    final List<Product> products = List<Product>.generate(90, _product);
    await tester.pumpWidget(_host(products, pageSize: 10));

    expect(find.text('더 보기 (10 / 90)'), findsOneWidget);
  });

  testWidgets('끝까지 스크롤하면 다음 묶음이 자동으로 이어진다', (WidgetTester tester) async {
    final List<Product> products = List<Product>.generate(90, _product);
    await tester.pumpWidget(_host(products, pageSize: 10));

    // 목록 끝으로 내려가면 더 보기를 누르지 않아도 이어 붙는다.
    await tester.ensureVisible(find.text('더 보기 (10 / 90)'));
    await tester.pump();

    expect(find.text('더 보기 (10 / 90)'), findsNothing);
    expect(find.textContaining('더 보기 (20 / 90)'), findsOneWidget);
  });

  testWidgets('더 보기 버튼으로도 다음 묶음을 볼 수 있다', (WidgetTester tester) async {
    final List<Product> products = List<Product>.generate(90, _product);
    await tester.pumpWidget(_host(products, pageSize: 10));

    // 스크롤 없이 버튼만 눌러도 늘어난다(스크롤이 닿지 않는 상황 대비).
    final PagedProductGrid grid = tester.widget<PagedProductGrid>(
      find.byType(PagedProductGrid),
    );
    expect(grid.pageSize, 10);

    final Finder button = find.widgetWithText(OutlinedButton, '더 보기 (10 / 90)');
    expect(button, findsOneWidget);
    tester.widget<OutlinedButton>(button).onPressed!.call();
    await tester.pump();

    expect(find.text('더 보기 (20 / 90)'), findsOneWidget);
  });

  testWidgets('상품이 한 페이지보다 적으면 더 보기를 두지 않는다', (WidgetTester tester) async {
    await tester.pumpWidget(_host(List<Product>.generate(5, _product)));

    expect(find.textContaining('더 보기'), findsNothing);
  });

  testWidgets('목록이 바뀌면 처음부터 다시 보여 준다', (WidgetTester tester) async {
    await tester.pumpWidget(
      _host(List<Product>.generate(90, _product), pageSize: 10),
    );
    await tester.ensureVisible(find.text('더 보기 (10 / 90)'));
    await tester.pump();
    expect(find.text('더 보기 (20 / 90)'), findsOneWidget);

    // 필터를 바꾼 상황: 새 목록이 들어온다.
    await tester.pumpWidget(
      _host(List<Product>.generate(50, _product), pageSize: 10),
    );
    await tester.pump();

    expect(find.text('더 보기 (10 / 50)'), findsOneWidget);
  });
}
