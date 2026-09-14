/**
 * API 계약 테스트.
 *
 * 핸들러를 직접 불러 상태 코드·본문 모양·헤더를 확인한다.
 * 실제 배포도 계정도 키도 쓰지 않는다. 환경변수는 이 테스트 안에서만 가짜 값을
 * 넣고 끝나면 지운다(어떤 값도 저장소에 남지 않는다).
 */

import assert from 'node:assert/strict';
import test, { afterEach, beforeEach } from 'node:test';

import health from '../api/health.js';
import productList from '../api/products/index.js';
import productDetail from '../api/products/[id].js';
import recommendHandler from '../api/recommend.js';
import { resetForTest } from '../lib/ratelimit.js';
import { makeReq, makeRes, productRow } from './helpers.js';

const FAKE_ENV = {
  SUPABASE_URL: 'https://example.supabase.co',
  SUPABASE_SERVICE_ROLE_KEY: 'test-only-not-a-real-key',
  OPENAI_API_KEY: 'test-only-not-a-real-key',
};

let realFetch;

beforeEach(() => {
  realFetch = globalThis.fetch;
  resetForTest();
});

afterEach(() => {
  globalThis.fetch = realFetch;
  for (const name of Object.keys(FAKE_ENV)) delete process.env[name];
  delete process.env.RECOMMEND_RATE_LIMIT_PER_MINUTE;
});

function withEnv(extra = {}) {
  Object.assign(process.env, FAKE_ENV, extra);
}

/** PostgREST 응답을 흉내 낸다. 경로별로 행을 정한다. */
function stubFetch(byTable) {
  globalThis.fetch = async (url) => {
    const path = String(url).split('/rest/v1/')[1]?.split('?')[0] ?? '';
    const rows = byTable[path] ?? [];
    return {
      ok: true,
      status: 200,
      headers: { get: () => `0-${Math.max(0, rows.length - 1)}/${rows.length}` },
      async json() {
        return rows;
      },
    };
  };
}

test('GET /api/health 는 준비 상태만 알린다', async () => {
  withEnv();
  const res = makeRes();

  await health(makeReq(), res);

  assert.equal(res.statusCode, 200);
  assert.equal(res.json.status, 'ok');
  assert.deepEqual(res.json.ready, { products: true, recommend: true });
  // 키나 주소가 응답에 섞여 나가면 안 된다.
  assert.equal(res.body.includes('supabase.co'), false);
  assert.equal(res.body.includes('test-only'), false);
});

test('환경변수가 없으면 준비되지 않았다고 알린다', async () => {
  const res = makeRes();
  await health(makeReq(), res);
  assert.deepEqual(res.json.ready, { products: false, recommend: false });
});

test('OPTIONS 는 본문 없이 204', async () => {
  const res = makeRes();
  await health(makeReq({ method: 'OPTIONS' }), res);
  assert.equal(res.statusCode, 204);
  assert.equal(res.headers['access-control-allow-methods'], 'GET, POST, OPTIONS');
});

test('허용하지 않는 메서드는 405 와 같은 오류 모양', async () => {
  const res = makeRes();
  await health(makeReq({ method: 'DELETE' }), res);

  assert.equal(res.statusCode, 405);
  assert.equal(res.json.error.code, 'method_not_allowed');
  assert.ok(res.headers.allow.includes('GET'));
});

test('GET /api/products 는 앱이 읽는 모양으로 돌려준다', async () => {
  withEnv();
  stubFetch({
    products: [productRow(), productRow({ id: 'seller-2' })],
    categories: [{ id: 'living', label: '홈·리빙' }],
    search_suggestions: [{ keyword: '텀블러' }],
  });
  const res = makeRes();

  await productList(makeReq({ query: { page: '1', limit: '2' } }), res);

  assert.equal(res.statusCode, 200);
  const body = res.json;
  assert.equal(body.page, 1);
  assert.equal(body.limit, 2);
  assert.equal(body.products.length, 2);
  assert.equal(body.products[0].categoryLabel, '홈·리빙');
  assert.equal(body.products[0].productName, '상품');
  // 첫 페이지에만 고지와 추천 검색어를 싣는다.
  assert.ok(body.disclaimer.length > 0);
  assert.deepEqual(body.searchSuggestions, ['텀블러']);
});

test('두 번째 페이지에는 고지와 추천 검색어를 싣지 않는다', async () => {
  withEnv();
  stubFetch({ products: [productRow()], categories: [] });
  const res = makeRes();

  await productList(makeReq({ query: { page: '2', limit: '10' } }), res);

  assert.equal(res.json.disclaimer, '');
  assert.deepEqual(res.json.searchSuggestions, []);
});

test('환경변수가 없으면 503 이고 데모로 감추지 않는다', async () => {
  const res = makeRes();
  await productList(makeReq(), res);

  assert.equal(res.statusCode, 503);
  assert.equal(res.json.error.code, 'not_configured');
});

