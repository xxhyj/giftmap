/**
 * Giftmap 추천 Edge Function.
 *
 * 앱이 사용자의 조건(관계·상황·예산 등)을 보내면, 이 함수가
 *   1. Supabase 에서 조건에 맞는 **실제 상품**만 후보로 추린 뒤
 *   2. OpenAI 에게 그 후보 중 3~5개를 고르게 하고
 *   3. 실제로 존재하는 상품 id 만 남겨 돌려준다.
 *
 * 모델은 상품·가격·URL 을 만들어 낼 수 없다. 고를 수만 있다.
 * 모델이 없는 id 를 말하면 버린다. 실패하면 `fallback: true` 로 답하고,
 * 앱은 자기 추천 엔진(실제 상품 대상)으로 계속한다.
 *
 * OPENAI_API_KEY 는 이 함수의 시크릿으로만 존재하며 앱에는 들어가지 않는다.
 */

const OPENAI_URL = 'https://api.openai.com/v1/chat/completions';

/**
 * 쓸 모델. 프로젝트가 접근할 수 있는 모델이어야 한다.
 * 다른 모델을 쓰려면 함수 시크릿 `OPENAI_MODEL` 로 바꾼다.
 */
const MODEL = Deno.env.get('OPENAI_MODEL') ?? 'gpt-5-nano';

const CORS_HEADERS = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'authorization, x-client-info, apikey, content-type',
  'access-control-allow-methods': 'POST, OPTIONS',
};

/** 앱이 보내는 조건. 값이 없으면 조건 없이 넓게 고른다. */
interface GiftIntent {
  relationship?: string;
  situation?: string;
  budgetMin?: number;
  budgetMax?: number;
  preferences?: string[];
  avoidTags?: string[];
  ageBand?: string;
  note?: string;
}

/** 모델에게 보여 줄 후보. 링크와 가격은 보여 주되 바꾸지 못한다. */
interface Candidate {
  id: string;
  brand: string | null;
  name: string;
  price: number | null;
  category: string;
  tags: string[];
  occasions: string[];
  recipients: string[];
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json', ...CORS_HEADERS },
  });
}

/** Supabase REST 로 조건에 맞는 실제 상품 후보를 읽는다. */
async function loadCandidates(intent: GiftIntent, limit = 60): Promise<Candidate[]> {
  const url = Deno.env.get('SUPABASE_URL');
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? Deno.env.get('SUPABASE_ANON_KEY');
  if (!url || !key) throw new Error('Supabase 환경변수가 없습니다.');

  const query = new URL(`${url}/rest/v1/products`);
  query.searchParams.set(
    'select',
    'id,brand_name,product_name,price,category_id,tags,occasions,recipient_types',
  );
  // 실제 상품만, 판매 중인 것만 고른다.
  query.searchParams.set('is_demo', 'eq.false');
  query.searchParams.set('is_active', 'eq.true');
  query.searchParams.append('in_stock', 'not.is.false');
  if (typeof intent.budgetMin === 'number') {
    query.searchParams.append('price', `gte.${Math.max(0, intent.budgetMin)}`);
  }
  if (typeof intent.budgetMax === 'number') {
    query.searchParams.append('price', `lte.${intent.budgetMax}`);
  }
  if (intent.situation) {
    query.searchParams.append('occasions', `cs.{${intent.situation}}`);
  }
  if (intent.relationship) {
    query.searchParams.append('recipient_types', `cs.{${intent.relationship}}`);
  }
  query.searchParams.set('order', 'id.asc');
  query.searchParams.set('limit', String(limit));

  const res = await fetch(query, {
    headers: { apikey: key, authorization: `Bearer ${key}` },
  });
  if (!res.ok) throw new Error(`상품 조회 실패: ${res.status}`);

  const rows = await res.json();
  return (rows as Record<string, unknown>[]).map((row) => ({
    id: String(row.id),
    brand: (row.brand_name as string) ?? null,
    name: String(row.product_name),
    price: (row.price as number) ?? null,
    category: String(row.category_id ?? ''),
    tags: (row.tags as string[]) ?? [],
    occasions: (row.occasions as string[]) ?? [],
    recipients: (row.recipient_types as string[]) ?? [],
  }));
}

