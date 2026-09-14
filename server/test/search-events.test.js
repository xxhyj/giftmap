/**
 * 검색 기록 계약 테스트.
 *
 * 개인을 식별할 값이 저장소로 넘어가지 않는지, 남기지 않기로 한 입력이
 * 정말 안 남는지를 확인한다.
 */

import assert from 'node:assert/strict';
import test, { afterEach, beforeEach } from 'node:test';

import searchEvents from '../api/search-events.js';
import { resetForTest } from '../lib/ratelimit.js';
import { normalizeKeyword, parseKind } from '../lib/validate.js';
import { makeReq, makeRes } from './helpers.js';

const FAKE_ENV = {
  SUPABASE_URL: 'https://example.supabase.co',
  SUPABASE_SERVICE_ROLE_KEY: 'test-only-not-a-real-key',
};

let realFetch;

beforeEach(() => {
  realFetch = globalThis.fetch;
  resetForTest();
  Object.assign(process.env, FAKE_ENV);
});

afterEach(() => {
  globalThis.fetch = realFetch;
  for (const name of Object.keys(FAKE_ENV)) delete process.env[name];
});

/** 저장소로 나간 요청을 모아 둔다. */
function stubFetch(rows = []) {
  const calls = [];
  globalThis.fetch = async (url, options = {}) => {
    calls.push({
      url: String(url),
      method: options.method ?? 'GET',
      body: options.body ? JSON.parse(options.body) : null,
    });
    return {
      ok: true,
      status: 200,
      headers: { get: () => `0-${Math.max(0, rows.length - 1)}/${rows.length}` },
      async json() {
        return rows;
      },
    };
  };
  return calls;
}

test('검색어만 다듬어 남긴다', () => {
  assert.equal(normalizeKeyword('  텀블러 '), '텀블러');
  assert.equal(normalizeKeyword('Hand Cream'), 'hand cream');
  // 문장처럼 긴 입력은 개인적인 내용을 담을 수 있어 남기지 않는다.
  assert.equal(normalizeKeyword('여자친구 생일 선물 뭐가 좋을까'), null);
  assert.equal(normalizeKeyword('x'.repeat(21)), null);
  assert.equal(normalizeKeyword('   '), null);
  assert.equal(normalizeKeyword(null), null);
});

test('종류는 둘뿐이고 모르는 값은 검색으로 본다', () => {
  assert.equal(parseKind('click'), 'click');
  assert.equal(parseKind('search'), 'search');
  assert.equal(parseKind('무엇이든'), 'search');
});

test('검색어와 종류만 저장소로 보낸다', async () => {
  const calls = stubFetch();
  const res = makeRes();

  await searchEvents(
    makeReq({
      method: 'POST',
      body: { keyword: '텀블러', kind: 'search', userId: '누구', deviceId: 'abc' },
    }),
    res,
  );

  assert.equal(res.statusCode, 202);
  assert.equal(res.json.recorded, true);
  const sent = calls[0].body;
  assert.deepEqual(sent, { keyword: '텀블러', kind: 'search' });
  // 보내지 않기로 한 값이 섞여 나가면 안 된다.
  assert.equal('userId' in sent, false);
  assert.equal('deviceId' in sent, false);
});

test('남기지 않기로 한 입력은 저장소를 부르지 않는다', async () => {
  const calls = stubFetch();
  const res = makeRes();

  await searchEvents(
    makeReq({ method: 'POST', body: { keyword: '남자친구 100일 선물 추천해줘' } }),
    res,
  );

  // 오류가 아니다. 앱은 그대로 검색을 이어간다.
  assert.equal(res.statusCode, 202);
  assert.equal(res.json.recorded, false);
  assert.equal(calls.length, 0);
});

test('집계된 검색어를 읽는다', async () => {
  stubFetch([
    { keyword: '텀블러', recent: 12, previous: 4 },
    { keyword: '디퓨저', recent: 8, previous: 9 },
  ]);
  const res = makeRes();

  await searchEvents(makeReq({ method: 'GET', query: { limit: '8' } }), res);

  assert.equal(res.statusCode, 200);
  assert.equal(res.json.trends.length, 2);
  assert.deepEqual(res.json.trends[0], {
    keyword: '텀블러',
    recent: 12,
    previous: 4,
  });
});

test('깨진 본문은 400', async () => {
  stubFetch();
  const res = makeRes();

  await searchEvents(makeReq({ method: 'POST', body: '{이건 JSON 이 아니다' }), res);

  assert.equal(res.statusCode, 400);
  assert.equal(res.json.error.code, 'invalid_body');
});

test('환경변수가 없으면 503', async () => {
  for (const name of Object.keys(FAKE_ENV)) delete process.env[name];
  const res = makeRes();

  await searchEvents(makeReq({ method: 'POST', body: { keyword: '텀블러' } }), res);

  assert.equal(res.statusCode, 503);
});
