import assert from 'node:assert/strict';
import test from 'node:test';

import {
  diversify,
  loadCandidates,
  mixCandidates,
  recommend,
  wantsBooks,
} from '../lib/recommend.js';
import { fakeOpenAiFetch, fakeSupabase } from './helpers.js';

const openai = { key: 'test-key-not-real', model: 'test-model' };

function candidate(id, category, source, brand = null) {
  return { id, category, source, brand, name: id, price: 10000 };
}

test('책을 말한 조건만 도서를 넉넉히 본다', () => {
  assert.equal(wantsBooks({ preference: '책 좋아해요' }), true);
  assert.equal(wantsBooks({ preference: 'reading' }), true);
  assert.equal(wantsBooks({ preference: '향수' }), false);
  assert.equal(wantsBooks({}), false);
});

test('후보에서 도서는 15% 까지만 담는다', () => {
  const items = [
    ...Array.from({ length: 50 }, (_, i) => candidate(`b${i}`, 'book', 'aladin')),
    ...Array.from({ length: 50 }, (_, i) => candidate(`l${i}`, 'living', 'shop')),
  ];

  const mixed = mixCandidates(items, 20, { allowBooks: false });

  const books = mixed.filter((item) => item.category === 'book').length;
  assert.ok(books <= 3, `도서가 ${books}개나 들어갔다`);
  assert.equal(mixed.length, 20);
});

test('책을 원하면 도서 한도를 풀어 준다', () => {
  const items = Array.from({ length: 30 }, (_, i) => candidate(`b${i}`, 'book', 'aladin'));

  const mixed = mixCandidates(items, 10, { allowBooks: true });

  assert.equal(mixed.length, 10);
  assert.equal(mixed.every((item) => item.category === 'book'), true);
});

test('도서만 있으면 한도를 걸어도 후보가 비지 않는다', () => {
  const items = Array.from({ length: 30 }, (_, i) => candidate(`b${i}`, 'book', 'aladin'));

  const mixed = mixCandidates(items, 10, { allowBooks: false });

  // 남는 자리는 미뤄 둔 책으로 채운다. 후보가 0이면 추천 자체가 사라진다.
  assert.equal(mixed.length, 10);
});

test('같은 분류·브랜드만 고르면 걸러 낸다', () => {
  const byId = new Map([
    ['a', candidate('a', 'living', 's', '브랜드')],
    ['b', candidate('b', 'living', 's', '브랜드')],
    ['c', candidate('c', 'living', 's', '다른브랜드')],
    ['d', candidate('d', 'bag', 's', '가방브랜드')],
    ['e', candidate('e', 'beauty', 's', '뷰티브랜드')],
  ]);
  const picks = [...byId.keys()].map((id) => ({ id, reason: '' }));

  const kept = diversify(picks, byId, { allowBooks: false });

  const categories = kept.map((pick) => byId.get(pick.id).category);
  const living = categories.filter((category) => category === 'living').length;
  assert.ok(living <= 2, '같은 분류가 3개 이상 남았다');
  const brands = kept.map((pick) => byId.get(pick.id).brand);
  assert.equal(new Set(brands).size, brands.length, '같은 브랜드가 두 번 남았다');
});

test('걸러 내다 3개 미만이 되면 되돌려 채운다', () => {
  const byId = new Map([
    ['a', candidate('a', 'living', 's', '브랜드')],
    ['b', candidate('b', 'living', 's', '브랜드')],
    ['c', candidate('c', 'living', 's', '브랜드')],
  ]);
  const picks = [...byId.keys()].map((id) => ({ id, reason: '' }));

  assert.equal(diversify(picks, byId, { allowBooks: false }).length, 3);
});

test('후보 조회는 품절과 보여 줄 수 없는 상품을 뺀다', async () => {
  const supabase = fakeSupabase({ products: [] });

  await loadCandidates(supabase, { situation: 'birthday', relationship: 'friend' }, 10);

  const params = supabase.calls[0].params;
  const has = (key, value) => params.some(([k, v]) => k === key && v === value);
  assert.ok(has('availability', 'neq.out_of_stock'));
  assert.ok(has('image_url', 'not.is.null'));
  assert.ok(has('product_url', 'not.is.null'));
  assert.ok(has('price', 'not.is.null'));
  assert.ok(has('is_demo', 'eq.false'));
  assert.ok(has('occasions', 'cs.{birthday}'));
  assert.ok(has('recipient_types', 'cs.{friend}'));
});

