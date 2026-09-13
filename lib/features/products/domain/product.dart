import '../../gift_finder/domain/gift_intent.dart';

/// 공급원이 알려준 재고 상태.
///
/// 모를 때 품절로 단정하지 않기 위해 [unknown]을 따로 둔다.
enum ProductAvailability {
  inStock('in_stock', '판매 중'),
  outOfStock('out_of_stock', '품절'),
  unknown('unknown', '재고 미확인');

  const ProductAvailability(this.wireName, this.label);

  final String wireName;
  final String label;

  static ProductAvailability fromWire(String? value) {
    for (final ProductAvailability item in ProductAvailability.values) {
      if (item.wireName == value) return item;
    }
    return ProductAvailability.unknown;
  }
}

/// 카탈로그의 상품 한 건.
///
/// 두 종류가 섞여 있다.
/// - 번들 데모 상품(`isDemo == true`): 실제 판매 상품이 아니고 가격도 Mock 시세다.
///   화면에서 항상 데모임을 함께 표시한다.
/// - 수집 상품(`isDemo == false`): `crawler/`가 공급원의 공개 페이지에서 읽어
///   Supabase에 올린 실제 판매 상품이며 [productUrl]로 원본을 열 수 있다.
class Product {
  const Product({
    required this.id,
    required this.productName,
    required this.category,
    required this.categoryLabel,
    required this.subCategory,
    required this.tags,
    required this.occasions,
    required this.recipientTypes,
    required this.ageRange,
    required this.priceRange,
    required this.recommendationKeywords,
    required this.description,
    required this.recommendationReason,
    required this.createdAt,
    this.brandName,
    this.price,
    this.originalPrice,
    this.discountRate,
    this.imageAsset,
    this.imageUrl,
    this.productUrl,
    this.genderTarget,
    this.isDemo = true,
    this.inStock,
    this.source,
    this.availability = ProductAvailability.unknown,
    this.lastVerifiedAt,
  });

  final String id;

  /// 브랜드가 확인되지 않는 상품이 있을 수 있다.
  final String? brandName;
  final String productName;

  /// 카테고리 식별자(예: `perfume`).
  final String category;

  /// 사용자에게 보여줄 카테고리 이름(예: 향수).
  final String categoryLabel;
  final String subCategory;

  /// 가격을 확인할 수 없는 상품이 있을 수 있다.
  /// null을 0원으로 표시하지 않는다.
  final int? price;
  final int? originalPrice;
  final int? discountRate;

  /// 로컬 asset 경로. 없으면 카테고리 기반 비주얼을 그린다.
  final String? imageAsset;

  /// 수집한 상품의 공개 이미지 주소. 번들 데모 상품은 null이다.
  /// asset → 원격 이미지 → 카테고리 비주얼 순으로 그린다.
  final String? imageUrl;

  /// 실제 판매 페이지 주소. 수집 상품에는 값이 있고 데모 상품은 null이다.
  /// null이면 구매 CTA를 활성화하지 않는다.
  final String? productUrl;

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

  /// 데모 데이터 여부. 번들 카탈로그는 모두 true이고,
  /// `crawler/`가 수집해 Supabase에 올린 실제 상품은 false다.
  final bool isDemo;

  /// 재고 여부. null이면 공급원이 알려주지 않은 것이며 품절로 단정하지 않는다.
  final bool? inStock;

  /// 재고 상태. 공급원이 알려주지 않으면 [ProductAvailability.unknown]이다.
  final ProductAvailability availability;

  /// 공급원 페이지에서 마지막으로 확인한 시각.
  /// 오래된 상품은 추천에서 뒤로 밀린다.
  final DateTime? lastVerifiedAt;

  /// 어느 공급원에서 수집했는지(예: `10x10`). 데모 상품은 null이다.
  final String? source;

  final DateTime createdAt;

  /// 품절이 확인된 상품인지. 모르면 false다(품절로 단정하지 않는다).
  bool get isSoldOut => availability == ProductAvailability.outOfStock;

