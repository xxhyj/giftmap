/**
 * POST /api/search-events  — 검색했음을 익명으로 남긴다
 * GET  /api/search-events  — 집계된 인기 검색어를 읽는다
 *
 * 개인을 식별할 수 있는 값은 받지도 저장하지도 않는다. 사용자 id·기기 id 없이
 * 정규화한 검색어 하나와 종류(search/click)만 남긴다. 20자를 넘거나 문장처럼
 * 긴 입력은 개인적인 내용을 담을 수 있어 아예 기록하지 않는다.
 *
 * 집계는 `search_trends` 뷰가 3회 이상 검색어만 세므로, 한두 사람의 입력이
 * 그대로 드러나지 않는다.
 */

import { supabaseEnv } from '../lib/env.js';
import {
  applyCors,
  clientKey,
  guardMethod,
  readJsonBody,
  sendError,
  sendJson,
} from '../lib/http.js';
import { take } from '../lib/ratelimit.js';
import { createSupabase, UpstreamError } from '../lib/supabase.js';
import { normalizeKeyword, parseKind, parsePaging } from '../lib/validate.js';

/** 한 사람이 검색 기록으로 저장소를 두드리는 횟수. */
const RECORD_LIMIT_PER_MINUTE = 60;

export default async function handler(req, res) {
  applyCors(req, res);
  if (!guardMethod(req, res, ['GET', 'POST'])) return;

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

  if (req.method === 'GET') return readTrends(req, res, supabase);
  return recordEvent(req, res, supabase);
}

async function readTrends(req, res, supabase) {
  const { limit } = parsePaging({ limit: req.query?.limit ?? '8' });
  try {
    const { rows } = await supabase.request('search_trends', [
      ['select', 'keyword,recent,previous'],
      ['order', 'recent.desc'],
      ['limit', String(Math.min(limit, 20))],
    ]);
    sendJson(
      res,
      200,
      {
        trends: rows
          .filter((row) => row?.keyword)
          .map((row) => ({
            keyword: String(row.keyword),
            recent: Number(row.recent ?? 0),
            previous: Number(row.previous ?? 0),
          })),
      },
      { cacheSeconds: 300 },
    );
  } catch (error) {
    if (error instanceof UpstreamError) {
      return sendError(res, error.status, error.code, error.message);
    }
    return sendError(res, 500, 'internal_error', '검색어 집계를 읽지 못했습니다.');
  }
}

async function recordEvent(req, res, supabase) {
  const body = await readJsonBody(req);
  if (body === null) {
    return sendError(res, 400, 'invalid_body', '요청 본문을 JSON 으로 읽지 못했습니다.');
  }

  const keyword = normalizeKeyword(body.keyword);
  const kind = parseKind(body.kind);
  if (!keyword) {
    // 남기지 않기로 한 입력이다. 오류가 아니므로 앱을 멈추지 않는다.
    return sendJson(res, 202, { recorded: false, reason: 'not_recordable' });
  }

  const gate = take(`search:${clientKey(req)}`, RECORD_LIMIT_PER_MINUTE);
  if (!gate.allowed) {
    res.setHeader('retry-after', String(gate.retryAfterSeconds));
    return sendError(res, 429, 'rate_limited', '검색 기록이 너무 잦습니다.');
  }

  try {
    await supabase.insert('search_events', { keyword, kind });
    sendJson(res, 202, { recorded: true });
  } catch (error) {
    if (error instanceof UpstreamError) {
      return sendError(res, error.status, error.code, error.message);
    }
    return sendError(res, 500, 'internal_error', '검색 기록을 남기지 못했습니다.');
  }
}
