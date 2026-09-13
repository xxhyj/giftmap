import test from 'node:test';
import assert from 'node:assert/strict';

import {
  dedupeKey,
  guessCategory,
  priceBand,
  readStock,
  toProductRow,
} from '../src/normalize.js';
import { mergeDuplicates } from '../src/index.js';
import { fromJsonLd } from '../src/extract.js';
import { isAllowed } from '../src/robots.js';

const context = {
  sourceId: '10x10',
  sourceLabel: '텐바이텐',
  collectedAt: '2026-01-01T00:00:00.000Z',
};

test('JSON-LD Product/Offer 에서 이름·가격·정가·이미지를 읽는다', () => {
  const raw = fromJsonLd([
    {
      '@type': 'Product',
      name: '향기로운 캔들',
      sku: '123',
      image: 'https://example.test/a.jpg',
      brand: { '@type': 'Brand', name: '테스트브랜드' },
      keywords: '캔들,선물,',
      offers: {
        '@type': 'Offer',
        url: 'https://example.test/p/123',
        price: '24800',
        priceCurrency: 'KRW',
        hasPriceSpecification: { price: '30000' },
      },
    },
  ]);

  assert.equal(raw.name, '향기로운 캔들');
  assert.equal(raw.price, 24800);
  assert.equal(raw.listPrice, 30000);
  assert.equal(raw.brand, '테스트브랜드');
  assert.deepEqual(raw.keywords, ['캔들', '선물']);
});

test('Product 가 없으면 null 을 돌려준다(메타데이터 경로로 넘어간다)', () => {
  assert.equal(fromJsonLd([{ '@type': 'BreadcrumbList', itemListElement: [] }]), null);
});

test('가격을 모르면 0 이 아니라 null 로 둔다', () => {
  const row = toProductRow(
    { name: '가격 미상 상품', productUrl: 'https://example.test/p/9', sku: '9' },
    context,
  );
  assert.equal(row.price, null);
  assert.equal(row.price_range, 'custom');
});

test('수집 상품은 데모와 구분되고 출처가 남는다', () => {
  const row = toProductRow(
    {
      name: '캠핑컵 세트',
      productUrl: 'https://example.test/p/5',
      sku: '5',
      price: 17400,
      listPrice: 29000,
      breadcrumb: ['주방', '식기'],
    },
    context,
  );
  assert.equal(row.is_demo, false);
  assert.equal(row.source, '10x10');
  assert.equal(row.id, '10x10-5');
  assert.equal(row.category_id, 'living');
  assert.equal(row.discount_rate, 40);
});

test('상품명이나 URL 이 없으면 행을 만들지 않는다', () => {
  assert.equal(toProductRow({ name: '이름만 있음' }, context), null);
  assert.equal(toProductRow({ productUrl: 'https://example.test/x' }, context), null);
});

test('같은 입력은 항상 같은 id 를 만든다', () => {
  const input = { name: 'sku 없는 상품', productUrl: 'https://example.test/p/no-sku' };
  assert.equal(toProductRow(input, context).id, toProductRow(input, context).id);
});

test('분류는 공급원 분류를 먼저 믿는다', () => {
  assert.equal(guessCategory('마우스패드'), 'desk');
  assert.equal(guessCategory('알 수 없는 말'), 'hobby');
  assert.equal(guessCategory('알 수 없는 말', null), null);
});

test('가격 구간은 앱의 BudgetBand 와 같은 경계를 쓴다', () => {
  assert.equal(priceBand(10000), 'under10k');
  assert.equal(priceBand(10001), 'from10kTo30k');
  assert.equal(priceBand(100001), 'over100k');
});

test('robots 의 allow/disallow 는 더 긴 패턴이 이긴다', () => {
  const rules = { allow: ['/shopping/'], disallow: ['/', '/shopping/secret'] };
  assert.equal(isAllowed(rules, '/shopping/category_prd.asp'), true);
  assert.equal(isAllowed(rules, '/shopping/secret/x'), false);
  assert.equal(isAllowed(rules, '/member/login'), false);
  assert.equal(isAllowed(null, '/anything'), true);
});

test('재고는 availability 로 읽고, 모르면 null 로 둔다', () => {
  assert.equal(readStock('https://schema.org/InStock'), true);
  assert.equal(readStock('https://schema.org/OutOfStock'), false);
  assert.equal(readStock(null), null);
  assert.equal(readStock('알 수 없는 값'), null);
});

