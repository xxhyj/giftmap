import test from 'node:test';
import assert from 'node:assert/strict';

import { guessCategory, priceBand, toProductRow } from '../src/normalize.js';
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
