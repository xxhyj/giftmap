/** 테스트에서 쓰는 가짜 요청·응답과 가짜 fetch. 실제 계정도 키도 쓰지 않는다. */

export function makeReq({ method = 'GET', query = {}, headers = {}, body } = {}) {
  return { method, query, headers, body, socket: { remoteAddress: '10.0.0.1' } };
}

export function makeRes() {
  const res = {
    statusCode: null,
    headers: {},
    body: null,
    setHeader(name, value) {
      this.headers[name.toLowerCase()] = value;
    },
    status(code) {
      this.statusCode = code;
      return this;
    },
    send(payload) {
      this.body = payload;
      return this;
    },
  };
  Object.defineProperty(res, 'json', {
    get() {
      return res.body == null ? null : JSON.parse(res.body);
    },
  });
  return res;
}

/** 경로별로 정해진 행을 돌려주는 가짜 Supabase. 호출 기록을 남긴다. */
export function fakeSupabase(tables = {}) {
  const calls = [];
  return {
    calls,
    async request(path, params, options) {
      calls.push({ path, params: params ?? [], options: options ?? {} });
      const table = tables[path];
      if (typeof table === 'function') return table(params, options);
      const rows = table ?? [];
      return {
        rows,
        contentRange: `0-${Math.max(0, rows.length - 1)}/${rows.length}`,
      };
    },
  };
}

/** OpenAI 응답을 흉내 낸다. */
export function fakeOpenAiFetch(picks, { ok = true, status = 200 } = {}) {
  return async () => ({
    ok,
    status,
    async json() {
      return { choices: [{ message: { content: JSON.stringify({ picks }) } }] };
    },
  });
}

export function productRow(overrides = {}) {
  return {
    id: 'seller-1',
    brand_name: '브랜드',
    product_name: '상품',
    category_id: 'living',
    sub_category: '',
    price: 10000,
    original_price: null,
    discount_rate: null,
    image_asset: null,
    image_url: 'https://img.test/a.jpg',
    product_url: 'https://shop.test/a',
    in_stock: true,
    availability: 'in_stock',
    last_verified_at: '2026-09-01T00:00:00Z',
    source: 'seller',
    tags: ['tag'],
    occasions: ['birthday'],
    recipient_types: ['friend'],
    gender_target: null,
    age_range: ['twenties'],
    price_range: null,
    recommendation_keywords: [],
    description: '설명',
    recommendation_reason: '이유',
    is_demo: false,
    sort_order: 1,
    created_at: '2026-09-01T00:00:00Z',
    ...overrides,
  };
}
