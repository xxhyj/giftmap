/**
 * GET /api/products/:id
 *
 * 상품 하나를 목록과 같은 모양으로 돌려준다.
 * 찜·최근 본 상품처럼 목록에 없는 상품을 한 건만 확인할 때 쓴다.
 */

import { supabaseEnv } from '../../lib/env.js';
import { applyCors, guardMethod, sendError, sendJson } from '../../lib/http.js';
import { getProduct, loadCategoryLabels, toProductJson } from '../../lib/products.js';
import { createSupabase, UpstreamError } from '../../lib/supabase.js';
import { parseProductId } from '../../lib/validate.js';

export default async function handler(req, res) {
  applyCors(req, res);
  if (!guardMethod(req, res, ['GET'])) return;

  const id = parseProductId(req.query?.id);
  if (!id) {
    return sendError(res, 400, 'invalid_id', '상품 id 가 올바르지 않습니다.');
  }

  const env = supabaseEnv();
  if (!env) {
    return sendError(
      res,
      503,
      'not_configured',
      '상품 저장소 설정이 없습니다. 배포 환경변수를 확인하세요.',
    );
  }

  const supabase = createSupabase(env);
  try {
    const row = await getProduct(supabase, id);
    if (!row) {
      return sendError(res, 404, 'not_found', '상품을 찾지 못했습니다.');
    }
    const labels = await loadCategoryLabels(supabase).catch(() => ({}));
    sendJson(res, 200, { product: toProductJson(row, labels) }, { cacheSeconds: 60 });
  } catch (error) {
    if (error instanceof UpstreamError) {
      return sendError(res, error.status, error.code, error.message);
    }
    return sendError(res, 500, 'internal_error', '상품을 불러오지 못했습니다.');
  }
}
