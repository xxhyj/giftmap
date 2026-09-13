// 로컬 Mock 데이터(lib/data/products.json)를 Supabase seed SQL로 변환한다.
//
// 실행:
//   dart run tool/generate_supabase_seed.dart
//
// 상품 개수를 가정하지 않고 JSON에 들어 있는 만큼 그대로 내보낸다.
// 카테고리 상위 그룹은 lib/features/categories/domain/category_group.dart와
// 같은 묶음을 쓴다.
import 'dart:convert';
import 'dart:io';

const String _productsJson = 'lib/data/products.json';
const String _outputPath = 'supabase/seed/0002_seed_demo_data.sql';

/// 카테고리 상위 그룹. 앱의 `CategoryGroup`과 같은 구성이다.
const Map<String, ({String id, String label})> _groupOfCategory =
    <String, ({String id, String label})>{
      'perfume': (id: 'beauty_care', label: '뷰티·케어'),
      'hand_care': (id: 'beauty_care', label: '뷰티·케어'),
      'body_care': (id: 'beauty_care', label: '뷰티·케어'),
      'beauty': (id: 'beauty_care', label: '뷰티·케어'),
      'tea_coffee': (id: 'food_drink', label: '푸드·디저트'),
      'dessert': (id: 'food_drink', label: '푸드·디저트'),
      'candle': (id: 'home_living', label: '홈·리빙'),
      'homewear': (id: 'home_living', label: '홈·리빙'),
      'living': (id: 'home_living', label: '홈·리빙'),
      'tumbler': (id: 'home_living', label: '홈·리빙'),
      'stationery': (id: 'desk_stationery', label: '문구·데스크'),
      'desk': (id: 'desk_stationery', label: '문구·데스크'),
      'fashion_accessory': (id: 'fashion', label: '패션·잡화'),
      'wallet': (id: 'fashion', label: '패션·잡화'),
      'hobby': (id: 'hobby', label: '취미·라이프스타일'),
    };

/// 홈 큐레이션 묶음. 상품은 조건에 맞는 것을 seed에서 연결한다.
const List<({String id, String title, String subtitle})> _collections =
    <({String id, String title, String subtitle})>[
      (
        id: 'spotlight',
        title: '요즘 눈여겨볼 선물',
        subtitle: '지금 할인 중인 데모 상품',
      ),
      (
        id: 'giftmap_picks',
        title: 'Giftmap 추천 상품',
        subtitle: '상황을 가리지 않고 무난한 선택',
      ),
      (
        id: 'under_30k',
        title: '부담 없이 마음을 전하기 좋은 선물',
        subtitle: '가볍게 건네기 좋은 가격대',
      ),
    ];

void main() {
  final File source = File(_productsJson);
  if (!source.existsSync()) {
    stderr.writeln('$_productsJson 을 찾을 수 없습니다.');
    exitCode = 1;
    return;
  }

  final Map<String, Object?> doc =
      jsonDecode(source.readAsStringSync()) as Map<String, Object?>;
  final List<Map<String, Object?>> products =
      (doc['products'] as List<Object?>).cast<Map<String, Object?>>();
  final List<String> suggestions = (doc['searchSuggestions'] as List<Object?>?)
      ?.map((Object? e) => e.toString())
      .toList(growable: false) ??
      const <String>[];

  final StringBuffer out = StringBuffer()
    ..writeln('-- Giftmap · 데모 데이터 seed')
    ..writeln('-- 자동 생성 파일입니다. 직접 고치지 말고 아래 명령으로 다시 만드세요.')
    ..writeln('--   dart run tool/generate_supabase_seed.dart')
    ..writeln('--')
    ..writeln('-- 실행 순서: migrations/0001_init_schema.sql 을 먼저 실행한 뒤 이 파일을 실행합니다.')
    ..writeln('-- 모든 상품은 is_demo = true 입니다. 실제 판매 상품이 아닙니다.')
    ..writeln()
    ..writeln('begin;')
    ..writeln();

  _writeCategories(out, products);
  _writeProducts(out, products);
  _writeProductCategories(out, products);
  _writeCollections(out, products);
  _writeSuggestions(out, suggestions);

  out
    ..writeln('commit;')
    ..writeln()
    ..writeln('-- 확인용 조회')
    ..writeln('-- select count(*) from public.products where is_active;')
    ..writeln('-- select count(*) from public.categories where is_active;');

  final File target = File(_outputPath);
  target.parent.createSync(recursive: true);
  target.writeAsStringSync(out.toString());

  stdout.writeln(
    '생성 완료: $_outputPath '
    '(상품 ${products.length}개, 추천 검색어 ${suggestions.length}개)',
  );
}

