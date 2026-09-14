/**
 * 요청·응답을 다루는 공통 규칙.
 *
 * 오류는 어디서 나든 같은 모양으로 돌려준다.
 * `{ "error": { "code": "...", "message": "..." } }`
 * 앱은 code 로 분기하고 message 는 사람이 읽는 용도다.
 * 비밀키나 내부 스택은 담지 않는다.
 */

import { allowedOrigins } from './env.js';

/** 앱은 Origin 을 보내지 않는다. 브라우저에서 열어 볼 때를 위한 CORS 다. */
export function applyCors(req, res, env = process.env) {
  const allowed = allowedOrigins(env);
  const origin = req.headers?.origin;

  if (allowed.length === 0) {
    res.setHeader('access-control-allow-origin', '*');
  } else if (origin && allowed.includes(origin)) {
    res.setHeader('access-control-allow-origin', origin);
    res.setHeader('vary', 'Origin');
  } else {
    // 허용 목록에 없는 출처에는 CORS 헤더를 주지 않는다(요청 자체는 막지 않는다).
    res.setHeader('vary', 'Origin');
  }
  res.setHeader('access-control-allow-methods', 'GET, POST, OPTIONS');
  res.setHeader('access-control-allow-headers', 'content-type');
  res.setHeader('access-control-max-age', '86400');
}

export function sendJson(res, status, body, { cacheSeconds = 0 } = {}) {
  res.setHeader('content-type', 'application/json; charset=utf-8');
  if (cacheSeconds > 0) {
    res.setHeader(
      'cache-control',
      `public, s-maxage=${cacheSeconds}, stale-while-revalidate=${cacheSeconds * 2}`,
    );
  } else {
    res.setHeader('cache-control', 'no-store');
  }
  res.status(status).send(JSON.stringify(body));
}

export function sendError(res, status, code, message) {
  sendJson(res, status, { error: { code, message } });
}

/** 허용하지 않는 메서드면 응답까지 하고 false 를 돌려준다. */
export function guardMethod(req, res, allowed) {
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return false;
  }
  if (!allowed.includes(req.method)) {
    res.setHeader('allow', [...allowed, 'OPTIONS'].join(', '));
    sendError(res, 405, 'method_not_allowed', `${req.method} 는 받지 않습니다.`);
    return false;
  }
  return true;
}

/**
 * 본문을 JSON 으로 읽는다.
 *
 * Vercel 이 미리 파싱해 주면 그 값을 쓰고, 아니면 직접 읽는다.
 * 깨진 JSON 은 예외 대신 null 로 돌려 호출한 쪽이 400 으로 답하게 한다.
 */
export async function readJsonBody(req, { limitBytes = 32 * 1024 } = {}) {
  if (req.body && typeof req.body === 'object' && !Buffer.isBuffer(req.body)) {
    return req.body;
  }
  let raw = '';
  if (typeof req.body === 'string') {
    raw = req.body;
  } else if (Buffer.isBuffer(req.body)) {
    raw = req.body.toString('utf8');
  } else if (typeof req[Symbol.asyncIterator] === 'function') {
    let size = 0;
    const chunks = [];
    for await (const chunk of req) {
      size += chunk.length;
      if (size > limitBytes) return null;
      chunks.push(chunk);
    }
    raw = Buffer.concat(chunks).toString('utf8');
  }
  if (raw.trim().length === 0) return {};
  try {
    const parsed = JSON.parse(raw);
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed)
      ? parsed
      : null;
  } catch {
    return null;
  }
}

/** 호출자를 구분하는 값. 제한을 걸 때만 쓰고 저장하지 않는다. */
export function clientKey(req) {
  const forwarded = req.headers?.['x-forwarded-for'];
  if (typeof forwarded === 'string' && forwarded.length > 0) {
    return forwarded.split(',')[0].trim();
  }
  return req.socket?.remoteAddress ?? 'unknown';
}
