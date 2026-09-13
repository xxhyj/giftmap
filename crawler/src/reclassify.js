#!/usr/bin/env node
/**
 * 이미 저장된 상품을 지금의 분류 규칙으로 다시 매긴다.
 *
 *   node src/reclassify.js --dry-run   # 무엇이 바뀌는지만 본다
 *   node src/reclassify.js             # 실제로 고친다
 *
 * 분류 규칙을 고쳐도 예전에 저장한 상품은 그대로라 화면에서 계속 어긋난다.
 * 상품명·분류(sub_category)만 가지고 다시 판단하며, 새로 수집하지 않는다.
 * 사람에게 주는 선물이 아닌 상품(반려동물 용품)은 화면에서 내린다(지우지 않는다).
 */
import { readFileSync, existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { guessCategory } from './normalize.js';
import { createServiceClient, readEnvCredentials } from './supabase.js';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

/** `normalize.js` 와 같은 목록. 사람 선물이 아닌 상품을 걸러낸다. */
const NOT_A_GIFT = [
  '강아지', '고양이', '반려견', '반려묘', '반려동물', '캣타워', '스크래쳐',
  '노즈워크', '사료', '펠리웨이', '캣닢', '캣닙',
];

function loadDotEnv() {
  const file = path.join(ROOT, '.env');
  if (!existsSync(file)) return;
  for (const line of readFileSync(file, 'utf8').split(/\r?\n/)) {
    const match = /^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/.exec(line);
    if (!match) continue;
    if (!process.env[match[1]]) process.env[match[1]] = match[2].replace(/^["']|["']$/g, '');
  }
}

async function loadAll(client) {
  const pageSize = 1000;
  const all = [];
  for (let from = 0; ; from += pageSize) {
    const { data, error } = await client
      .from('products')
      .select('id, product_name, sub_category, category_id, recommendation_keywords, is_active')
      .eq('is_demo', false)
      .order('id')
      .range(from, from + pageSize - 1);
    if (error) throw new Error(error.message);
    all.push(...(data ?? []));
    if ((data?.length ?? 0) < pageSize) return all;
  }
}

async function main() {
  loadDotEnv();
  const dryRun = process.argv.includes('--dry-run');
  const credentials = readEnvCredentials();
  if (!credentials.isConfigured) {
    console.error('SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY 가 필요합니다.');
    process.exitCode = 1;
    return;
  }
  const client = createServiceClient(credentials);
  const rows = await loadAll(client);

  const changes = [];
  const hide = [];
  for (const row of rows) {
    const text = `${row.sub_category ?? ''} ${row.product_name}`.toLowerCase();
    if (NOT_A_GIFT.some((word) => text.includes(word))) {
      if (row.is_active) hide.push(row);
      continue;
    }
    // 수집할 때와 같은 순서: 공급원 분류 → 상품명·키워드.
    const next =
      guessCategory(row.sub_category ?? '', null) ??
      guessCategory(
        `${row.product_name} ${(row.recommendation_keywords ?? []).join(' ')}`,
        null,
      );
    if (next && next !== row.category_id) changes.push({ row, next });
  }

  console.log(`대상 ${rows.length}건 · 분류 변경 ${changes.length}건 · 화면에서 내릴 상품 ${hide.length}건`);
  for (const { row, next } of changes.slice(0, 15)) {
    console.log(`  ${row.category_id} → ${next.padEnd(18)} ${row.product_name.slice(0, 34)}`);
  }
  if (dryRun) {
    console.log('--dry-run 이라 DB 를 고치지 않았습니다.');
    return;
  }

  let done = 0;
  for (const { row, next } of changes) {
    const { error } = await client
      .from('products')
      .update({ category_id: next })
      .eq('id', row.id);
    if (error) {
      console.warn(`  ! ${row.id} 실패: ${error.message}`);
      continue;
    }
    done += 1;
  }
  for (const row of hide) {
    // 지우지 않는다. 화면에서만 내린다.
    await client.from('products').update({ is_active: false }).eq('id', row.id);
  }
  console.log(`분류 수정 ${done}건 · 비활성 처리 ${hide.length}건 완료`);
}

main();