void _writeCategories(StringBuffer out, List<Map<String, Object?>> products) {
  final Map<String, String> labels = <String, String>{};
  for (final Map<String, Object?> product in products) {
    final String id = product['category']!.toString();
    labels.putIfAbsent(id, () => product['categoryLabel']?.toString() ?? id);
  }
  final List<String> ids = labels.keys.toList()..sort();

  out
    ..writeln('-- categories ------------------------------------------------')
    ..writeln(
      'insert into public.categories '
      '(id, label, group_id, group_label, sort_order) values',
    );

  final List<String> rows = <String>[];
  for (int i = 0; i < ids.length; i++) {
    final String id = ids[i];
    final ({String id, String label})? group = _groupOfCategory[id];
    rows.add(
      '  (${_text(id)}, ${_text(labels[id]!)}, '
      '${_text(group?.id)}, ${_text(group?.label)}, ${i + 1})',
    );
  }
  out
    ..writeln(rows.join(',\n'))
    ..writeln('on conflict (id) do update set')
    ..writeln('  label = excluded.label,')
    ..writeln('  group_id = excluded.group_id,')
    ..writeln('  group_label = excluded.group_label,')
    ..writeln('  sort_order = excluded.sort_order,')
    ..writeln('  is_active = true;')
    ..writeln();
}

void _writeProducts(StringBuffer out, List<Map<String, Object?>> products) {
  out
    ..writeln('-- products --------------------------------------------------')
    ..writeln('insert into public.products (')
    ..writeln('  id, brand_name, product_name, category_id, sub_category,')
    ..writeln('  price, original_price, discount_rate, image_asset, product_url,')
    ..writeln('  tags, occasions, recipient_types, gender_target, age_range,')
    ..writeln('  price_range, recommendation_keywords, description,')
    ..writeln('  recommendation_reason, is_demo, sort_order')
    ..writeln(') values');

  final List<String> rows = <String>[];
  for (int i = 0; i < products.length; i++) {
    final Map<String, Object?> p = products[i];
    rows.add(
      '  (${_text(p['id'])}, ${_text(p['brandName'])}, '
      '${_text(p['productName'])}, ${_text(p['category'])}, '
      '${_text(p['subCategory'])},\n'
      '   ${_number(p['price'])}, ${_number(p['originalPrice'])}, '
      '${_number(p['discountRate'])}, ${_text(p['imageAsset'])}, '
      '${_text(p['productUrl'])},\n'
      '   ${_array(p['tags'])}, ${_array(p['occasions'])}, '
      '${_array(p['recipientTypes'])}, ${_text(p['genderTarget'])}, '
      '${_array(p['ageRange'])},\n'
      '   ${_text(p['priceRange'])}, ${_array(p['recommendationKeywords'])}, '
      '${_text(p['description'])},\n'
      '   ${_text(p['recommendationReason'])}, '
      '${p['isDemo'] == false ? 'false' : 'true'}, ${i + 1})',
    );
  }

  out
    ..writeln(rows.join(',\n'))
    ..writeln('on conflict (id) do update set')
    ..writeln('  brand_name = excluded.brand_name,')
    ..writeln('  product_name = excluded.product_name,')
    ..writeln('  category_id = excluded.category_id,')
    ..writeln('  sub_category = excluded.sub_category,')
    ..writeln('  price = excluded.price,')
    ..writeln('  original_price = excluded.original_price,')
    ..writeln('  discount_rate = excluded.discount_rate,')
    ..writeln('  tags = excluded.tags,')
    ..writeln('  occasions = excluded.occasions,')
    ..writeln('  recipient_types = excluded.recipient_types,')
    ..writeln('  age_range = excluded.age_range,')
    ..writeln('  price_range = excluded.price_range,')
    ..writeln('  recommendation_keywords = excluded.recommendation_keywords,')
    ..writeln('  description = excluded.description,')
    ..writeln('  recommendation_reason = excluded.recommendation_reason,')
    ..writeln('  sort_order = excluded.sort_order,')
    ..writeln('  is_active = true;')
    ..writeln();
}

