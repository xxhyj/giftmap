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
 * 상품을 upsert 한다. 같은 id 는 덮어쓰므로 여러 번 실행해도 중복되지 않는다.
 * 카테고리가 아직 없으면 먼저 만들어 외래 키 오류를 피한다.
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

  const { error } = await client.from('products').upsert(rows, { onConflict: 'id' });
  if (error) throw new Error(`products upsert 실패: ${error.message}`);
  return { inserted: rows.length };
}