test('중복키는 표기가 달라도 같은 상품이면 같다', () => {
  assert.equal(
    dedupeKey('몬치치', '[몬치치] 얼굴 파우치 키링'),
    dedupeKey('몬치치', '몬치치 얼굴 파우치 키링'),
  );
  assert.notEqual(dedupeKey('A', '가방'), dedupeKey('B', '가방'));
});

test('중복 통합은 가격·재고·가격순으로 하나만 남긴다', () => {
  const make = (id, price, inStock) => ({
    id,
    dedupe_key: 'same',
    price,
    in_stock: inStock,
  });

  const { merged, dropped } = mergeDuplicates([
    make('b', null, true),
    make('a', 10000, true),
    make('c', 8000, true),
    make('d', 5000, false), // 품절은 가격이 싸도 고르지 않는다.
  ]);

  assert.equal(merged.length, 1);
  assert.equal(dropped, 3);
  assert.equal(merged[0].id, 'c');
});

test('이미 DB 에 있는 상품은 다시 만들지 않는다', () => {
  const known = new Map([['same', '10x10-1']]);
  const { merged, dropped } = mergeDuplicates(
    [{ id: 'musinsa-9', dedupe_key: 'same', price: 1000, in_stock: true }],
    known,
  );
  assert.equal(merged.length, 0);
  assert.equal(dropped, 1);
});

test('중복키가 없는 상품은 그대로 남는다', () => {
  const { merged } = mergeDuplicates([{ id: 'x', dedupe_key: null, price: 1 }]);
  assert.equal(merged.length, 1);
});

test('어댑터 보완값이 들어오면 가격과 저자가 채워진다', () => {
  // 알라딘 도서처럼 JSON-LD 가 없어 메타데이터로만 읽힌 뒤,
  // 어댑터 enrich 가 화면에 공개된 값을 채워 준 상황.
  const row = toProductRow(
    {
      name: '한국사 이상현상 연구원',
      brand: '최인서',
      productUrl: 'https://example.test/book/1',
      price: 16830,
      listPrice: 22000,
    },
    { ...context, sourceId: 'aladin', sourceLabel: '알라딘', categoryHint: 'book' },
  );

  assert.equal(row.price, 16830);
  assert.equal(row.original_price, 22000);
  assert.equal(row.discount_rate, 24);
  assert.equal(row.brand_name, '최인서');
  assert.equal(row.category_id, 'book');
});

test('분류 힌트는 공급원 분류가 없을 때만 쓴다', () => {
  const withBreadcrumb = toProductRow(
    {
      name: '무언가',
      productUrl: 'https://example.test/1',
      sku: '1',
      breadcrumb: ['주방', '식기'],
    },
    { ...context, categoryHint: 'book' },
  );
  assert.equal(withBreadcrumb.category_id, 'living');

  const withoutBreadcrumb = toProductRow(
    { name: '무언가', productUrl: 'https://example.test/2', sku: '2' },
    { ...context, categoryHint: 'book' },
  );
  assert.equal(withoutBreadcrumb.category_id, 'book');
});

test('중복으로 빠진 판매처도 offer 로 남는다', () => {
  const make = (id, source, price) => ({
    id,
    source,
    source_url: `https://${source}.test/${id}`,
    dedupe_key: 'same',
    price,
    in_stock: true,
    collected_at: '2026-01-01T00:00:00.000Z',
  });

  const { merged, offers } = mergeDuplicates([
    make('10x10-1', '10x10', 20000),
    make('musinsa-9', 'musinsa', 17000),
  ]);

  // 대표는 더 싼 쪽 하나만 남는다.
  assert.equal(merged.length, 1);
  assert.equal(merged[0].id, 'musinsa-9');

  // 두 판매처의 가격·URL 은 모두 보존된다.
  assert.equal(offers.length, 2);
  assert.deepEqual(
    offers.map((offer) => offer.source).sort(),
    ['10x10', 'musinsa'],
  );
  assert.ok(offers.every((offer) => offer.product_id === 'musinsa-9'));
  assert.ok(offers.every((offer) => offer.source_url.startsWith('https://')));
});

