import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftmap/features/gift_finder/domain/gift_intent.dart';
import 'package:giftmap/features/products/domain/product.dart';
import 'package:giftmap/features/products/domain/product_catalog.dart';
import 'package:giftmap/features/products/presentation/widgets/product_card.dart';
import 'package:giftmap/features/products/presentation/widgets/product_collections.dart';
import 'package:giftmap/features/products/presentation/widgets/product_visual.dart';

import '../../helpers/scope_harness.dart';

const String longKoreanName =
    '아주 길고 자세한 이름을 가진 프리미엄 홈 프래그런스 기프트 세트 '
    '리드 디퓨저 200ml 리필 포함 선물 포장 구성';
const String longEnglishBrand =
    'Very Long Demonstration Brand Name Studio Atelier Collection';

Product productOf({
  int? price = 49000,
  int? originalPrice,
  String? brandName = '무드셀렉트',
  String name = '데이브레이크 오 드 뚜왈렛 50ml',
  String? imageAsset,
  String? productUrl,
}) {
  return Product(
    id: 'demo_01',
    brandName: brandName,
    productName: name,
    category: 'perfume',
    categoryLabel: '향수',
    subCategory: '오 드 뚜왈렛',
    price: price,
    originalPrice: originalPrice,
    discountRate: (originalPrice == null || price == null)
        ? null
        : (((originalPrice - price) * 100) / originalPrice).round(),
    imageAsset: imageAsset,
    productUrl: productUrl,
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
  group('가격 표기', () {
    testWidgets('할인이 없으면 판매가만 보여준다', (WidgetTester tester) async {
      await pumpUnder(tester, ProductPrice(product: productOf()));

      expect(find.text('49,000원'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
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

    testWidgets('가격이 없으면 0원이 아니라 확인 필요로 표시한다', (WidgetTester tester) async {
      await pumpUnder(tester, ProductPrice(product: productOf(price: null)));

      expect(find.text('가격 확인 필요'), findsOneWidget);
      expect(find.textContaining('0원'), findsNothing);
    });

    testWidgets('정가가 판매가보다 낮으면 할인으로 취급하지 않는다', (WidgetTester tester) async {
      final Product product = Product.fromJson(<String, Object?>{
        'id': 'x',
        'productName': 'n',
        'price': 50000,
        'originalPrice': 40000,
      });

      expect(product.hasDiscount, isFalse);
      expect(product.originalPrice, isNull);
      expect(product.discountRate, isNull);
    });
  });

  group('null 필드', () {
    test('브랜드가 없으면 카테고리 이름으로 대신 보여준다', () {
      final Product product = productOf(brandName: null);
      expect(product.brandLabel, '향수');
    });

    test('가격이 없어도 모델이 만들어지고 정렬에서 뒤로 간다', () {
      final Product product = Product.fromJson(<String, Object?>{
        'id': 'x',
        'productName': '가격 미확인 상품',
      });
      expect(product.hasPrice, isFalse);
      expect(product.price, isNull);
      expect(product.sortPrice, greaterThan(1000000));
    });

    test('productUrl은 기본적으로 없다', () {
      expect(productOf().productUrl, isNull);
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
  });

  group('긴 텍스트', () {
    testWidgets('상품명은 2줄, 브랜드는 1줄로 말줄임한다', (WidgetTester tester) async {
      await pumpUnder(
        tester,
        SizedBox(
          width: 170,
          height: 320,
          child: ProductRowCardTestHost(
            product: productOf(
              name: longKoreanName,
              brandName: longEnglishBrand,
            ),
          ),
        ),
      );

      final Text name = tester.widget<Text>(find.text(longKoreanName));
      expect(name.maxLines, ProductTextLines.name);
      expect(name.overflow, TextOverflow.ellipsis);

      final Text brand = tester.widget<Text>(find.text(longEnglishBrand));
      expect(brand.maxLines, ProductTextLines.brand);
      expect(brand.overflow, TextOverflow.ellipsis);

      expect(tester.takeException(), isNull);
    });

    testWidgets('긴 이름이어도 가격이 사라지지 않는다', (WidgetTester tester) async {
      await pumpUnder(
        tester,
        SizedBox(
          width: 170,
          height: 320,
          child: ProductRowCardTestHost(
            product: productOf(name: longKoreanName),
          ),
        ),
      );

      expect(find.text('49,000원'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('상품 수가 바뀌어도 화면이 동작한다', () {
    Future<void> pumpGrid(WidgetTester tester, int count) async {
      final List<Product> products = List<Product>.generate(
        count,
        (int i) => Product(
          id: 'p$i',
          productName: '데모 상품 $i',
          category: 'perfume',
          categoryLabel: '향수',
          subCategory: '',
          price: 10000 + i,
          tags: const <String>[],
          occasions: const <GiftSituation>[],
          recipientTypes: const <RelationshipType>[],
          ageRange: const <AgeBand>[],
          priceRange: BudgetBand.from10kTo30k,
          recommendationKeywords: const <String>[],
          description: '',
          recommendationReason: '',
          createdAt: DateTime(2026),
        ),
      );
      await tester.pumpWidget(
        wrapWithScope(
          SizedBox(
            width: 360,
            height: 640,
            child: ProductGrid(products: products, onOpen: (_) {}),
          ),
          products: products,
        ),
      );
      await tester.pump();
    }

    testWidgets('상품이 0개면 아무 카드도 그리지 않는다', (WidgetTester tester) async {
      await pumpGrid(tester, 0);
      expect(find.byType(ProductGridCard), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('상품이 1개여도 정상 렌더링된다', (WidgetTester tester) async {
      await pumpGrid(tester, 1);
      expect(find.byType(ProductGridCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('상품이 많아도 정상 렌더링된다', (WidgetTester tester) async {
      await pumpGrid(tester, 24);
      expect(find.byType(ProductGridCard), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('카탈로그 빈 상태', () {
    test('빈 카탈로그도 안전하게 조회된다', () {
      final ProductCatalog empty = ProductCatalog(
        products: const <Product>[],
        version: 'empty',
        disclaimer: '데모',
      );
      expect(empty.isEmpty, isTrue);
      expect(empty.categories, isEmpty);
      expect(empty.search('아무거나'), isEmpty);
      expect(empty.popular, isEmpty);
      expect(empty.byPriceUnder(30000), isEmpty);
    });
  });
}

/// 찜 버튼은 AppScope를 필요로 하므로, 텍스트 규칙만 확인할 때는
/// trailing을 비워 둔 호스트를 쓴다.
class ProductRowCardTestHost extends StatelessWidget {
  const ProductRowCardTestHost({required this.product, super.key});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return ProductRowCard(
      product: product,
      onTap: () {},
      trailing: const SizedBox.shrink(),
    );
  }
}
