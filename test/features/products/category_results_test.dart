import 'package:flutter_test/flutter_test.dart';
import 'package:giftmap/features/gift_finder/domain/gift_intent.dart';
import 'package:giftmap/features/products/domain/product.dart';
import 'package:giftmap/features/products/domain/product_catalog.dart';

/// 주요 선물 카테고리마다 그 분야 상품과, 섞이기 쉬운 상품을 함께 넣는다.
/// 카테고리를 고르면 그 분야 상품만 나오는지 확인하기 위해서다.
const List<(String, String, String)> _fixtures = <(String, String, String)>[
  ('perfume', '오 드 퍼퓸 타입 N 50ml', '아비브'),
  ('beauty', '센슈얼 누드 립스틱 5g', '헤라'),
  ('body_care', '샤넬 5 레뮐지옹 바디 로션 200ml', '샤넬'),
  ('hand_care', '핸드크림 세트 3종', '이솝'),
  ('dessert', '바크 초콜릿 박스', '디비디'),
  ('tea_coffee', '유리다기세트 GW02', '청백원'),
  ('tumbler', '캠핑 법랑컵 350ml', '욜로브'),
  ('living', '올스텐 무광 수저 세트', '다이소'),
  ('fashion_clothing', '소버린 레터링 롱슬리브 블랙', '다미쉬'),
  ('fashion_accessory', '프렌즈 페이스 통통 키링', '피너츠'),
  ('shoes', '여성 메리제인 플랫 구두', '샤베트'),
  ('bag', '에센셜 스트라이프 숄더백', '굿나잇데이브'),
  ('stationery', '하루 한 페이지 다이어리 2027', 'MD'),
  ('candle', '히노키 캔들 향초 편백향', '자아 라이브러리'),
  ('appliance', '무지개 빔 메이커 무드등', '잼몬스터'),
  ('hobby', '코닥 M38 다회용 필름카메라', '필름공구'),
  ('book', '무라카미 하루키 소설집', '문학동네'),
];

ProductCatalog _catalog() {
  final List<Product> products = <Product>[
    for (final (String category, String name, String brand) in _fixtures)
      for (int i = 0; i < 3; i += 1)
        Product.fromJson(<String, Object?>{
          'id': '$category-$i',
          'brandName': brand,
          'productName': '$name $i',
          'category': category,
          'categoryLabel': category,
          'price': 10000 + i * 5000,
          'productUrl': 'https://example.test/$category/$i',
          'imageUrl': 'https://example.test/$category/$i.jpg',
          'isDemo': false,
          'source': i.isEven ? '10x10' : 'daiso',
          'availability': 'in_stock',
          'recommendationKeywords': <String>[name.split(' ').first],
        }),
  ];
  return ProductCatalog(products: products, version: 'test', disclaimer: '');
}

void main() {
  final ProductCatalog catalog = _catalog();

  group('카테고리를 고르면 그 분야 상품만 나온다', () {
    for (final (String category, _, _) in _fixtures) {
      test(category, () {
        final List<Product> results = catalog.search('', category: category);

        expect(results, isNotEmpty, reason: '$category 결과가 비어 있다');
        expect(
          results.every((Product p) => p.category == category),
          isTrue,
          reason: '$category 에 다른 분야 상품이 섞였다',
        );
      });
    }
  });

  test('카테고리 목록은 실제로 상품이 있는 분야만 준다', () {
    final Set<String> ids = catalog.categories
        .map((({String id, String label}) c) => c.id)
        .toSet();

    expect(ids.length, _fixtures.length);
    expect(ids, contains('perfume'));
    // 상품이 없는 분야는 고를 수 없어야 한다.
    expect(ids, isNot(contains('music')));
  });

  group('세부 키워드로 찾으면 관련 상품이 나온다', () {
    const Map<String, String> cases = <String, String>{
      '퍼퓸': 'perfume',
      '립스틱': 'beauty',
      '핸드크림': 'hand_care',
      '초콜릿': 'dessert',
      '다기세트': 'tea_coffee',
      '법랑컵': 'tumbler',
      '롱슬리브': 'fashion_clothing',
      '키링': 'fashion_accessory',
      '구두': 'shoes',
      '숄더백': 'bag',
      '다이어리': 'stationery',
      '향초': 'candle',
      '무드등': 'appliance',
      '필름카메라': 'hobby',
    };

    cases.forEach((String keyword, String expected) {
      test('$keyword → $expected', () {
        final List<Product> results = catalog.search(keyword);

        expect(results, isNotEmpty, reason: '"$keyword" 결과가 비어 있다');
        expect(results.first.category, expected);
      });
    });
  });

  test('예산 구간 필터가 그 구간만 준다', () {
    final List<Product> cheap = catalog.search(
      '',
      priceRange: BudgetBand.from10kTo30k,
    );

    expect(cheap, isNotEmpty);
    expect(
      cheap.every((Product p) => p.price! >= 10000 && p.price! <= 30000),
      isTrue,
    );
  });

  test('정렬을 바꾸면 순서가 바뀌고 결과 수는 같다', () {
    final List<Product> low = catalog.search('', sort: ProductSort.priceLow);
    final List<Product> high = catalog.search('', sort: ProductSort.priceHigh);

    expect(low.length, high.length);
    expect(low.first.price! <= low.last.price!, isTrue);
    expect(high.first.price! >= high.last.price!, isTrue);
  });

  test('맞는 상품이 없으면 빈 결과를 준다', () {
    expect(catalog.search('이런상품은없다'), isEmpty);
    expect(catalog.search('', category: '없는카테고리'), isEmpty);
  });
}