test('중복이 없어도 자기 판매처는 offer 로 남는다', () => {
  const { offers } = mergeDuplicates([
    {
      id: '10x10-1',
      source: '10x10',
      source_url: 'https://x.test/1',
      dedupe_key: 'only',
      price: 1000,
      in_stock: true,
    },
  ]);
  assert.equal(offers.length, 1);
  assert.equal(offers[0].product_id, '10x10-1');
});

test('앞서 저장한 상품은 다음 묶음에서 다시 만들지 않는다', () => {
  // 공급원별로 나눠 저장할 때, 먼저 저장한 상품의 중복키를 이어서 쓰는 상황.
  const known = new Map();

  const first = mergeDuplicates(
    [
      {
        id: '10x10-1',
        source: '10x10',
        source_url: 'https://a.test/1',
        dedupe_key: 'same',
        price: 20000,
        in_stock: true,
      },
    ],
    known,
  );
  assert.equal(first.merged.length, 1);

  // 저장이 끝나면 호출부가 known 에 더한다(saveBatch 가 하는 일).
  for (const row of first.merged) known.set(row.dedupe_key, row.id);

  // 다음 공급원이 같은 상품을 들고 와도 새 상품을 만들지 않는다.
  const second = mergeDuplicates(
    [
      {
        id: '29cm-9',
        source: '29cm',
        source_url: 'https://b.test/9',
        dedupe_key: 'same',
        price: 17000,
        in_stock: true,
      },
    ],
    known,
  );
  assert.equal(second.merged.length, 0);
  assert.equal(second.dropped, 1);

  // 다만 판매처 정보는 먼저 저장된 상품에 매달아 보존한다.
  assert.equal(second.offers.length, 1);
  assert.equal(second.offers[0].product_id, '10x10-1');
  assert.equal(second.offers[0].source, '29cm');
});

test('검색어 힌트가 상품명을 이기지 않는다', () => {
  // "향수"로 검색하면 바디로션·훈증기 같은 것이 딸려 온다.
  // 힌트를 상품명보다 먼저 쓰면 이런 것들이 향수로 들어간다.
  const row = (name, hint) =>
    toProductRow(
      { name, productUrl: `https://example.test/${encodeURIComponent(name)}`, sku: name, price: 1000 },
      { ...context, categoryHint: hint },
    );

  assert.equal(row('샤넬 5 레뮐지옹 바디 로션 200ml', 'perfume').category_id, 'body_care');
  assert.equal(row('오리지날 샌드위치 와플메이커', 'dessert').category_id, 'appliance');
  assert.equal(row('욜로브 캠핑 법랑컵 350ml', 'tea_coffee').category_id, 'tumbler');
  assert.equal(row('모노 트라우져 삭스 화이트', 'beauty').category_id, 'fashion_accessory');

  // 상품명이 분류를 말해 주지 않을 때만 힌트를 쓴다.
  assert.equal(row('이름만으로는 알 수 없는 물건', 'perfume').category_id, 'perfume');
});

test('한 글자 낱말이 다른 단어에 묻혀 오분류되지 않는다', () => {
  // '립' 이 '플립' 안에 들어 있어 신발이 뷰티로 분류되던 문제.
  assert.equal(guessCategory('여아 키즈 구두 플립 신발'), 'shoes');
  assert.equal(guessCategory('맥 립스틱 루비우'), 'beauty');
});

test('사람에게 주는 선물이 아닌 상품은 카탈로그에 넣지 않는다', () => {
  const pet = toProductRow(
    {
      name: '고양이 페로몬 펠리웨이 호환 훈증기',
      productUrl: 'https://example.test/pet',
      sku: 'pet',
      price: 20000,
    },
    { ...context, categoryHint: 'perfume' },
  );
  assert.equal(pet, null);
});

test('재고 상태와 확인 시각을 함께 남긴다', () => {
  const row = toProductRow(
    {
      name: '품절된 상품',
      productUrl: 'https://example.test/x',
      sku: 'x',
      price: 1000,
      availability: 'https://schema.org/OutOfStock',
    },
    context,
  );
  assert.equal(row.availability, 'out_of_stock');
  assert.equal(row.in_stock, false);
  assert.equal(row.last_verified_at, context.collectedAt);

  const unknown = toProductRow(
    { name: '재고 모름', productUrl: 'https://example.test/y', sku: 'y', price: 1000 },
    context,
  );
  // 알려 주지 않으면 품절로 단정하지 않는다.
  assert.equal(unknown.availability, 'unknown');
  assert.equal(unknown.in_stock, null);
});