/** 후보 중에서만 고르게 하는 프롬프트. 새 상품을 만들 여지를 주지 않는다. */
function buildMessages(intent: GiftIntent, candidates: Candidate[]) {
  const system = [
    '너는 선물 추천을 돕는다.',
    '아래 후보 목록에 있는 상품만 고를 수 있다.',
    '상품명·가격·링크를 새로 만들거나 바꾸지 마라. 목록에 없는 id 는 절대 쓰지 마라.',
    '조건에 맞는 서로 다른 상품 3~5개를 고른다.',
    '각 상품마다 왜 이 사람에게 맞는지 한 문장으로 설명한다.',
    'JSON 으로만 답한다: {"picks":[{"id":"...","reason":"..."}]}',
  ].join('\n');

  const user = [
    '조건:',
    JSON.stringify(intent, null, 2),
    '',
    '후보 목록(이 안에서만 고를 것):',
    JSON.stringify(candidates, null, 2),
  ].join('\n');

  return [
    { role: 'system', content: system },
    { role: 'user', content: user },
  ];
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS_HEADERS });
  if (req.method !== 'POST') return json({ error: 'POST 만 받습니다.' }, 405);

  let intent: GiftIntent;
  try {
    intent = (await req.json()) as GiftIntent;
  } catch {
    return json({ error: '요청 본문을 읽지 못했습니다.' }, 400);
  }

  let candidates: Candidate[] = [];
  try {
    candidates = await loadCandidates(intent);
  } catch (error) {
    // 상품을 못 읽으면 추천할 수 없다. 앱이 자기 엔진으로 넘어가게 한다.
    return json({ fallback: true, reason: `후보 조회 실패: ${error}` });
  }
  if (candidates.length === 0) {
    return json({ fallback: true, reason: '조건에 맞는 실제 상품이 없습니다.' });
  }

  const apiKey = Deno.env.get('OPENAI_API_KEY');
  if (!apiKey) {
    return json({ fallback: true, reason: 'OPENAI_API_KEY 가 설정되지 않았습니다.' });
  }

  try {
    const res = await fetch(OPENAI_URL, {
      method: 'POST',
      headers: {
        authorization: `Bearer ${apiKey}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        model: MODEL,
        // temperature 는 지정하지 않는다. 모델에 따라 기본값만 받는다.
        response_format: { type: 'json_object' },
        messages: buildMessages(intent, candidates),
      }),
      signal: AbortSignal.timeout(20_000),
    });
    if (!res.ok) {
      // 왜 거절됐는지 알 수 있게 응답 본문을 짧게 함께 남긴다.
      const detail = (await res.text().catch(() => '')).slice(0, 300);
      return json({ fallback: true, reason: `OpenAI 응답 ${res.status}`, detail });
    }

    const body = await res.json();
    const content = body?.choices?.[0]?.message?.content ?? '{}';
    const parsed = JSON.parse(content) as { picks?: { id?: string; reason?: string }[] };

    // 모델이 만들어 낸 id 는 버린다. 실제 후보에 있는 것만 남긴다.
    const byId = new Map(candidates.map((item) => [item.id, item]));
    const seen = new Set<string>();
    const picks = (parsed.picks ?? [])
      .filter((pick) => typeof pick?.id === 'string' && byId.has(pick.id!))
      .filter((pick) => !seen.has(pick.id!) && seen.add(pick.id!))
      .slice(0, 5)
      .map((pick) => ({
        productId: pick.id!,
        reason: typeof pick.reason === 'string' ? pick.reason.slice(0, 200) : '',
      }));

    if (picks.length < 3) {
      return json({ fallback: true, reason: '모델이 고른 실제 상품이 3개 미만입니다.' });
    }
    return json({ fallback: false, picks, candidateCount: candidates.length });
  } catch (error) {
    return json({ fallback: true, reason: `OpenAI 호출 실패: ${error}` });
  }
});