void _writeProductCategories(
  StringBuffer out,
  List<Map<String, Object?>> products,
) {
  out
    ..writeln('-- product_categories ----------------------------------------')
    ..writeln(
      'insert into public.product_categories '
      '(product_id, category_id, is_primary, sort_order) values',
    );

  final List<String> rows = <String>[];
  for (int i = 0; i < products.length; i++) {
    final Map<String, Object?> p = products[i];
    rows.add(
      '  (${_text(p['id'])}, ${_text(p['category'])}, true, ${i + 1})',
    );
  }

  out
    ..writeln(rows.join(',\n'))
    ..writeln('on conflict (product_id, category_id) do update set')
    ..writeln('  is_primary = excluded.is_primary,')
    ..writeln('  sort_order = excluded.sort_order;')
    ..writeln();
}

void _writeCollections(StringBuffer out, List<Map<String, Object?>> products) {
  out
    ..writeln('-- collections -----------------------------------------------')
    ..writeln(
      'insert into public.collections (id, title, subtitle, sort_order) values',
    );
  final List<String> collectionRows = <String>[];
  for (int i = 0; i < _collections.length; i++) {
    final ({String id, String title, String subtitle}) c = _collections[i];
    collectionRows.add(
      '  (${_text(c.id)}, ${_text(c.title)}, ${_text(c.subtitle)}, ${i + 1})',
    );
  }
  out
    ..writeln(collectionRows.join(',\n'))
    ..writeln('on conflict (id) do update set')
    ..writeln('  title = excluded.title,')
    ..writeln('  subtitle = excluded.subtitle,')
    ..writeln('  sort_order = excluded.sort_order,')
    ..writeln('  is_active = true;')
    ..writeln();

  // 큐레이션에 담을 상품을 mock 데이터 기준으로 고른다.
  final List<Map<String, Object?>> discounted = products
      .where((Map<String, Object?> p) => p['originalPrice'] != null)
      .toList(growable: false);
  final List<Map<String, Object?>> broad = products
      .where((Map<String, Object?> p) => (p['occasions'] as List<Object?>).length >= 3)
      .toList(growable: false);
  final List<Map<String, Object?>> cheap = products
      .where(
        (Map<String, Object?> p) =>
            p['price'] is num && (p['price']! as num) <= 30000,
      )
      .toList(growable: false);

  final List<String> rows = <String>[
    ..._collectionRows('spotlight', discounted),
    ..._collectionRows('giftmap_picks', broad),
    ..._collectionRows('under_30k', cheap),
  ];

  if (rows.isEmpty) return;

  out
    ..writeln('-- collection_products --------------------------------------')
    ..writeln(
      'insert into public.collection_products '
      '(collection_id, product_id, sort_order) values',
    )
    ..writeln(rows.join(',\n'))
    ..writeln('on conflict (collection_id, product_id) do update set')
    ..writeln('  sort_order = excluded.sort_order;')
    ..writeln();
}

List<String> _collectionRows(
  String collectionId,
  List<Map<String, Object?>> products,
) {
  final List<String> rows = <String>[];
  for (int i = 0; i < products.length; i++) {
    rows.add(
      '  (${_text(collectionId)}, ${_text(products[i]['id'])}, ${i + 1})',
    );
  }
  return rows;
}

void _writeSuggestions(StringBuffer out, List<String> suggestions) {
  if (suggestions.isEmpty) return;

  out
    ..writeln('-- search_suggestions ---------------------------------------')
    ..writeln(
      'insert into public.search_suggestions (id, keyword, sort_order) values',
    );

  final List<String> rows = <String>[];
  for (int i = 0; i < suggestions.length; i++) {
    rows.add(
      '  (${_text('suggestion_${i + 1}')}, ${_text(suggestions[i])}, ${i + 1})',
    );
  }

  out
    ..writeln(rows.join(',\n'))
    ..writeln('on conflict (id) do update set')
    ..writeln('  keyword = excluded.keyword,')
    ..writeln('  sort_order = excluded.sort_order,')
    ..writeln('  is_active = true;')
    ..writeln();
}

/// SQL 문자열 리터럴. 작은따옴표를 이스케이프한다.
String _text(Object? value) {
  if (value == null) return 'null';
  final String text = value.toString();
  if (text.isEmpty) return "''";
  return "'${text.replaceAll("'", "''")}'";
}

String _number(Object? value) => value == null ? 'null' : value.toString();

String _array(Object? value) {
  if (value is! List || value.isEmpty) return "'{}'";
  final String items = value
      .map((Object? e) => '"${e.toString().replaceAll('"', r'\"')}"')
      .join(',');
  return "'{$items}'";
}
