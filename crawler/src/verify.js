#!/usr/bin/env node
/**
 * 저장된 실제 상품이 화면에서 제대로 동작하는지 표본으로 확인한다.
 *
 *   node src/verify.js              # 출처마다 8건씩
 *   node src/verify.js --per 15     # 출처마다 15건씩
 *
 * 확인하는 것
 *   - 이미지 URL 이 실제로 이미지를 돌려주는지 (상품 카드가 비지 않는지)
 *   - 상품 URL 이 실제 판매 페이지로 열리는지 ("상품 보러 가기" CTA 가 가는 곳)
 *
 * 읽기만 하며 DB 를 바꾸지 않는다.
 */
import { createServiceClient, readEnvCredentials } from './supabase.js';
import { readFileSync, existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const BROWSER_UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

function loadDotEnv() {
  const file = path.join(ROOT, '.env');
  if (!existsSync(file)) return;
  for (const line of readFileSync(file, 'utf8').split(/\r?\n/)) {
    const match = /^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/.exec(line);
    if (!match) continue;
    if (!process.env[match[1]]) process.env[match[1]] = match[2].replace(/^["']|["']$/g, '');
  }
}

/** 주소 하나를 열어 본다. 본문은 받지 않고 상태와 종류만 본다. */
async function check(url, { expectImage = false } = {}) {
  try {
    const res = await fetch(url, {
      method: 'GET',
      headers: { 'user-agent': BROWSER_UA, accept: expectImage ? 'image/*' : 'text/html' },
      redirect: 'follow',
      signal: AbortSignal.timeout(20_000),
    });
    const type = res.headers.get('content-type') ?? '';
    const okType = expectImage ? type.startsWith('image/') : type.includes('html');
    return { ok: res.ok && okType, status: res.status, type: type.split(';')[0] };
  } catch (error) {
    return { ok: false, status: 0, type: String(error.name ?? error).slice(0, 30) };
  }
}

async function main() {
  loadDotEnv();
  const perSource = Number(
    process.argv[process.argv.indexOf('--per') + 1] > 0
      ? process.argv[process.argv.indexOf('--per') + 1]
      : 8,
  );

  const credentials = readEnvCredentials();
  if (!credentials.isConfigured) {
    console.error('SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY 가 필요합니다.');
    process.exitCode = 1;
    return;
  }
  const client = createServiceClient(credentials);

  const { data: sources, error } = await client
    .from('products')
    .select('source')
    .eq('is_demo', false)
    .not('source', 'is', null);
  if (error) {
    console.error(`상품을 읽지 못했습니다: ${error.message}`);
    process.exitCode = 1;
    return;
  }

  const ids = [...new Set((sources ?? []).map((row) => row.source))].sort();
  let totalOk = 0;
  let totalChecked = 0;

  for (const source of ids) {
    const { data: rows } = await client
      .from('products')
      .select('id, product_name, image_url, product_url')
      .eq('source', source)
      .eq('is_demo', false)
      .eq('is_active', true)
      .order('id')
      .limit(perSource);

    let imageOk = 0;
    let linkOk = 0;
    const failures = [];
    for (const row of rows ?? []) {
      const image = await check(row.image_url, { expectImage: true });
      const link = await check(row.product_url);
      if (image.ok) imageOk += 1;
      if (link.ok) linkOk += 1;
      if (!image.ok || !link.ok) {
        failures.push(
          `${row.id} 이미지=${image.ok ? 'OK' : image.status + ' ' + image.type}` +
            ` 링크=${link.ok ? 'OK' : link.status + ' ' + link.type}`,
        );
      }
      totalChecked += 1;
      if (image.ok && link.ok) totalOk += 1;
    }
    console.log(
      `${source.padEnd(8)} 표본 ${rows?.length ?? 0}건 · 이미지 ${imageOk} · 상품링크 ${linkOk}`,
    );
    for (const line of failures.slice(0, 5)) console.log(`   ! ${line}`);
  }

  console.log(`\n표본 ${totalChecked}건 중 이미지·링크 모두 정상 ${totalOk}건`);
  if (totalOk < totalChecked) process.exitCode = 1;
}

main();
