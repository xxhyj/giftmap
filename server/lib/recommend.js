/**
 * 추천.
 *
 * Supabase 에서 조건에 맞는 실제 상품 후보를 고르고, OpenAI 에게 그 후보
 * 중에서만 3~5개를 고르게 한다. 모델은 상품·가격·URL 을 만들 수 없고 고를 수만
 * 있다. 돌려주는 것은 실제로 존재하는 상품 id 뿐이다.
 *
 * 호출이 실패하거나 결과가 3개 미만이면 fallback 을 돌려주고, 앱은 자기
 * 로컬 엔진으로 계속한다. 추천이 없다고 화면이 비지는 않는다.
 */

import { UpstreamError } from './supabase.js';

const OPENAI_URL = 'https://api.openai.com/v1/chat/completions';
const CANDIDATE_LIMIT = 60;

/** 책을 바라는 조건인지. 아니라면 도서 후보를 조금만 보여 준다. */
export function wantsBooks(intent) {
  // preference 는 숫자(실용↔감성)로 올 수도 있다. 글자일 때만 뜻을 읽는다.
  const text = [
    typeof intent.preference === 'string' ? intent.preference : '',
    ...(intent.avoidTags ?? []),
  ]
    .join(' ')
    .toLowerCase();
  return /책|도서|독서|소설|에세이|book|reading/.test(text);
}

/**
 * 공급원과 분류를 번갈아 뽑는다.
 *
 * 최근 확인 순으로만 받으면 마지막에 수집한 공급원이 후보를 다 차지하고,
 * 상품 수가 가장 많은 도서가 후보를 메우면 모델은 책밖에 고를 수 없다.
 */
export function mixCandidates(items, limit, { allowBooks }) {
  const bySource = new Map();
  for (const item of items) {
    const source = item.source || 'unknown';
    if (!bySource.has(source)) bySource.set(source, new Map());
    const byCategory = bySource.get(source);
    const category = item.category || 'unknown';
    if (!byCategory.has(category)) byCategory.set(category, []);
    byCategory.get(category).push(item);
  }

  const lines = [];
  for (const source of [...bySource.keys()].sort()) {
    const byCategory = bySource.get(source);
    const categories = [...byCategory.keys()].sort();
    const line = [];
    for (let round = 0; ; round += 1) {
      let took = false;
      for (const category of categories) {
        const group = byCategory.get(category);
        if (round >= group.length) continue;
        line.push(group[round]);
        took = true;
      }
      if (!took) break;
    }
    lines.push(line);
  }

  const bookCap = allowBooks ? limit : Math.max(1, Math.floor(limit * 0.15));
  let books = 0;
  const out = [];
  const deferred = [];
  for (let round = 0; out.length < limit; round += 1) {
    let took = false;
    for (const line of lines) {
      if (round >= line.length) continue;
      took = true;
      const item = line[round];
      if (item.category === 'book' && books >= bookCap) {
        deferred.push(item);
        continue;
      }
      if (item.category === 'book') books += 1;
      out.push(item);
      if (out.length >= limit) break;
    }
    if (!took) break;
  }
  // 다른 분류가 모자라면 미뤄 둔 책으로 채운다.
  for (const item of deferred) {
    if (out.length >= limit) break;
    out.push(item);
  }
  return out;
}

/**
 * 모델이 고른 것을 한 번 더 고른다.
 *
 * 후보를 섞어 줘도 같은 분류·브랜드만 집어 오는 경우가 있다.
 * 분류는 2개, 브랜드는 1개까지만 남겨 서로 다른 선물이 되게 한다.
 */
export function diversify(picks, byId, { allowBooks }) {
  const perCategory = new Map();
  const perBrand = new Map();
  const kept = [];
  const spare = [];

  for (const pick of picks) {
    const item = byId.get(pick.id);
    if (!item) continue;
    const category = item.category || 'unknown';
    const brand = (item.brand ?? '').toLowerCase();
    const categoryCap = category === 'book' && !allowBooks ? 1 : 2;
    const categoryUsed = perCategory.get(category) ?? 0;
    const brandUsed = brand ? (perBrand.get(brand) ?? 0) : 0;
    if (categoryUsed >= categoryCap || (brand && brandUsed >= 1)) {
      spare.push(pick);
      continue;
    }
    perCategory.set(category, categoryUsed + 1);
    if (brand) perBrand.set(brand, brandUsed + 1);
    kept.push(pick);
  }
  // 3개를 못 채우면 걸러 낸 것으로 되돌려 채운다. 빈손보다는 낫다.
  for (const pick of spare) {
    if (kept.length >= 3) break;
    kept.push(pick);
  }
  return kept.slice(0, 5);
}

