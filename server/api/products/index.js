/**
 * GET /api/products?page=&limit=&category=&query=
 *
 * 앱이 화면에 바로 쓸 수 있는 모양으로 상품 한 페이지를 돌려준다.
 *
 * ```json
 * {
 *   "page": 1, "limit": 60, "total": 1886, "hasMore": true,
 *   "disclaimer": "...",
 *   "searchSuggestions": ["향수"],
 *   "products": [{ "id": "...", "productName": "...", ... }]
 * }
 * ```
 *
 * 첫 페이지에만 고지 문구와 추천 검색어를 함께 싣는다. 뒷 페이지에서 다시
 * 받아 봐야 같은 값이고 호출만 늘어난다.
 */

import { supabaseEnv } from '../../lib/env.js';
import { applyCors, guardMethod, sendError, sendJson } from '../../lib/http.js';
import {
  listProducts,
  loadCategoryLabels,
  loadSearchSuggestions,
  toProductJson,
} from '../../lib/products.js';
import { createSupabase, UpstreamError } from '../../lib/supabase.js';
import { parseCategory, parsePaging, parseQuery } from '../../lib/validate.js';

/** 수집한 실제 상품에 붙는 고지. 앱의 문구와 같은 뜻이다. */
const DISCLAIMER =
  '판매처에 공개된 정보를 옮긴 실제 상품입니다. 가격과 재고는 판매처 기준으로 달라질 수 있습니다.';

export default async function handler(req, res) {
  applyCors(req, res);
  if (!guardMethod(req, res, ['GET'])) return;

  const env = supabaseEnv();
  if (!env) {
    return sendError(
      res,
      503,
      'not_configured',
      '상품 저장소 설정이 없습니다. 배포 환경변수를 확인하세요.',
    );
  }

  const { page, limit, offset } = parsePaging(req.query);
  const category = parseCategory(req.query);
  const query = parseQuery(req.query);
  const supabase = createSupabase(env);

  try {
    // 셋을 한꺼번에 물어본다. 차례로 물으면 상류가 깨어나는 시간이 그만큼 쌓인다.
    // 추천 검색어는 첫 페이지에만 싣고, 실패해도 상품은 그대로 내보낸다.
    const [{ rows, total, hasMore }, labels, searchSuggestions] =
      await Promise.all([
        listProducts(supabase, { offset, limit, category, query }),
        loadCategoryLabels(supabase),
        page === 1 ? loadSearchSuggestions(supabase).catch(() => []) : [],
      ]);

    sendJson(
      res,
      200,
      {
        page,
        limit,
        total,
        hasMore,
        disclaimer: page === 1 ? DISCLAIMER : '',
        searchSuggestions,
        products: rows.map((row) => toProductJson(row, labels)),
      },
      // 상품은 자주 바뀌지 않는다. 잠깐 캐시해 호출을 줄인다.
      { cacheSeconds: 60 },
    );
  } catch (error) {
    if (error instanceof UpstreamError) {
      return sendError(res, error.status, error.code, error.message);
    }
    return sendError(res, 500, 'internal_error', '상품을 불러오지 못했습니다.');
  }
}
