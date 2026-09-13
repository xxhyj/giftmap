import 'package:flutter_test/flutter_test.dart';
import 'package:giftmap/app/giftmap_app.dart';
import 'package:giftmap/features/library/data/in_memory_id_list_storage.dart';
import 'package:giftmap/features/products/data/bundled_product_data_source.dart';
import 'package:giftmap/features/products/domain/product.dart';
import 'package:giftmap/features/products/domain/product_catalog.dart';
import 'package:giftmap/features/splash/presentation/load_failure_screen.dart';
import 'package:giftmap/features/splash/presentation/splash_screen.dart';

/// 원격에서 실제 상품을 읽는 데이터 소스를 흉내 낸다.
final class _FakeRemoteSource implements ProductDataSource {
  _FakeRemoteSource({this.failTimes = 0, this.products = const <Product>[]});

  /// 이 횟수만큼은 실패하고, 그다음부터 성공한다. 재시도 검증에 쓴다.
  int failTimes;
  final List<Product> products;
  int calls = 0;

  @override
  Future<ProductCatalog> load() async {
    calls += 1;
    if (failTimes > 0) {
      failTimes -= 1;
      throw StateError('네트워크 실패');
    }
    return ProductCatalog(
      products: products,
      version: 'supabase',
      disclaimer: '',
    );
  }
}

Product _realProduct(String id) => Product.fromJson(<String, Object?>{
  'id': id,
  'productName': '실제 상품 $id',
  'category': 'stationery',
  'categoryLabel': '문구',
  'price': 12000,
  'productUrl': 'https://example.test/p/$id',
  'imageUrl': 'https://example.test/i/$id.jpg',
  'isDemo': false,
  'inStock': true,
  'source': '10x10',
});

/// 스플래시에는 계속 도는 로딩 표시가 있어 pumpAndSettle 이 끝나지 않는다.
/// 스플래시를 벗어날 때까지만 프레임을 흘린다.
Future<void> _settleBootstrap(WidgetTester tester) async {
  for (int i = 0; i < 60; i += 1) {
    // 번들 asset 읽기는 진짜 비동기라 실제 시간을 흘려 줘야 진행된다.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
    if (find.byType(SplashScreen).evaluate().isEmpty) return;
  }
}

void main() {
  testWidgets('실패하면 재시도 화면을 보여 주고, 다시 시도하면 복구된다', (WidgetTester tester) async {
    final _FakeRemoteSource source = _FakeRemoteSource(
      failTimes: 1,
      products: <Product>[_realProduct('a')],
    );

    await tester.pumpWidget(
      GiftmapApp(productDataSource: source, storage: InMemoryIdListStorage()),
    );
    await _settleBootstrap(tester);

    // 실패를 데모 상품으로 덮지 않고 그대로 알린다.
    expect(find.byType(LoadFailureScreen), findsOneWidget);
    expect(find.text('상품을 불러오지 못했어요'), findsOneWidget);
    expect(find.text('데모 상품'), findsNothing);
    expect(source.calls, 1);

    await tester.tap(find.text('다시 시도'));
    await _settleBootstrap(tester);

    expect(find.byType(LoadFailureScreen), findsNothing);
    expect(source.calls, 2);
  });

  test('실제 상품은 데모 배지 없이 판매 페이지로 이동할 수 있다', () {
    final Product product = _realProduct('a');
    expect(product.isDemo, isFalse);
    expect(product.canOpenStore, isTrue);
    expect(product.isSoldOut, isFalse);
    expect(product.sourceLabel, '텐바이텐');
  });

  test('품절은 알려 줄 때만 품절로 본다', () {
    final Product unknown = Product.fromJson(<String, Object?>{
      'id': 'x',
      'productName': '재고 모름',
      'isDemo': false,
    });
    expect(unknown.inStock, isNull);
    expect(unknown.isSoldOut, isFalse);
  });
}
