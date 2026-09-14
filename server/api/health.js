/**
 * GET /api/health
 *
 * 배포가 살아 있는지, 그리고 필요한 환경변수가 채워졌는지만 알려준다.
 * 값 자체는 절대 담지 않는다. 있다/없다만 말한다.
 */

import { openaiEnv, supabaseEnv } from '../lib/env.js';
import { applyCors, guardMethod, sendJson } from '../lib/http.js';

export default function handler(req, res) {
  applyCors(req, res);
  if (!guardMethod(req, res, ['GET'])) return;

  const supabase = supabaseEnv();
  const openai = openaiEnv();

  sendJson(res, 200, {
    status: 'ok',
    time: new Date().toISOString(),
    // 준비 상태만 알린다. 키·주소는 담지 않는다.
    ready: { products: supabase !== null, recommend: openai !== null },
  });
}
