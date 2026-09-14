/**
 * GET /api/image?u=<판매처 이미지 주소>
 *
 * 판매처 이미지를 그대로 옮겨 준다. 웹 브라우저에서만 쓴다.
 *
 * 앱에서는 필요 없다. 안드로이드에는 CORS 가 없어 판매처 주소를 직접 읽는다.
 * 브라우저에서는 판매처 이미지 서버가 다른 출처의 요청을 막아(텐바이텐이 그렇다)
 * 이미지가 통째로 비어 보인다.
 *
 * 아무 주소나 옮겨 주면 남의 트래픽을 대신 내주는 통로가 된다. 그래서
 * **수집한 판매처의 이미지 호스트만** 허용하고, 이미지가 아닌 응답은 거절한다.
 */

import { applyCors, guardMethod, sendError } from '../lib/http.js';

/** 수집 대상 판매처의 이미지 호스트. 이 목록 밖은 옮기지 않는다. */
const ALLOWED_HOSTS = new Set([
  'thumbnail.10x10.co.kr',
  'webimage.10x10.co.kr',
  'image.aladin.co.kr',
  'image.msscdn.net',
]);

/** 옮겨 줄 수 있는 최대 크기. 이보다 크면 이미지가 아니라고 본다. */
const MAX_BYTES = 8 * 1024 * 1024;
const TIMEOUT_MS = 10_000;

export default async function handler(req, res) {
  applyCors(req, res);
  if (!guardMethod(req, res, ['GET'])) return;

  const raw = Array.isArray(req.query?.u) ? req.query.u[0] : req.query?.u;
  if (typeof raw !== 'string' || raw.length === 0 || raw.length > 2048) {
    return sendError(res, 400, 'invalid_url', '이미지 주소가 없습니다.');
  }

  let url;
  try {
    url = new URL(raw);
  } catch {
    return sendError(res, 400, 'invalid_url', '이미지 주소를 읽지 못했습니다.');
  }
  if (url.protocol !== 'https:' || !ALLOWED_HOSTS.has(url.hostname)) {
    return sendError(res, 403, 'host_not_allowed', '허용하지 않은 이미지 주소입니다.');
  }

  let upstream;
  try {
    upstream = await fetch(url, {
      // 판매처가 참조 페이지를 보는 경우가 있어 자기 사이트에서 온 것처럼 알린다.
      headers: { referer: `${url.protocol}//${url.hostname}/`, accept: 'image/*' },
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
  } catch (error) {
    return sendError(res, 504, 'upstream_timeout', '이미지를 가져오지 못했습니다.');
  }
  if (!upstream.ok) {
    return sendError(res, 502, 'upstream_error', `이미지 서버가 ${upstream.status} 를 돌려줬습니다.`);
  }

  const type = upstream.headers.get('content-type') ?? '';
  if (!type.startsWith('image/')) {
    return sendError(res, 415, 'not_an_image', '이미지가 아닙니다.');
  }

  const body = Buffer.from(await upstream.arrayBuffer());
  if (body.length > MAX_BYTES) {
    return sendError(res, 413, 'too_large', '이미지가 너무 큽니다.');
  }

  res.setHeader('content-type', type);
  res.setHeader('content-length', String(body.length));
  // 상품 이미지는 잘 바뀌지 않는다. 오래 캐시해 옮기는 횟수를 줄인다.
  res.setHeader('cache-control', 'public, max-age=86400, s-maxage=604800, immutable');
  res.status(200).send(body);
}
