import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftmap/features/gift_finder/data/bundled_category_data_source.dart';
import 'package:giftmap/features/gift_finder/domain/gift_category.dart';
import 'package:giftmap/features/gift_finder/domain/gift_ruleset.dart';

/// 테스트용 asset 번들. 원하는 문자열을 그대로 돌려준다.
class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.contents);

  final Map<String, String> contents;

  @override
  Future<ByteData> load(String key) async {
    final String? value = contents[key];
    if (value == null) throw StateError('missing asset $key');
    final List<int> bytes = utf8.encode(value);
    return ByteData.view(Uint8List.fromList(bytes).buffer);
  }
}

void main() {
  test('정상 JSON은 카테고리와 규칙을 모두 읽는다', () async {
    final BundledCategoryDataSource source = BundledCategoryDataSource(
      bundle: _FakeBundle(<String, String>{
        BundledCategoryDataSource.categoriesAsset: jsonEncode(<String, Object?>{
          'rulesetVersion': 'test.1',
          'priceDisclaimer': '데모 가격',
          'categories': <Object?>[
            for (int i = 0; i < 3; i++)
              <String, Object?>{
                'id': 'cat_$i',
                'title': '카테고리 $i',
                'preference': 0.5,
                'priceMin': 10000,
                'priceMedian': 20000,
                'priceMax': 30000,
                'tags': <String>['home'],
                'situations': <String>['birthday'],
                'relationships': <String>['friend'],
                'safeDefault': true,
              },
          ],
        }),
        BundledCategoryDataSource.rulesAsset: jsonEncode(<String, Object?>{
          'rules': <Object?>[
            <String, Object?>{
              'id': 'r1',
              'level': 'caution',
              'penalty': 5,
              'tags': <String>['home'],
              'message': '주의',
            },
          ],
        }),
        BundledCategoryDataSource.queriesAsset: jsonEncode(<String, Object?>{
          'templates': <String>['{relationship} {category}'],
        }),
      }),
    );

    final GiftRuleset ruleset = await source.load();
    expect(ruleset.version, 'test.1');
    expect(ruleset.categories.length, 3);
    expect(ruleset.rules.length, 1);
    expect(ruleset.queryTemplates.length, 1);
  });

  test('손상된 JSON이면 안전한 기본 카테고리로 진입한다', () async {
    final BundledCategoryDataSource source = BundledCategoryDataSource(
      bundle: _FakeBundle(<String, String>{
        BundledCategoryDataSource.categoriesAsset: '{"categories": [',
        BundledCategoryDataSource.rulesAsset: '{}',
        BundledCategoryDataSource.queriesAsset: '{}',
      }),
    );

    final GiftRuleset ruleset = await source.load();
    expect(ruleset.version, 'safe-default');
    expect(ruleset.categories.length, 3);
    expect(ruleset.isUsable, isTrue);
  });

  test('카테고리가 부족하면 안전한 기본값으로 대체한다', () async {
    final BundledCategoryDataSource source = BundledCategoryDataSource(
      bundle: _FakeBundle(<String, String>{
        BundledCategoryDataSource.categoriesAsset: jsonEncode(<String, Object?>{
          'categories': <Object?>[],
        }),
        BundledCategoryDataSource.rulesAsset: '{}',
        BundledCategoryDataSource.queriesAsset: '{}',
      }),
    );

    final GiftRuleset ruleset = await source.load();
    expect(ruleset.version, 'safe-default');
  });

  test('가격 범위가 잘못된 카테고리는 스키마 검증에서 걸러진다', () {
    expect(
      () => GiftCategory.fromJson(<String, Object?>{
        'id': 'broken',
        'title': '잘못된 카테고리',
        'priceMin': 50000,
        'priceMedian': 10000,
        'priceMax': 20000,
      }),
      throwsFormatException,
    );
  });

  test('id나 title이 없으면 스키마 검증에서 걸러진다', () {
    expect(
      () => GiftCategory.fromJson(<String, Object?>{'title': '이름만 있음'}),
      throwsFormatException,
    );
  });

  test('지원하지 않는 enum 값은 조용히 무시한다', () {
    final GiftCategory category = GiftCategory.fromJson(<String, Object?>{
      'id': 'ok',
      'title': '정상',
      'priceMin': 1000,
      'priceMedian': 2000,
      'priceMax': 3000,
      'situations': <String>['birthday', 'unknown_situation'],
      'relationships': <String>['friend', 'robot'],
    });

    expect(category.situations.length, 1);
    expect(category.relationships.length, 1);
    expect(category.priceAvailable, isTrue);
  });
}
