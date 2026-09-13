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

/** 근거가 없을 때 두는 기본 분류. `normalize.js` 와 같아야 한다. */
const DEFAULT_CATEGORY = 'hobby';

/**
 * "이 분야가 맞다"는 근거가 반드시 있어야 하는 분류.
 *
 * 사용자가 이 분류를 고르면 그 분야 상품을 기대한다. 근거 없이 들어와 있으면
 * 예전 규칙이 잘못 넣은 것이므로 기본 분류로 내린다.
 * 반대로 생활용품·데스크·문구처럼 포괄적인 분류는 근거가 없어도 그대로 둔다.
 * 규칙이 모르는 낱말이라고 해서 멀쩡한 분류를 흔들지 않기 위해서다.
 */
const STRICT_CATEGORIES = new Set([
  'book',
  'music',
  'appliance',
  'perfume',
  'beauty',
  'dessert',
  'tea_coffee',
  'shoes',
  'bag',
  'fashion_clothing',
  'candle',
]);

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

/** `normalize.js` 와 같은 목록. 사람 선물이 아닌 상품을 걸러낸다. */
const NOT_A_GIFT = [
  '강아지', '고양이', '반려견', '반려묘', '반려동물', '캣타워', '스크래쳐',
  '노즈워크', '사료', '펠리웨이', '캣닢', '캣닙', '애견', '애묘', '배변',
  '하네스', '산책줄', '펫드라이', '냥이', '멍멍이',
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
    const whole = `${row.sub_category ?? ''} ${row.product_name}`.toLowerCase();
    if (NOT_A_GIFT.some((word) => whole.includes(word))) {
      if (row.is_active) hide.push(row);
      continue;
    }
    // 수집할 때와 같은 순서: 공급원 분류 → 상품명·키워드.
    const text = `${row.product_name} ${(row.recommendation_keywords ?? []).join(' ')}`;
    const next =
      guessCategory(row.sub_category ?? '', null) ?? guessCategory(text, null);

    if (next) {
      if (next !== row.category_id) changes.push({ row, next });
      continue;
    }

    // 근거가 없는데 특정 분야로 박혀 있으면 예전 규칙이 잘못 넣은 것이다
    // ("캠핑 폴딩 테이블"이 '책'에 있는 식). 그때만 기본 분류로 내린다.
    if (STRICT_CATEGORIES.has(row.category_id)) {
      changes.push({ row, next: DEFAULT_CATEGORY });
    }
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
