/**
 * POST /api/recommend
 *
 * 조건을 받아 실제 상품 중에서 3~5개를 고른다.
 * OpenAI 호출은 여기서만 일어나고 앱에는 키가 없다.
 *
 * 요청 본문(모르는 값은 버린다):
 * ```json
 * { "relationship": "friend", "situation": "birthday",
 *   "budgetMin": 10000, "budgetMax": 50000,
 *   "ageBand": "twenties", "preference": "책", "avoidTags": [] }
 * ```
 *
 * 응답은 두 가지뿐이다.
 * - 성공: fallback false, picks 배열(productId·reason)
 * - 그 밖: fallback true, reason → 앱이 자기 로컬 엔진으로 추천을 이어간다
 *
 * 못 고르는 것은 오류가 아니다. 그래서 이 경우에도 200 으로 답한다.
 */

import { openaiEnv, recommendRateLimit, supabaseEnv } from '../lib/env.js';
import {
  applyCors,
  clientKey,
  guardMethod,
  readJsonBody,
  sendError,
  sendJson,
} from '../lib/http.js';
import { take } from '../lib/ratelimit.js';
import { recommend } from '../lib/recommend.js';
import { createSupabase, UpstreamError } from '../lib/supabase.js';
import { parseIntent } from '../lib/validate.js';

export default async function handler(req, res) {
  applyCors(req, res);
  if (!guardMethod(req, res, ['POST'])) return;

  const body = await readJsonBody(req);
  if (body === null) {
    return sendError(res, 400, 'invalid_body', '요청 본문을 JSON 으로 읽지 못했습니다.');
  }

  const env = supabaseEnv();
  if (!env) {
    // 상품을 못 읽으면 고를 수도 없다. 앱은 로컬 엔진으로 넘어간다.
    return sendJson(res, 200, { fallback: true, reason: '상품 저장소 설정이 없습니다.' });
  }

  // 모델 호출은 돈이 든다. 한 사람이 연달아 부르는 것만 막는다.
  const limit = recommendRateLimit();
  const gate = take(clientKey(req), limit);
  if (!gate.allowed) {
    res.setHeader('retry-after', String(gate.retryAfterSeconds));
    return sendError(
      res,
      429,
      'rate_limited',
      '추천 요청이 너무 잦습니다. 잠시 후 다시 시도해 주세요.',
    );
  }

  try {
    const result = await recommend({
      supabase: createSupabase(env),
      openai: openaiEnv(),
      intent: parseIntent(body),
    });
    sendJson(res, 200, result);
  } catch (error) {
    if (error instanceof UpstreamError) {
      return sendError(res, error.status, error.code, error.message);
    }
    return sendError(res, 500, 'internal_error', '추천을 만들지 못했습니다.');
  }
}
