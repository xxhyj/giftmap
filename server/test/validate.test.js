import assert from 'node:assert/strict';
import test from 'node:test';

import {
  DEFAULT_LIMIT,
  MAX_LIMIT,
  parseCategory,
  parseIntent,
  parsePaging,
  parseProductId,
  parseQuery,
} from '../lib/validate.js';

test('페이지 기본값은 1쪽부터', () => {
  assert.deepEqual(parsePaging({}), {
    page: 1,
    limit: DEFAULT_LIMIT,
    offset: 0,
  });
});

test('page 와 limit 으로 offset 을 계산한다', () => {
  assert.deepEqual(parsePaging({ page: '3', limit: '20' }), {
    page: 3,
    limit: 20,
    offset: 40,
  });
});

test('말이 안 되는 값은 기본값으로 되돌린다', () => {
  // 0쪽·음수·글자·지나치게 큰 limit 은 그대로 쓰면 서버가 헛일을 한다.
  assert.equal(parsePaging({ page: '0' }).page, 1);
  assert.equal(parsePaging({ page: '-5' }).page, 1);
  assert.equal(parsePaging({ page: 'abc' }).page, 1);
  assert.equal(parsePaging({ limit: '99999' }).limit, MAX_LIMIT);
  assert.equal(parsePaging({ limit: '0' }).limit, DEFAULT_LIMIT);
});

test('분류는 영문·숫자·밑줄만 받는다', () => {
  assert.equal(parseCategory({ category: 'fashion_accessory' }), 'fashion_accessory');
  assert.equal(parseCategory({ category: 'book' }), 'book');
  assert.equal(parseCategory({ category: 'book;drop table' }), null);
  assert.equal(parseCategory({}), null);
});

test('검색어에서 필터 문법을 뜻하는 문자를 지운다', () => {
  // PostgREST 의 ilike 값에서 , . ( ) * 는 뜻을 갖는다. 그대로 두면 필터가 비틀린다.
  assert.equal(parseQuery({ query: '텀블러' }), '텀블러');
  assert.equal(parseQuery({ query: 'a,b.(c)*' }), 'a b c');
  assert.equal(parseQuery({ query: '   ' }), null);
  assert.equal(parseQuery({ query: 'x'.repeat(200) }).length, 60);
});

test('상품 id 는 수집기가 붙이는 모양만 받는다', () => {
  assert.equal(parseProductId('10x10-1234'), '10x10-1234');
  assert.equal(parseProductId('aladin-zu9oco'), 'aladin-zu9oco');
  assert.equal(parseProductId('a b'), null);
  assert.equal(parseProductId('../../etc/passwd'), null);
  assert.equal(parseProductId(undefined), null);
});

test('추천 조건은 아는 값만 남긴다', () => {
  const intent = parseIntent({
    relationship: 'friend',
    situation: 'birthday',
    ageBand: 'twenties',
    budgetMin: 10000,
    budgetMax: 50000,
    preference: 0.7,
    avoidTags: ['scent', 123],
    nickname: '누구',
  });

  assert.deepEqual(intent, {
    relationship: 'friend',
    situation: 'birthday',
    ageBand: 'twenties',
    budgetMin: 10000,
    budgetMax: 50000,
    preference: 0.7,
    avoidTags: ['scent'],
  });
  // 모르는 값은 모델에게 넘기지 않는다.
  assert.equal('nickname' in intent, false);
});

test('모르는 관계·상황은 버린다', () => {
  const intent = parseIntent({ relationship: 'boss', situation: '' });
  assert.deepEqual(intent, {});
});

test('앱이 보내는 값은 그대로 통과한다', () => {
  // 앱의 RelationshipType·GiftSituation·AgeBand wireName 과 같아야 한다.
  for (const relationship of ['partner', 'friend', 'family', 'colleague', 'manager', 'acquaintance']) {
    assert.equal(parseIntent({ relationship }).relationship, relationship);
  }
  for (const situation of ['birthday', 'anniversary', 'promotion', 'thanks', 'housewarming', 'birth', 'holiday', 'support', 'other']) {
    assert.equal(parseIntent({ situation }).situation, situation);
  }
  for (const ageBand of ['teens', 'twenties', 'thirties', 'fortiesPlus', 'unspecified']) {
    assert.equal(parseIntent({ ageBand }).ageBand, ageBand);
  }
});

test('preference 는 실수로도 글자로도 받는다', () => {
  // 앱은 0.0~1.0 실수를 보낸다. 범위를 벗어나면 잘라서 쓴다.
  assert.equal(parseIntent({ preference: 0.7 }).preference, 0.7);
  assert.equal(parseIntent({ preference: 5 }).preference, 1);
  assert.equal(parseIntent({ preference: -1 }).preference, 0);
  assert.equal(parseIntent({ preference: '책' }).preference, '책');
});

test('뒤집힌 예산은 버린다', () => {
  // 그대로 쓰면 결과가 반드시 0건이 된다.
  const intent = parseIntent({ budgetMin: 50000, budgetMax: 1000 });
  assert.equal('budgetMin' in intent, false);
  assert.equal('budgetMax' in intent, false);
});
