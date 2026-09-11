import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftmap/features/gift_finder/domain/gift_intent.dart';
import 'package:giftmap/features/products/domain/product.dart';
import 'package:giftmap/features/products/presentation/widgets/product_card.dart';
import 'package:giftmap/features/products/presentation/widgets/product_visual.dart';

Product productOf({int price = 49000, int? originalPrice}) {
  return Product(
    id: 'demo_01',
    brandName: '무드셀렉트',
    productName: '데이브레이크 오 드 뚜왈렛 50ml',
    category: 'perfume',
    categoryLabel: '향수',
    subCategory: '오 드 뚜왈렛',
    price: price,
    originalPrice: originalPrice,
    discountRate: originalPrice == null
        ? null
        : (((originalPrice - price) * 100) / originalPrice).round(),
    tags: const <String>['scent'],
    occasions: const <GiftSituation>[GiftSituation.birthday],
    recipientTypes: const <RelationshipType>[RelationshipType.friend],
    ageRange: const <AgeBand>[AgeBand.twenties],
    priceRange: BudgetBand.from30kTo50k,
    recommendationKeywords: const <String>['향수'],
    description: '설명',
    recommendationReason: '이유',
    createdAt: DateTime(2026, 9, 11),
  );
}

Future<void> pumpUnder(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  testWidgets('할인이 없으면 판매가만 보여준다', (WidgetTester tester) async {
    await pumpUnder(tester, ProductPrice(product: productOf()));

    expect(find.text('49,000원'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    expect(find.textContaining('0원 '), findsNothing);
  });

  testWidgets('할인이 있으면 할인율·판매가·정가를 함께 보여준다', (WidgetTester tester) async {
    await pumpUnder(
      tester,
      ProductPrice(product: productOf(originalPrice: 68000)),
    );

    expect(find.text('28%'), findsOneWidget);
    expect(find.text('49,000원'), findsOneWidget);
    expect(find.text('68,000원'), findsOneWidget);
  });

  testWidgets('정가가 판매가보다 낮으면 할인으로 취급하지 않는다', (WidgetTester tester) async {
    final Product product = Product.fromJson(<String, Object?>{
      'id': 'x',
      'brandName': 'b',
      'productName': 'n',
      'price': 50000,
      'originalPrice': 40000,
    });

    expect(product.hasDiscount, isFalse);
    expect(product.originalPrice, isNull);
    expect(product.discountRate, isNull);
  });

  testWidgets('이미지 asset이 없어도 상품 비주얼을 그린다', (WidgetTester tester) async {
    await pumpUnder(
      tester,
      SizedBox(width: 160, child: ProductImage(product: productOf())),
    );

    expect(find.byType(ProductImage), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.water_drop_outlined), findsOneWidget);
  });

  testWidgets('데모 배지가 표시된다', (WidgetTester tester) async {
    await pumpUnder(tester, const DemoBadge());
    expect(find.text('데모 상품'), findsOneWidget);
  });
}
