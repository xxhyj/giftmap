import '../../gift_finder/domain/gift_intent.dart';

/// 로컬 Mock 카탈로그의 상품 한 건.
///
/// 실제 판매 상품이 아니라 데모 데이터다. 가격은 실시간 시세가 아니며
/// 화면에서는 항상 데모 데이터임을 함께 표시한다.
class Product {
  const Product({
    required this.id,
    required this.brandName,
    required this.productName,
    required this.category,
    required this.categoryLabel,
    required this.subCategory,
    required this.price,
    required this.tags,
    required this.occasions,
    required this.recipientTypes,
    required this.ageRange,
    required this.priceRange,
    required this.recommendationKeywords,
    required this.description,
    required this.recommendationReason,
    required this.createdAt,
    this.originalPrice,
    this.discountRate,
    this.imageAsset,
    this.genderTarget,
    this.isDemo = true,
  });

  final String id;
  final String brandName;
  final String productName;

  /// 카테고리 식별자(예: `perfume`).
  final String category;

  /// 사용자에게 보여줄 카테고리 이름(예: 향수).
  final String categoryLabel;
  final String subCategory;

  final int price;
  final int? originalPrice;
  final int? discountRate;

  /// 로컬 asset 경로. 없으면 카테고리 기반 비주얼을 그린다.
  final String? imageAsset;

  /// 회피 태그와 같은 어휘를 사용한다(scent, food, sizing, strongTaste 등).
  final List<String> tags;
  final List<GiftSituation> occasions;
  final List<RelationshipType> recipientTypes;

  /// 선물 대상 성별. 현재 카탈로그는 모두 null이며 추천 점수에 쓰지 않는다.
  final String? genderTarget;
  final List<AgeBand> ageRange;
  final BudgetBand priceRange;
  final List<String> recommendationKeywords;
  final String description;
  final String recommendationReason;

  /// 데모 데이터 여부. 현재 카탈로그는 모두 true다.
  final bool isDemo;
  final DateTime createdAt;

  bool get hasDiscount =>
      originalPrice != null && originalPrice! > price && discountRate != null;

  /// 검색 대상 문자열. 소문자·공백 제거 비교에 사용한다.
  String get searchIndex => <String>[
    brandName,
    productName,
    categoryLabel,
    subCategory,
    ...tags,
    ...recommendationKeywords,
  ].join(' ').toLowerCase();

  factory Product.fromJson(Map<String, Object?> json) {
    final String? id = _str(json['id']);
    final String? name = _str(json['productName']);
    final String? brand = _str(json['brandName']);
    final int? price = _int(json['price']);
    if (id == null || name == null || brand == null || price == null) {
      throw const FormatException('product requires id, brand, name and price');
    }
    if (price <= 0) {
      throw FormatException('product $id has an invalid price');
    }

    final int? originalPrice = _int(json['originalPrice']);
    final bool discounted = originalPrice != null && originalPrice > price;

    return Product(
      id: id,
      brandName: brand,
      productName: name,
      category: _str(json['category']) ?? 'etc',
      categoryLabel: _str(json['categoryLabel']) ?? '선물',
      subCategory: _str(json['subCategory']) ?? '',
      price: price,
      originalPrice: discounted ? originalPrice : null,
      discountRate: discounted
          ? (_int(json['discountRate']) ??
                (((originalPrice - price) * 100) / originalPrice).round())
          : null,
      imageAsset: _str(json['imageAsset']),
      tags: _strList(json['tags']),
      occasions: _strList(json['occasions'])
          .map(GiftSituation.fromWire)
          .nonNulls
          .toList(growable: false),
      recipientTypes: _strList(json['recipientTypes'])
          .map(RelationshipType.fromWire)
          .nonNulls
          .toList(growable: false),
      genderTarget: _str(json['genderTarget']),
      ageRange: _strList(json['ageRange'])
          .map(AgeBand.fromWire)
          .nonNulls
          .toList(growable: false),
      priceRange:
          BudgetBand.fromWire(_str(json['priceRange'])) ?? _bandForPrice(price),
      recommendationKeywords: _strList(json['recommendationKeywords']),
      description: _str(json['description']) ?? '',
      recommendationReason: _str(json['recommendationReason']) ?? '',
      isDemo: json['isDemo'] != false,
      createdAt:
          DateTime.tryParse(_str(json['createdAt']) ?? '') ?? DateTime(2026),
    );
  }

  static BudgetBand _bandForPrice(int price) {
    if (price <= 10000) return BudgetBand.under10k;
    if (price <= 30000) return BudgetBand.from10kTo30k;
    if (price <= 50000) return BudgetBand.from30kTo50k;
    if (price <= 100000) return BudgetBand.from50kTo100k;
    return BudgetBand.over100k;
  }

  static String? _str(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  static int? _int(Object? value) => value is num ? value.round() : null;

  static List<String> _strList(Object? value) {
    if (value is! List) return const <String>[];
    return value.map(_str).nonNulls.toList(growable: false);
  }
}