  /// 목록·추천에 내보내도 되는 상품인지.
  /// 품절이 확인된 상품은 기본으로 뺀다(찜·최근 본 상품에서는 그대로 보여 준다).
  bool get isSellable => !isSoldOut;

  /// 마지막 확인이 오래됐는지. 추천 우선순위를 낮추는 데 쓴다.
  bool isStale({Duration after = const Duration(days: 14), DateTime? now}) {
    final DateTime? verified = lastVerifiedAt;
    if (verified == null) return true;
    return (now ?? DateTime.now()).difference(verified) > after;
  }

  /// 사용자에게 보여줄 공급원 이름.
  String? get sourceLabel => switch (source) {
    '10x10' => '텐바이텐',
    'musinsa' => '무신사',
    'aladin' => '알라딘',
    final String value when value.isNotEmpty => value,
    _ => null,
  };

  /// 실제 판매 페이지로 이동할 수 있는 상품인지.
  ///
  /// 데모 상품에는 판매 페이지가 없고, 품절이 확인된 상품은 사러 가도 살 수 없어
  /// CTA를 활성화하지 않는다(찜·최근 본 상품에서 만나는 경우다).
  bool get canOpenStore =>
      !isDemo && !isSoldOut && (productUrl?.isNotEmpty ?? false);

  bool get hasPrice => price != null;

  bool get hasDiscount =>
      price != null &&
      originalPrice != null &&
      originalPrice! > price! &&
      discountRate != null;

  /// 가격 정렬에서 값이 없는 상품을 뒤로 보내기 위한 정렬 키.
  int get sortPrice => price ?? 1 << 30;

  /// 브랜드가 없으면 카테고리 이름으로 대신 보여준다.
  String get brandLabel =>
      (brandName != null && brandName!.isNotEmpty) ? brandName! : categoryLabel;

  /// 검색 대상 문자열. 소문자·공백 제거 비교에 사용한다.
  String get searchIndex => <String>[
    brandName ?? '',
    productName,
    categoryLabel,
    subCategory,
    ...tags,
    ...recommendationKeywords,
  ].join(' ').toLowerCase();

  factory Product.fromJson(Map<String, Object?> json) {
    final String? id = _str(json['id']);
    final String? name = _str(json['productName']);
    if (id == null || name == null) {
      throw const FormatException('product requires id and productName');
    }

    // 가격은 없을 수 있다. 다만 0 이하의 값은 잘못된 데이터로 본다.
    int? price = _int(json['price']);
    if (price != null && price <= 0) {
      throw FormatException('product $id has an invalid price');
    }

    final int? originalPrice = _int(json['originalPrice']);
    final bool discounted =
        price != null && originalPrice != null && originalPrice > price;

    return Product(
      id: id,
      brandName: _str(json['brandName']),
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
      imageUrl: _str(json['imageUrl']),
      productUrl: _str(json['productUrl']),
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
      inStock: json['inStock'] is bool ? json['inStock']! as bool : null,
      source: _str(json['source']),
      // availability 가 없으면 inStock 으로 유추한다.
      // 예전에 저장된 데이터와 재고를 boolean 으로만 주는 입력을 함께 받기 위해서다.
      availability: _availabilityOf(json),
      lastVerifiedAt: DateTime.tryParse(_str(json['lastVerifiedAt']) ?? ''),
      createdAt:
          DateTime.tryParse(_str(json['createdAt']) ?? '') ?? DateTime(2026),
    );
  }

  static ProductAvailability _availabilityOf(Map<String, Object?> json) {
    final String? wire = _str(json['availability']);
    if (wire != null) return ProductAvailability.fromWire(wire);
    return switch (json['inStock']) {
      true => ProductAvailability.inStock,
      false => ProductAvailability.outOfStock,
      _ => ProductAvailability.unknown,
    };
  }

  static BudgetBand _bandForPrice(int? price) {
    if (price == null) return BudgetBand.custom;
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
