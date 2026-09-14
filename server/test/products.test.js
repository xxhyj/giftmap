import assert from 'node:assert/strict';
import test from 'node:test';

import {
  getProduct,
  listProducts,
  loadCategoryLabels,
  toProductJson,
} from '../lib/products.js';
import { totalFromContentRange } from '../lib/supabase.js';
import { fakeSupabase, productRow } from './helpers.js';

test('DB 행을 앱이 읽는 모양으로 바꾼다', () => {
  const json = toProductJson(productRow(), { living: '홈·리빙' });

  assert.equal(json.productName, '상품');
  assert.equal(json.brandName, '브랜드');
  assert.equal(json.category, 'living');
  assert.equal(json.categoryLabel, '홈·리빙');
  assert.equal(json.imageUrl, 'https://img.test/a.jpg');
  assert.equal(json.productUrl, 'https://shop.test/a');
  assert.equal(json.isDemo, false);
  assert.deepEqual(json.recipientTypes, ['friend']);
  // snake_case 는 남기지 않는다. 앱이 읽지 못한다.
  assert.equal('product_name' in json, false);
});

test('배열이 아닌 값은 빈 목록으로 둔다', () => {
  const json = toProductJson(productRow({ tags: null, occasions: 'birthday' }));
  assert.deepEqual(json.tags, []);
  assert.deepEqual(json.occasions, []);
});

test('라벨을 모르면 null 로 두고 지어내지 않는다', () => {
  const json = toProductJson(productRow({ category_id: 'unknown_cat' }), {});
  assert.equal(json.category, 'unknown_cat');
  assert.equal(json.categoryLabel, null);
});

test('목록은 데모를 빼고 정렬을 고정해 요청한다', async () => {
  const supabase = fakeSupabase({ products: [productRow()] });

  await listProducts(supabase, { offset: 60, limit: 30, category: null, query: null });

  const call = supabase.calls[0];
  const params = new Map(call.params.map(([k, v]) => [k, v]));
  assert.equal(params.get('is_demo'), 'eq.false');
  assert.equal(params.get('is_active'), 'eq.true');
  // 정렬이 흔들리면 같은 상품이 두 페이지에 걸쳐 나온다.
  const orders = call.params.filter(([k]) => k === 'order').map(([, v]) => v);
  assert.deepEqual(orders, ['sort_order.asc', 'id.asc']);
  assert.equal(call.options.range, '60-89');
});

test('분류와 검색어는 필터로 넘어간다', async () => {
  const supabase = fakeSupabase({ products: [] });

  await listProducts(supabase, {
    offset: 0,
    limit: 10,
    category: 'book',
    query: '에세이',
  });

  const params = supabase.calls[0].params;
  assert.ok(params.some(([k, v]) => k === 'category_id' && v === 'eq.book'));
  // 상품명이든 브랜드든 하나만 맞아도 찾는다.
  const or = params.find(([k]) => k === 'or');
  assert.match(or[1], /product_name\.ilike\.\*에세이\*/);
  assert.match(or[1], /brand_name\.ilike\.\*에세이\*/);
});

test('전체 개수를 알면 그것으로 다음 페이지 여부를 정한다', async () => {
  const supabase = fakeSupabase({
    products: () => ({
      rows: [productRow(), productRow({ id: 'seller-2' })],
      contentRange: '0-1/50',
    }),
  });

  const result = await listProducts(supabase, {
    offset: 0,
    limit: 2,
    category: null,
    query: null,
  });

  assert.equal(result.total, 50);
  assert.equal(result.hasMore, true);
});

test('마지막 페이지에서는 더 없다고 알린다', async () => {
  const supabase = fakeSupabase({
    products: () => ({ rows: [productRow()], contentRange: '49-49/50' }),
  });

  const result = await listProducts(supabase, {
    offset: 49,
    limit: 10,
    category: null,
    query: null,
  });

  assert.equal(result.hasMore, false);
});

test('개수를 모르면 받은 만큼으로 판단한다', async () => {
  const supabase = fakeSupabase({
    products: () => ({ rows: [productRow(), productRow()], contentRange: '0-1/*' }),
  });

  const result = await listProducts(supabase, {
    offset: 0,
    limit: 2,
    category: null,
    query: null,
  });

  assert.equal(result.total, null);
  assert.equal(result.hasMore, true);
});

test('content-range 를 못 읽으면 null', () => {
  assert.equal(totalFromContentRange('0-59/1886'), 1886);
  assert.equal(totalFromContentRange('0-59/*'), null);
  assert.equal(totalFromContentRange(null), null);
});

test('분류 라벨을 id 기준으로 모은다', async () => {
  const supabase = fakeSupabase({
    categories: [
      { id: 'book', label: '도서' },
      { id: 'living', label: null },
    ],
  });

  const labels = await loadCategoryLabels(supabase);

  assert.equal(labels.book, '도서');
  // 라벨이 비면 id 를 그대로 쓴다. 화면이 빈 칸이 되지 않게.
  assert.equal(labels.living, 'living');
});

test('없는 상품은 null 로 돌려준다', async () => {
  const supabase = fakeSupabase({ products: [] });
  assert.equal(await getProduct(supabase, 'seller-404'), null);
});
