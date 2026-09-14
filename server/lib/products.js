/**
 * 상품 읽기.
 *
 * DB 의 snake_case 행을 앱이 읽는 모양(camelCase)으로 바꿔 돌려준다.
 * 바꾸는 자리를 서버 한 곳에 두면 앱은 받은 것을 그대로 Product.fromJson 에
 * 넘기기만 하면 된다.
 */

import { totalFromContentRange } from './supabase.js';

/** 앱이 화면을 그리는 데 필요한 열만 읽는다. */
const COLUMNS = [
  'id', 'brand_name', 'product_name', 'category_id', 'sub_category',
  'price', 'original_price', 'discount_rate', 'image_asset', 'image_url',
  'product_url', 'in_stock', 'availability', 'last_verified_at', 'source',
  'tags', 'occasions', 'recipient_types', 'gender_target', 'age_range',
  'price_range', 'recommendation_keywords', 'description',
  'recommendation_reason', 'is_demo', 'sort_order', 'created_at',
].join(',');

function strList(value) {
  if (!Array.isArray(value)) return [];
  return value.filter((item) => item !== null && item !== undefined).map(String);
}

/** 행 하나를 앱이 읽는 모양으로. */
export function toProductJson(row, categoryLabels = {}) {
  const categoryId = row.category_id == null ? null : String(row.category_id);
  return {
    id: row.id,
    brandName: row.brand_name,
    productName: row.product_name,
    category: categoryId,
    categoryLabel: categoryId == null ? null : (categoryLabels[categoryId] ?? null),
    subCategory: row.sub_category,
    price: row.price,
    originalPrice: row.original_price,
    discountRate: row.discount_rate,
    imageAsset: row.image_asset,
    imageUrl: row.image_url,
    productUrl: row.product_url,
    inStock: row.in_stock,
    availability: row.availability,
    lastVerifiedAt: row.last_verified_at,
    source: row.source,
    tags: strList(row.tags),
    occasions: strList(row.occasions),
    recipientTypes: strList(row.recipient_types),
    genderTarget: row.gender_target,
    ageRange: strList(row.age_range),
    priceRange: row.price_range,
    recommendationKeywords: strList(row.recommendation_keywords),
    description: row.description,
    recommendationReason: row.recommendation_reason,
    isDemo: row.is_demo,
    createdAt: row.created_at,
  };
}

/** 분류 라벨. 화면에 "도서" 처럼 보이는 이름이다. */
export async function loadCategoryLabels(supabase) {
  const { rows } = await supabase.request('categories', [
    ['select', 'id,label'],
    ['order', 'sort_order.asc'],
  ]);
  const labels = {};
  for (const row of rows) {
    if (row?.id == null) continue;
    labels[String(row.id)] = row.label == null ? String(row.id) : String(row.label);
  }
  return labels;
}

/** 추천 검색어. 첫 페이지에만 실어 보낸다. */
export async function loadSearchSuggestions(supabase) {
  const { rows } = await supabase.request('search_suggestions', [
    ['select', 'keyword'],
    ['order', 'sort_order.asc'],
  ]);
  return rows
    .map((row) => (row?.keyword == null ? null : String(row.keyword).trim()))
    .filter((keyword) => keyword && keyword.length > 0);
}

/**
 * 상품 한 페이지.
 *
 * 정렬은 `sort_order`(공급원 안에서의 순번) → `id` 오름차순으로 고정한다.
 * 정렬이 흔들리면 같은 상품이 두 페이지에 걸쳐 나오고 어떤 상품은 빠진다.
 */
export async function listProducts(supabase, { offset, limit, category, query }) {
  const params = [
    ['select', COLUMNS],
    ['is_demo', 'eq.false'],
    ['is_active', 'eq.true'],
    ['order', 'sort_order.asc'],
    ['order', 'id.asc'],
  ];
  if (category) params.push(['category_id', `eq.${category}`]);
  if (query) {
    // 상품명·브랜드 중 하나만 맞아도 결과에 넣는다.
    params.push(['or', `(product_name.ilike.*${query}*,brand_name.ilike.*${query}*)`]);
  }

  const { rows, contentRange } = await supabase.request('products', params, {
    range: `${offset}-${offset + limit - 1}`,
  });
  const total = totalFromContentRange(contentRange);
  return {
    rows,
    total,
    // 개수를 모르면 받은 만큼으로 판단한다(꽉 찼으면 뒤에 더 있을 수 있다).
    hasMore: total == null ? rows.length >= limit : offset + rows.length < total,
  };
}

/** 상품 하나. 없으면 null. */
export async function getProduct(supabase, id) {
  const { rows } = await supabase.request('products', [
    ['select', COLUMNS],
    ['id', `eq.${id}`],
    ['limit', '1'],
  ]);
  return rows.length > 0 ? rows[0] : null;
}