test('예산이 있으면 가격 범위로 좁힌다', async () => {
  const supabase = fakeSupabase({ products: [] });

  await loadCandidates(supabase, { budgetMin: 10000, budgetMax: 50000 }, 10);

  const params = supabase.calls[0].params;
  assert.ok(params.some(([k, v]) => k === 'price' && v === 'gte.10000'));
  assert.ok(params.some(([k, v]) => k === 'price' && v === 'lte.50000'));
});

test('모델이 고른 실제 상품만 돌려준다', async () => {
  const rows = [
    { id: 'a-1', product_name: 'A', category_id: 'living', source: 's1', brand_name: 'A사', price: 1000, image_url: 'x', product_url: 'y' },
    { id: 'b-1', product_name: 'B', category_id: 'bag', source: 's2', brand_name: 'B사', price: 2000, image_url: 'x', product_url: 'y' },
    { id: 'c-1', product_name: 'C', category_id: 'beauty', source: 's3', brand_name: 'C사', price: 3000, image_url: 'x', product_url: 'y' },
  ];
  const supabase = fakeSupabase({ products: rows });

  const result = await recommend({
    supabase,
    openai,
    intent: {},
    fetchImpl: fakeOpenAiFetch([
      { id: 'a-1', reason: '이유1' },
      { id: 'b-1', reason: '이유2' },
      { id: 'c-1', reason: '이유3' },
      // 모델이 지어낸 id 는 버린다.
      { id: '없는상품', reason: '지어낸 것' },
    ]),
  });

  assert.equal(result.fallback, false);
  assert.deepEqual(
    result.picks.map((pick) => pick.productId),
    ['a-1', 'b-1', 'c-1'],
  );
  assert.equal(result.picks[0].reason, '이유1');
});

test('고른 것이 3개 미만이면 앱에 넘긴다', async () => {
  const supabase = fakeSupabase({
    products: [
      { id: 'a-1', product_name: 'A', category_id: 'living', source: 's', price: 1 },
      { id: 'b-1', product_name: 'B', category_id: 'bag', source: 's', price: 1 },
      { id: 'c-1', product_name: 'C', category_id: 'beauty', source: 's', price: 1 },
    ],
  });

  const result = await recommend({
    supabase,
    openai,
    intent: {},
    fetchImpl: fakeOpenAiFetch([{ id: 'a-1', reason: '' }]),
  });

  assert.equal(result.fallback, true);
  assert.match(result.reason, /3개 미만/);
});

test('후보가 없으면 앱에 넘긴다', async () => {
  const result = await recommend({
    supabase: fakeSupabase({ products: [] }),
    openai,
    intent: {},
    fetchImpl: fakeOpenAiFetch([]),
  });

  assert.equal(result.fallback, true);
  assert.match(result.reason, /실제 상품이 없습니다/);
});

test('모델 키가 없으면 앱에 넘긴다', async () => {
  const result = await recommend({
    supabase: fakeSupabase({
      products: [{ id: 'a-1', product_name: 'A', category_id: 'living', source: 's', price: 1 }],
    }),
    openai: null,
    intent: {},
  });

  assert.equal(result.fallback, true);
});

test('모델 호출이 실패해도 오류를 던지지 않는다', async () => {
  const result = await recommend({
    supabase: fakeSupabase({
      products: [{ id: 'a-1', product_name: 'A', category_id: 'living', source: 's', price: 1 }],
    }),
    openai,
    intent: {},
    fetchImpl: async () => {
      throw new Error('network down');
    },
  });

  assert.equal(result.fallback, true);
  assert.match(result.reason, /호출 실패/);
});

test('모델이 깨진 JSON 을 주면 앱에 넘긴다', async () => {
  const result = await recommend({
    supabase: fakeSupabase({
      products: [{ id: 'a-1', product_name: 'A', category_id: 'living', source: 's', price: 1 }],
    }),
    openai,
    intent: {},
    fetchImpl: async () => ({
      ok: true,
      status: 200,
      async json() {
        return { choices: [{ message: { content: '{이건 JSON 이 아니다' } }] };
      },
    }),
  });

  assert.equal(result.fallback, true);
  assert.match(result.reason, /읽지 못했습니다/);
});

test('모델이 거절하면 상태 코드만 남기고 본문은 남기지 않는다', async () => {
  const result = await recommend({
    supabase: fakeSupabase({
      products: [{ id: 'a-1', product_name: 'A', category_id: 'living', source: 's', price: 1 }],
    }),
    openai,
    intent: {},
    fetchImpl: async () => ({
      ok: false,
      status: 401,
      async json() {
        return { error: { message: 'Incorrect API key: sk-should-never-leak' } };
      },
    }),
  });

  assert.equal(result.fallback, true);
  assert.equal(result.reason, '추천 모델 응답 401');
  assert.equal(result.reason.includes('sk-'), false);
});
