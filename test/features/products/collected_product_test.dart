import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftmap/features/products/domain/product.dart';
import 'package:giftmap/features/products/presentation/widgets/product_visual.dart';

/// `crawler/`가 수집해 Supabase에 올린 실제 상품 한 건.
Map<String, Object?> _collectedJson({Object? imageUrl, Object? productUrl}) {
  return <String, Object?>{
    'id': '10x10-7670388',
    'brandName': '웨이투페치',
    'productName': '코지 무드 노트',
    'category': 'stationery',
    'categoryLabel': '문구',
    'price': 8010,
    'originalPrice': 8900,
    'imageUrl': imageUrl,
    'productUrl': productUrl,
    'isDemo': false,
  };
}

void main() {
  test('수집 상품은 데모와 구분되고 판매 페이지를 열 수 있다', () {
    final Product product = Product.fromJson(
      _collectedJson(
        imageUrl: 'https://example.test/a.jpg',
        productUrl: 'https://example.test/p/1',
      ),
    );

    expect(product.isDemo, isFalse);
    expect(product.imageUrl, 'https://example.test/a.jpg');
    expect(product.canOpenStore, isTrue);
    expect(product.discountRate, 10);
  });

  test('판매 페이지 주소가 없으면 CTA를 활성화하지 않는다', () {
    final Product product = Product.fromJson(_collectedJson());
    expect(product.canOpenStore, isFalse);
  });

  test('데모 상품은 주소가 있어도 판매 페이지로 보내지 않는다', () {
    final Product product = Product.fromJson(<String, Object?>{
      ..._collectedJson(productUrl: 'https://example.test/p/1'),
      'isDemo': true,
    });
    expect(product.canOpenStore, isFalse);
  });

  testWidgets('이미지 URL이 없으면 카테고리 비주얼로 되돌아간다', (WidgetTester tester) async {
    final Product product = Product.fromJson(_collectedJson());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProductImage(product: product)),
      ),
    );

    expect(find.byType(Image), findsNothing);
    expect(find.byType(ProductImage), findsOneWidget);
  });

  testWidgets('이미지 URL이 있으면 원격 이미지를 그린다', (WidgetTester tester) async {
    final Product product = Product.fromJson(
      _collectedJson(imageUrl: 'https://example.test/a.jpg'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProductImage(product: product)),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
  });
}
