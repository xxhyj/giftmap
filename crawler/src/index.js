#!/usr/bin/env node
/**
 * Giftmap 상품 수집기 (MCP 없이 단독 실행된다).
 *
 *   node src/index.js --source 10x10 --limit 20            # 수집 + Supabase upsert
 *   node src/index.js --source 10x10 --limit 5 --dry-run   # 수집만 하고 파일로 저장
 *   node src/index.js --source 10x10 --limit 200 --rounds 8  # 하위 분류까지 넓게
 *
 * 실패해도 앱은 멈추지 않는다. 앱은 Supabase 읽기가 실패하면 번들 Mock 으로 되돌아간다.
 */
import { writeFile, mkdir } from 'node:fs/promises';
import { readFileSync, existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { adapterById, adapterIds } from './adapters/index.js';
import { openBrowser } from './browser.js';
import { detectAccessWall, extractProduct } from './extract.js';
import { toProductRow } from './normalize.js';
import { createServiceClient, readEnvCredentials, upsertProducts } from './supabase.js';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

/** dotenv 를 따로 두지 않고 `.env` 를 직접 읽는다(dependency 최소화). */
function loadDotEnv() {
  const file = path.join(ROOT, '.env');
  if (!existsSync(file)) return;
  for (const line of readFileSync(file, 'utf8').split(/\r?\n/)) {
    const match = /^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/.exec(line);
    if (!match) continue;
    const value = match[2].replace(/^["']|["']$/g, '');
    if (!process.env[match[1]]) process.env[match[1]] = value;
  }
}

function parseArgs(argv) {
  const args = {
    source: adapterIds[0],
    limit: 20,
    dryRun: false,
    headless: true,
    // 하위 분류를 따라 내려가는 최대 횟수. 무한히 넓어지지 않게 막는다.
    maxRounds: 6,
  };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--source') args.source = argv[++i];
    else if (arg === '--limit') args.limit = Math.max(1, Number(argv[++i]) || 20);
    else if (arg === '--dry-run') args.dryRun = true;
    else if (arg === '--headed') args.headless = false;
    else if (arg === '--rounds') args.maxRounds = Math.max(1, Number(argv[++i]) || 6);
  }
  return args;
}

async function main() {
  loadDotEnv();
  const args = parseArgs(process.argv.slice(2));
  const adapter = adapterById(args.source);
  if (!adapter) {
    console.error(`알 수 없는 공급원: ${args.source} (사용 가능: ${adapterIds.join(', ')})`);
    process.exitCode = 1;
    return;
  }

  const { loadRobots, isAllowed } = await import('./robots.js');
  const { rules } = await loadRobots(adapter.origin);
  const allowedPath = (url) => isAllowed(rules, new URL(url).pathname);

  const usableListings = adapter.listingUrls.filter(allowedPath);
  if (usableListings.length === 0) {
    console.error(`[${adapter.id}] robots.txt 가 목록 경로를 허용하지 않아 중단합니다.`);
    process.exitCode = 1;
    return;
  }

  const collectedAt = new Date().toISOString();
  const browser = await openBrowser({ headless: args.headless });
  const page = await browser.context.newPage();

  const rows = [];
  const skipped = [];
  const seenIds = new Set();
  const visitedListings = new Set();
  const visitedDetails = new Set();

  /** 목록 한 묶음에서 상세 URL 을 모은다. 이미 본 목록은 건너뛴다. */
  async function gatherDetailUrls(listings, budget) {
    const urls = [];
    // 한 목록에 결과가 몰리지 않도록 목록마다 가져올 개수를 나눈다.
    const perListing = Math.max(1, Math.ceil(budget / listings.length));
    for (const listing of listings) {
      if (urls.length >= budget) break;
      if (visitedListings.has(listing)) continue;
      visitedListings.add(listing);
      const take = Math.min(perListing, budget - urls.length);
      let found = [];
      try {
        found = await adapter.collectProductUrls(page, listing, take);
      } catch (error) {
        skipped.push({ url: listing, reason: `listing 실패: ${error.message ?? error}` });
        continue;
      }
      for (const url of found) {
        if (!allowedPath(url)) {
          skipped.push({ url, reason: 'robots disallow' });
          continue;
        }
        if (visitedDetails.has(url) || urls.includes(url)) continue;
        urls.push(url);
      }
    }
    return urls;
  }

  /** 상세 페이지를 돌며 행을 만든다. 이번 회차에 읽은 원본도 함께 돌려준다. */
  async function collectDetails(detailUrls) {
    const raws = [];
    for (const url of detailUrls) {
      if (rows.length >= args.limit) break;
      visitedDetails.add(url);
      try {
        await adapter.openDetail(page, url);
        const wall = await detectAccessWall(page);
        if (wall) {
          // 우회하지 않는다. 그대로 건너뛴다.
          skipped.push({ url, reason: `access wall (${wall})` });
          continue;
        }
        const raw = await extractProduct(page);
        if (!raw) {
          skipped.push({ url, reason: 'no JSON-LD / meta' });
          continue;
        }
        raws.push(raw);
        const row = toProductRow(
          { ...raw, productUrl: raw.productUrl ?? url },
          { sourceId: adapter.id, sourceLabel: adapter.label, collectedAt },
        );
        if (!row) {
          skipped.push({ url, reason: 'missing name or url' });
          continue;
        }
        if (seenIds.has(row.id)) continue;
        seenIds.add(row.id);
        rows.push(row);
        console.log(
          `  · ${row.id} ${row.product_name.slice(0, 34)} ` +
            `${row.price === null ? '(가격 확인 필요)' : row.price.toLocaleString('ko-KR') + '원'} [${raw.source}]`,
        );
      } catch (error) {
        skipped.push({ url, reason: String(error.message ?? error) });
      }
      await page.waitForTimeout(700); // 공급원 부하를 낮춘다.
    }
    return raws;
  }

  try {
    // 1회차는 어댑터가 정한 시작 목록에서, 그다음부터는 수집한 상품이 알려준
    // 하위 분류로 범위를 넓힌다. 목표 개수를 채우거나 새 분류가 없으면 멈춘다.
    let listings = usableListings;
    let round = 1;
    while (rows.length < args.limit && listings.length > 0 && round <= args.maxRounds) {
      const detailUrls = await gatherDetailUrls(listings, args.limit - rows.length);
      console.log(
        `[${adapter.id}] ${round}회차 · 분류 ${listings.length}개 · 상세 후보 ${detailUrls.length}건`,
      );
      if (detailUrls.length === 0) break;

      const raws = await collectDetails(detailUrls);
      const discovered = adapter.discoverListings?.(raws) ?? [];
      listings = discovered.filter(
        (url) => allowedPath(url) && !visitedListings.has(url),
      );
      round += 1;
    }
  } finally {
    await browser.close();
  }

  // 결과는 항상 파일로 남겨 두어 업로드가 실패해도 확인할 수 있다.
  const outDir = path.join(ROOT, 'out');
  await mkdir(outDir, { recursive: true });
  const outFile = path.join(outDir, `${adapter.id}.json`);
  await writeFile(outFile, JSON.stringify({ collectedAt, rows, skipped }, null, 2), 'utf8');
  console.log(`\n수집 ${rows.length}건 / 건너뜀 ${skipped.length}건 → ${outFile}`);

  if (args.dryRun) {
    console.log('--dry-run 이라 Supabase 에는 올리지 않았습니다.');
    return;
  }

  const credentials = readEnvCredentials();
  if (!credentials.isConfigured) {
    console.warn(
      'SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY 가 없어 업로드를 건너뜁니다. ' +
        'crawler/.env.example 를 참고하세요. (앱은 기존 Mock 데이터로 계속 동작합니다)',
    );
    return;
  }

  try {
    const client = createServiceClient(credentials);
    const { inserted } = await upsertProducts(client, rows);
    console.log(`Supabase upsert 완료: ${inserted}건 (is_demo = false)`);
  } catch (error) {
    console.error(`Supabase 업로드 실패: ${error.message}`);
    console.error('앱은 기존 데이터(원격 실패 시 번들 Mock)로 계속 동작합니다.');
    process.exitCode = 1;
  }
}

main();
