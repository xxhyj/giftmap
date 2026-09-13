import { createClient } from '@supabase/supabase-js';

/**
 * 수집 결과를 Supabase 에 올린다.
 *
 * 키는 코드에 넣지 않고 환경변수로만 받는다(`crawler/.env` 또는 셸 환경).
 * 앱은 publishable(anon) 키로 읽기만 하고, 쓰기는 여기(서버 쪽)에서만 한다.
 */
export function readEnvCredentials(env = process.env) {
  const url = (env.SUPABASE_URL ?? '').trim();
  const key = (env.SUPABASE_SERVICE_ROLE_KEY ?? '').trim();
  return { url, key, isConfigured: url.length > 0 && key.length > 0 };
}

export function createServiceClient({ url, key }) {
  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

/**
 * 이미 DB 에 있는 중복키를 읽어 온다.
 *
 * 공급원이 달라 id 는 다르지만 같은 상품인 경우를 걸러내기 위해 쓴다.
 * 실패하면 빈 지도를 돌려주어 수집 자체가 멈추지 않게 한다.
 */
export async function loadDedupeKeys(client) {
  const map = new Map();
  const pageSize = 1000;
  for (let from = 0; ; from += pageSize) {
    const { data, error } = await client
      .from('products')
      .select('id, dedupe_key')
      .not('dedupe_key', 'is', null)
      .range(from, from + pageSize - 1);
    if (error) return map;
    for (const row of data ?? []) map.set(row.dedupe_key, row.id);
    if ((data?.length ?? 0) < pageSize) return map;
  }
}

/**
 * 상품을 upsert 한다. 같은 id 는 덮어쓰므로 여러 번 실행해도 중복되지 않는다.
 * 카테고리가 아직 없으면 먼저 만들어 외래 키 오류를 피한다.
 * 한 번에 너무 많이 보내지 않도록 나눠 올린다.
 */
export async function upsertProducts(client, rows, { categoryLabels = {} } = {}) {
  if (rows.length === 0) return { inserted: 0 };

  const categoryIds = [...new Set(rows.map((row) => row.category_id).filter(Boolean))];
  if (categoryIds.length > 0) {
    const { error } = await client.from('categories').upsert(
      categoryIds.map((id) => ({ id, label: categoryLabels[id] ?? id })),
      { onConflict: 'id', ignoreDuplicates: true },
    );
    if (error) throw new Error(`categories upsert 실패: ${error.message}`);
  }

  const chunkSize = 200;
  for (let from = 0; from < rows.length; from += chunkSize) {
    const chunk = rows.slice(from, from + chunkSize);
    const { error } = await client.from('products').upsert(chunk, { onConflict: 'id' });
    if (error) throw new Error(`products upsert 실패: ${error.message}`);
  }
  return { inserted: rows.length };
}

/**
 * 판매처별 가격·URL 을 저장한다.
 *
 * `products` 에 실제로 올라간 상품의 offer 만 남긴다.
 * 아직 DB 에 없는 상품을 가리키는 offer 는 외래 키에 걸리므로 버린다.
 */
export async function upsertOffers(client, offers, productRows) {
  if (!offers || offers.length === 0) return 0;

  const knownIds = new Set(productRows.map((row) => row.id));
  // 같은 (상품, 판매처) 는 한 번만 보낸다. 가장 싼 것을 남긴다.
  const byKey = new Map();
  for (const offer of offers) {
    if (!knownIds.has(offer.product_id) || !offer.source || !offer.source_url) continue;
    const key = `${offer.product_id}|${offer.source}`;
    const seen = byKey.get(key);
    if (!seen || (offer.price !== null && (seen.price === null || offer.price < seen.price))) {
      byKey.set(key, offer);
    }
  }

  const rows = [...byKey.values()];
  const chunkSize = 200;
  for (let from = 0; from < rows.length; from += chunkSize) {
    const { error } = await client
      .from('product_offers')
      .upsert(rows.slice(from, from + chunkSize), { onConflict: 'product_id,source' });
    // offer 는 부가 정보다. 실패해도 상품 자체는 이미 저장됐으므로 멈추지 않는다.
    if (error) {
      console.warn(`판매처 저장 실패(상품은 저장됨): ${error.message}`);
      return 0;
    }
  }
  return rows.length;
}
