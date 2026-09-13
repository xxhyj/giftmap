import 'package:flutter_test/flutter_test.dart';
import 'package:giftmap/features/gift_finder/data/ai_recommendation_service.dart';
import 'package:giftmap/features/gift_finder/data/product_recommendation_engine.dart';
import 'package:giftmap/features/gift_finder/domain/gift_intent.dart';
import 'package:giftmap/features/products/domain/product.dart';
import 'package:giftmap/features/products/domain/product_catalog.dart';

/// 서버 응답을 흉내 내는 구현. 네트워크를 쓰지 않는다.
///
/// 진짜 구현과 같은 규칙을 따른다: 카탈로그에 없는 id는 버리고,
/// 살아남은 상품이 3개 미만이면 null(= 기존 엔진에 맡김)이다.
final class FakeAiService implements AiRecommendationService {
  FakeAiService(this.serverPicks);

  /// 서버가 돌려줬다고 가정하는 (상품 id, 이유) 목록.
  final List<(String, String)> serverPicks;

  @override
  Future<List<ProductPick>?> recommend(
    GiftIntent intent, {
    required ProductCatalog catalog,
  }) async {
    final List<ProductPick> picks = <ProductPick>[];
    final Set<String> seen = <String>{};
    for (final (String id, String reason) in serverPicks) {
      if (!seen.add(id)) continue;
      final Product? product = catalog.byId(id);
      if (product == null) continue;
      picks.add(
        ProductPick(
          product: product,
          score: 0,
          riskLevel: RiskLevel.safe,
          badge: 'AI 추천',
          reason: reason,
        ),
      );
    }
    return picks.length >= 3 ? picks : null;
  }
}

Product _product(String id) => Product.fromJson(<String, Object?>{
  'id': id,
  'productName': '상품 $id',
  'category': 'stationery',
  'categoryLabel': '문구',
  'price': 10000,
  'productUrl': 'https://example.test/p/$id',
  'isDemo': false,
});

ProductCatalog _catalog() => ProductCatalog(
  products: <Product>[_product('a'), _product('b'), _product('c')],
  version: 'supabase',
  disclaimer: '',
);

const GiftIntent _intent = GiftIntent(
  situation: GiftSituation.birthday,
  relationship: RelationshipType.friend,
  ageBand: AgeBand.twenties,
  budget: BudgetBand.from10kTo30k,
  preference: 0.5,
);

void main() {
  test('DB에 있는 상품만 추천으로 남는다', () async {
    final FakeAiService service = FakeAiService(<(String, String)>[
      ('a', '취향에 맞아요'),
      ('b', '예산에 맞아요'),
      ('c', '무난해요'),
    ]);

    final List<ProductPick>? picks = await service.recommend(
      _intent,
      catalog: _catalog(),
    );

    expect(picks, isNotNull);
    expect(picks!.length, 3);
    expect(picks.every((ProductPick p) => !p.product.isDemo), isTrue);
    expect(picks.first.reason, '취향에 맞아요');
  });

  test('서버가 없는 상품을 말하면 버린다', () async {
    final FakeAiService service = FakeAiService(<(String, String)>[
      ('a', ''),
      ('b', ''),
      ('c', ''),
      ('지어낸-상품', '존재하지 않음'),
    ]);

    final List<ProductPick>? picks = await service.recommend(
      _intent,
      catalog: _catalog(),
    );

    expect(picks!.length, 3);
    expect(
      picks.map((ProductPick p) => p.product.id),
      isNot(contains('지어낸-상품')),
    );
  });

  test('실제 상품이 3개 미만이면 기존 엔진에 맡긴다', () async {
    final FakeAiService service = FakeAiService(<(String, String)>[
      ('a', ''),
      ('없는-id', ''),
    ]);

    expect(await service.recommend(_intent, catalog: _catalog()), isNull);
  });

  test('같은 상품을 두 번 추천하지 않는다', () async {
    final FakeAiService service = FakeAiService(<(String, String)>[
      ('a', ''),
      ('a', ''),
      ('b', ''),
      ('c', ''),
    ]);

    final List<ProductPick>? picks = await service.recommend(
      _intent,
      catalog: _catalog(),
    );

    expect(picks!.length, 3);
    expect(picks.map((ProductPick p) => p.product.id).toSet().length, 3);
  });
}