test('상품 저장소가 실패하면 502 로 알린다', async () => {
  withEnv();
  globalThis.fetch = async () => ({
    ok: false,
    status: 500,
    headers: { get: () => null },
    async json() {
      return {};
    },
  });
  const res = makeRes();

  await productList(makeReq(), res);

  assert.equal(res.statusCode, 502);
  assert.equal(res.json.error.code, 'upstream_error');
});

test('GET /api/products/:id 는 상품 하나를 돌려준다', async () => {
  withEnv();
  stubFetch({ products: [productRow()], categories: [{ id: 'living', label: '홈·리빙' }] });
  const res = makeRes();

  await productDetail(makeReq({ query: { id: 'seller-1' } }), res);

  assert.equal(res.statusCode, 200);
  assert.equal(res.json.product.id, 'seller-1');
  assert.equal(res.json.product.categoryLabel, '홈·리빙');
});

test('없는 상품은 404', async () => {
  withEnv();
  stubFetch({ products: [] });
  const res = makeRes();

  await productDetail(makeReq({ query: { id: 'seller-404' } }), res);

  assert.equal(res.statusCode, 404);
  assert.equal(res.json.error.code, 'not_found');
});

test('이상한 id 는 저장소를 찌르기 전에 400', async () => {
  withEnv();
  let called = false;
  globalThis.fetch = async () => {
    called = true;
    throw new Error('여기까지 오면 안 된다');
  };
  const res = makeRes();

  await productDetail(makeReq({ query: { id: '../../secret' } }), res);

  assert.equal(res.statusCode, 400);
  assert.equal(called, false);
});

test('POST /api/recommend 는 실제 상품 id 만 돌려준다', async () => {
  withEnv();
  const rows = [
    { id: 'a-1', product_name: 'A', category_id: 'living', source: 's1', brand_name: 'A사', price: 1000 },
    { id: 'b-1', product_name: 'B', category_id: 'bag', source: 's2', brand_name: 'B사', price: 2000 },
    { id: 'c-1', product_name: 'C', category_id: 'beauty', source: 's3', brand_name: 'C사', price: 3000 },
  ];
  globalThis.fetch = async (url) => {
    if (String(url).includes('openai')) {
      return {
        ok: true,
        status: 200,
        async json() {
          return {
            choices: [
              {
                message: {
                  content: JSON.stringify({
                    picks: [
                      { id: 'a-1', reason: '이유1' },
                      { id: 'b-1', reason: '이유2' },
                      { id: 'c-1', reason: '이유3' },
                    ],
                  }),
                },
              },
            ],
          };
        },
      };
    }
    return {
      ok: true,
      status: 200,
      headers: { get: () => `0-2/3` },
      async json() {
        return rows;
      },
    };
  };
  const res = makeRes();

  await recommendHandler(
    makeReq({ method: 'POST', body: { relationship: 'friend', situation: 'birthday' } }),
    res,
  );

  assert.equal(res.statusCode, 200);
  assert.equal(res.json.fallback, false);
  assert.equal(res.json.picks.length, 3);
  assert.ok(res.json.picks.every((pick) => typeof pick.productId === 'string'));
});

test('깨진 JSON 본문은 400', async () => {
  withEnv();
  const res = makeRes();

  await recommendHandler(makeReq({ method: 'POST', body: '{이건 JSON 이 아니다' }), res);

  assert.equal(res.statusCode, 400);
  assert.equal(res.json.error.code, 'invalid_body');
});

test('본문이 비어도 조건 없는 추천으로 받아들인다', async () => {
  withEnv();
  stubFetch({ products: [] });
  const res = makeRes();

  await recommendHandler(makeReq({ method: 'POST', body: '' }), res);

  // 후보가 없으면 오류가 아니라 fallback 이다. 앱이 로컬 엔진으로 잇는다.
  assert.equal(res.statusCode, 200);
  assert.equal(res.json.fallback, true);
});

test('추천을 연달아 부르면 429 로 막는다', async () => {
  withEnv({ RECOMMEND_RATE_LIMIT_PER_MINUTE: '2' });
  stubFetch({ products: [] });

  for (let i = 0; i < 2; i += 1) {
    const res = makeRes();
    await recommendHandler(makeReq({ method: 'POST', body: {} }), res);
    assert.equal(res.statusCode, 200);
  }

  const blocked = makeRes();
  await recommendHandler(makeReq({ method: 'POST', body: {} }), blocked);

  assert.equal(blocked.statusCode, 429);
  assert.equal(blocked.json.error.code, 'rate_limited');
  assert.ok(Number(blocked.headers['retry-after']) > 0);
});

test('GET 으로 추천을 부르면 405', async () => {
  withEnv();
  const res = makeRes();
  await recommendHandler(makeReq({ method: 'GET' }), res);
  assert.equal(res.statusCode, 405);
});
