/**
 * 이미지 중계 계약 테스트.
 *
 * 중계는 잘못 만들면 남의 트래픽을 대신 내주는 통로가 된다.
 * 허용한 판매처 이미지만 지나가는지를 확인한다.
 */

import assert from 'node:assert/strict';
import test, { afterEach, beforeEach } from 'node:test';

import image from '../api/image.js';
import { makeReq, makeRes } from './helpers.js';

let realFetch;

beforeEach(() => {
  realFetch = globalThis.fetch;
});

afterEach(() => {
  globalThis.fetch = realFetch;
});

function stubImage({ type = 'image/jpeg', bytes = 1024, ok = true, status = 200 } = {}) {
  const calls = [];
  globalThis.fetch = async (url, options) => {
    calls.push({ url: String(url), headers: options?.headers ?? {} });
    return {
      ok,
      status,
      headers: { get: (name) => (name === 'content-type' ? type : null) },
      async arrayBuffer() {
        return new ArrayBuffer(bytes);
      },
    };
  };
  return calls;
}

test('허용한 판매처 이미지는 그대로 옮긴다', async () => {
  const calls = stubImage();
  const res = makeRes();

  await image(
    makeReq({ query: { u: 'https://thumbnail.10x10.co.kr/webimage/image/a.jpg' } }),
    res,
  );

  assert.equal(res.statusCode, 200);
  assert.equal(res.headers['content-type'], 'image/jpeg');
  // 상품 이미지는 잘 바뀌지 않는다. 오래 캐시해 옮기는 횟수를 줄인다.
  assert.match(res.headers['cache-control'], /max-age=86400/);
  assert.equal(calls.length, 1);
});

test('네 판매처 호스트를 모두 허용한다', async () => {
  for (const host of [
    'thumbnail.10x10.co.kr',
    'webimage.10x10.co.kr',
    'image.aladin.co.kr',
    'image.msscdn.net',
  ]) {
    stubImage();
    const res = makeRes();
    await image(makeReq({ query: { u: `https://${host}/a.jpg` } }), res);
    assert.equal(res.statusCode, 200, host);
  }
});

test('허용 목록 밖의 주소는 거절한다', async () => {
  // 아무 주소나 옮겨 주면 남의 트래픽을 대신 내주는 통로가 된다.
  let called = false;
  globalThis.fetch = async () => {
    called = true;
    throw new Error('여기까지 오면 안 된다');
  };

  for (const url of [
    'https://example.com/a.jpg',
    'https://evil.test/big.zip',
    'https://thumbnail.10x10.co.kr.evil.test/a.jpg',
    'http://thumbnail.10x10.co.kr/a.jpg',
  ]) {
    const res = makeRes();
    await image(makeReq({ query: { u: url } }), res);
    assert.equal(res.statusCode, 403, url);
    assert.equal(res.json.error.code, 'host_not_allowed');
  }
  assert.equal(called, false);
});

test('주소가 없거나 읽을 수 없으면 400', async () => {
  for (const u of [undefined, '', '주소가 아님']) {
    const res = makeRes();
    await image(makeReq({ query: { u } }), res);
    assert.equal(res.statusCode, 400);
  }
});

test('이미지가 아니면 거절한다', async () => {
  stubImage({ type: 'text/html' });
  const res = makeRes();

  await image(makeReq({ query: { u: 'https://image.aladin.co.kr/a.html' } }), res);

  assert.equal(res.statusCode, 415);
  assert.equal(res.json.error.code, 'not_an_image');
});

test('너무 크면 거절한다', async () => {
  stubImage({ bytes: 9 * 1024 * 1024 });
  const res = makeRes();

  await image(makeReq({ query: { u: 'https://image.aladin.co.kr/big.jpg' } }), res);

  assert.equal(res.statusCode, 413);
});

test('이미지 서버가 실패하면 502', async () => {
  stubImage({ ok: false, status: 404 });
  const res = makeRes();

  await image(makeReq({ query: { u: 'https://image.aladin.co.kr/none.jpg' } }), res);

  assert.equal(res.statusCode, 502);
});