/** 조건에 맞는 후보를 읽어 섞는다. */
export async function loadCandidates(supabase, intent, limit = CANDIDATE_LIMIT) {
  const params = [
    [
      'select',
      'id,brand_name,product_name,price,category_id,tags,occasions,recipient_types,source,last_verified_at',
    ],
    ['is_demo', 'eq.false'],
    ['is_active', 'eq.true'],
    // 품절이 확인된 상품은 추천하지 않는다(모르는 상품은 남긴다).
    ['availability', 'neq.out_of_stock'],
    // 화면에 온전히 보여 줄 수 있는 상품만 고른다.
    ['image_url', 'not.is.null'],
    ['product_url', 'not.is.null'],
    ['price', 'not.is.null'],
    ['order', 'last_verified_at.desc.nullslast'],
    ['order', 'id.asc'],
    ['limit', String(limit * 5)],
  ];
  if (typeof intent.budgetMin === 'number') {
    params.push(['price', `gte.${intent.budgetMin}`]);
  }
  if (typeof intent.budgetMax === 'number') {
    params.push(['price', `lte.${intent.budgetMax}`]);
  }
  if (intent.situation) params.push(['occasions', `cs.{${intent.situation}}`]);
  if (intent.relationship) {
    params.push(['recipient_types', `cs.{${intent.relationship}}`]);
  }

  const { rows } = await supabase.request('products', params);
  const mapped = rows.map((row) => ({
    id: String(row.id),
    brand: row.brand_name ?? null,
    name: String(row.product_name),
    price: row.price ?? null,
    category: String(row.category_id ?? ''),
    tags: Array.isArray(row.tags) ? row.tags : [],
    occasions: Array.isArray(row.occasions) ? row.occasions : [],
    recipients: Array.isArray(row.recipient_types) ? row.recipient_types : [],
    source: String(row.source ?? ''),
  }));
  return mixCandidates(mapped, limit, { allowBooks: wantsBooks(intent) });
}

/** 후보 중에서만 고르게 하는 프롬프트. 새 상품을 만들 여지를 주지 않는다. */
export function buildMessages(intent, candidates) {
  const system = [
    '너는 선물 추천을 돕는다.',
    '아래 후보 목록에 있는 상품만 고를 수 있다.',
    '상품명·가격·링크를 새로 만들거나 바꾸지 마라. 목록에 없는 id 는 절대 쓰지 마라.',
    '조건에 맞는 서로 다른 상품 3~5개를 고른다.',
    '가능하면 분류와 판매처가 한쪽으로 쏠리지 않게 고른다.',
    '각 상품마다 왜 이 사람에게 맞는지 한 문장으로 설명한다.',
    'JSON 으로만 답한다.',
  ].join('\n');

  const user = [
    '조건:',
    JSON.stringify(intent, null, 2),
    '',
    '후보 목록(이 안에서만 고를 것):',
    JSON.stringify(candidates, null, 2),
    '',
    '답 모양: picks 배열 안에 id 와 reason 을 담는다.',
  ].join('\n');

  return [
    { role: 'system', content: system },
    { role: 'user', content: user },
  ];
}

/**
 * 추천 한 번.
 *
 * 돌려주는 모양은 두 가지뿐이다.
 * - 성공: fallback false, picks 배열(productId·reason), candidateCount
 * - 실패: fallback true, reason  → 앱이 로컬 엔진으로 넘어간다
 */
export async function recommend({
  supabase,
  openai,
  intent,
  fetchImpl = fetch,
  timeoutMs = 20_000,
}) {
  let candidates;
  try {
    candidates = await loadCandidates(supabase, intent);
  } catch (error) {
    if (error instanceof UpstreamError) throw error;
    return { fallback: true, reason: `후보 조회 실패: ${error?.message ?? error}` };
  }
  if (candidates.length === 0) {
    return { fallback: true, reason: '조건에 맞는 실제 상품이 없습니다.' };
  }
  if (!openai) {
    return { fallback: true, reason: '추천 모델이 설정되지 않았습니다.' };
  }

  let res;
  try {
    res = await fetchImpl(OPENAI_URL, {
      method: 'POST',
      headers: {
        authorization: `Bearer ${openai.key}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        model: openai.model,
        // temperature 는 지정하지 않는다. 모델에 따라 기본값만 받는다.
        response_format: { type: 'json_object' },
        messages: buildMessages(intent, candidates),
      }),
      signal: AbortSignal.timeout(timeoutMs),
    });
  } catch (error) {
    return { fallback: true, reason: `추천 모델 호출 실패: ${error?.name ?? error}` };
  }
  if (!res.ok) {
    // 응답 본문에는 키가 섞여 나올 수 있으므로 상태 코드만 남긴다.
    return { fallback: true, reason: `추천 모델 응답 ${res.status}` };
  }

  let parsed;
  try {
    const body = await res.json();
    parsed = JSON.parse(body?.choices?.[0]?.message?.content ?? '{}');
  } catch {
    return { fallback: true, reason: '추천 모델 응답을 읽지 못했습니다.' };
  }

  const byId = new Map(candidates.map((item) => [item.id, item]));
  const seen = new Set();
  const chosen = (Array.isArray(parsed?.picks) ? parsed.picks : [])
    .filter((pick) => typeof pick?.id === 'string' && byId.has(pick.id))
    .filter((pick) => !seen.has(pick.id) && seen.add(pick.id))
    .map((pick) => ({
      id: pick.id,
      reason: typeof pick.reason === 'string' ? pick.reason.slice(0, 200) : '',
    }));

  const picks = diversify(chosen, byId, { allowBooks: wantsBooks(intent) }).map(
    (pick) => ({ productId: pick.id, reason: pick.reason }),
  );

  // 3개 미만이면 신뢰하지 않고 앱의 로컬 엔진에 맡긴다.
  if (picks.length < 3) {
    return { fallback: true, reason: '모델이 고른 실제 상품이 3개 미만입니다.' };
  }
  return { fallback: false, picks, candidateCount: candidates.length };
}
