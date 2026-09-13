#!/usr/bin/env node
/**
 * 저장된 실제 상품 현황을 한 번에 뽑는다.
 *
 *   node src/report.js
 *
 * 출처별·분류별 건수와, 앱 홈이 실제로 어떤 출처·분류로 채워지는지 보여 준다.
 * 홈 분포는 앱과 같은 규칙(출처+분류를 번갈아 뽑기)으로 계산해 화면과 맞춘다.
 * 읽기만 하며 DB 를 바꾸지 않는다.
 */
import { readFileSync, existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { createServiceClient, readEnvCredentials } from './supabase.js';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

function loadDotEnv() {
  const file = path.join(ROOT, '.env');
  if (!existsSync(file)) return;
  for (const line of readFileSync(file, 'utf8').split(/\r?\n/)) {
    const match = /^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/.exec(line);
    if (!match) continue;
    if (!process.env[match[1]]) process.env[match[1]] = match[2].replace(/^["']|["']$/g, '');
  }
}

/** 상품을 모두 읽는다. 많아질 수 있으므로 나눠 받는다. */
async function loadAll(client) {
  const pageSize = 1000;
  const all = [];
  for (let from = 0; ; from += pageSize) {
    const { data, error } = await client
      .from('products')
      .select('id, source, category_id, price, image_url, product_url, in_stock, is_demo, occasions, recipient_types')
      .eq('is_active', true)
      .order('id')
      .range(from, from + pageSize - 1);
    if (error) throw new Error(error.message);
    all.push(...(data ?? []));
    if ((data?.length ?? 0) < pageSize) return all;
  }
}

/**
 * 앱 홈과 같은 방식으로 섞는다(`ProductCatalog.interleave`).
 *
 * 출처 안에서 분류를 번갈아 뽑아 줄을 만들고, 그 줄들을 출처끼리 번갈아 합친다.
 * 출처를 바깥 고리에 두지 않으면 상품이 많은 출처가 앞자리를 다 가져간다.
 */
function interleave(items, limit) {
  const bySource = new Map();
  for (const item of items) {
    const source = item.source ?? 'bundle';
    if (!bySource.has(source)) bySource.set(source, new Map());
    const byCategory = bySource.get(source);
    if (!byCategory.has(item.category_id)) byCategory.set(item.category_id, []);
    byCategory.get(item.category_id).push(item);
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

  const out = [];
  for (let round = 0; out.length < limit; round += 1) {
    let took = false;
    for (const line of lines) {
      if (round >= line.length) continue;
      out.push(line[round]);
      took = true;
      if (out.length >= limit) break;
    }
    if (!took) break;
  }
  return out;
}

const count = (items, pick) => {
  const map = new Map();
  for (const item of items) {
    const key = pick(item) ?? '(없음)';
    map.set(key, (map.get(key) ?? 0) + 1);
  }
  return [...map.entries()].sort((a, b) => b[1] - a[1]);
};

const table = (rows, total) =>
  rows
    .map(([key, n]) => `    ${String(key).padEnd(18)} ${String(n).padStart(5)}  ${((n / total) * 100).toFixed(1)}%`)
    .join('\n');

async function main() {
  loadDotEnv();
  const credentials = readEnvCredentials();
  if (!credentials.isConfigured) {
    console.error('SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY 가 필요합니다.');
    process.exitCode = 1;
    return;
  }

  const all = await loadAll(createServiceClient(credentials));
  const real = all.filter((row) => !row.is_demo);
  const demo = all.filter((row) => row.is_demo);

  console.log(`실제 상품 ${real.length}건 · 데모 ${demo.length}건 (실제 상품 모드에서는 데모를 보여 주지 않는다)\n`);

  console.log('출처별');
  console.log(table(count(real, (row) => row.source), real.length));

  console.log('\n분류별');
  console.log(table(count(real, (row) => row.category_id), real.length));

  const missing = real.filter(
    (row) => !row.image_url || !row.product_url || row.price === null,
  );
  const soldOut = real.filter((row) => row.in_stock === false);
  console.log(
    `\n값이 빠진 상품: ${missing.length}건 (이미지·가격·판매 URL 중 하나라도 없는 것)`,
  );
  console.log(`품절로 확인된 상품: ${soldOut.length}건`);

  // 홈이 실제로 어떻게 채워지는지. 앱의 "부담 없는 선물"(5만원 이하) 자리와 같은 조건.
  const homeSource = real.filter((row) => row.price !== null && row.price <= 50000);
  const home = interleave(homeSource, 12);
  console.log('\n홈 "인기 상품" 12칸의 출처 분포');
  console.log(table(count(home, (row) => row.source), home.length));
  console.log('홈 "인기 상품" 12칸의 분류 분포');
  console.log(table(count(home, (row) => row.category_id), home.length));
}

main();
