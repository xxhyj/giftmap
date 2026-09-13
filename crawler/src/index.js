#!/usr/bin/env node
/**
 * Giftmap 상품 수집기 (MCP 없이 단독 실행된다).
 *
 *   node src/index.js                                        # 모든 공급원
 *   node src/index.js --source 10x10 --limit 300             # 한 공급원만
 *   node src/index.js --source all --limit 500 --rounds 8    # 전부, 넓게
 *   node src/index.js --limit 5 --dry-run                    # 수집만 하고 파일로 저장
 *   node src/index.js --headed                               # 브라우저 창을 띄워 확인
 *
 * 실패해도 앱은 멈추지 않는다. 수집 결과는 항상 out/ 에 남고,
 * 업로드가 실패해도 DB 의 기존 상품은 그대로다.
 */
import { writeFile, mkdir } from 'node:fs/promises';
import { readFileSync, existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { adapters as allAdapters, adapterById, adapterIds } from './adapters/index.js';
import { openBrowser } from './browser.js';
import { detectAccessWall, extractProduct } from './extract.js';
import { toProductRow } from './normalize.js';
import { isAllowed, loadRobots } from './robots.js';
import {
  createServiceClient,
  loadDedupeKeys,
  readEnvCredentials,
  upsertProducts,
} from './supabase.js';

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
    source: 'all',
    limit: 300,
    dryRun: false,
    headless: true,
    // 하위 분류를 따라 내려가는 최대 횟수. 무한히 넓어지지 않게 막는다.
    maxRounds: 6,
  };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--source') args.source = argv[++i];
    else if (arg === '--limit') args.limit = Math.max(1, Number(argv[++i]) || 300);
    else if (arg === '--dry-run') args.dryRun = true;
    else if (arg === '--headed') args.headless = false;
    else if (arg === '--rounds') args.maxRounds = Math.max(1, Number(argv[++i]) || 6);
  }
  return args;
}

/**
 * 공급원 하나에서 상품을 모은다.
 *
 * 1회차는 어댑터가 정한 시작 목록에서, 그다음부터는 수집한 상품이 알려준
 * 하위 분류로 범위를 넓힌다. 목표 개수를 채우거나 새 목록이 없으면 멈춘다.
 */
async function collectFromAdapter(adapter, page, args) {
  const rows = [];
  const skipped = [];
  const seenIds = new Set();
  const visitedListings = new Set();
  const visitedDetails = new Set();
  const collectedAt = new Date().toISOString();

  const { rules } = await loadRobots(adapter.origin).catch(() => ({ rules: null }));
  const allowedPath = (url) => {
    try {
      return isAllowed(rules, new URL(url).pathname);
    } catch {
      return false;
    }
  };

  const startListings = adapter.listingUrls.filter(allowedPath);
  if (startListings.length === 0) {
    skipped.push({ url: adapter.origin, reason: 'robots.txt 가 목록 경로를 허용하지 않음' });
    return { rows, skipped };
  }

  // 상세 URL 이 어떤 목록에서 나왔는지 기억해 분류 힌트로 쓴다.
  const hintByUrl = new Map();

  /** 목록 한 묶음에서 상세 URL 을 모은다. 이미 본 목록은 건너뛴다. */
  async function gatherDetailUrls(listings, budget) {
    const urls = [];
    // 한 목록에 결과가 몰리지 않도록 목록마다 가져올 개수를 나눈다.
    const perListing = Math.max(1, Math.ceil(budget / listings.length));
    for (const listing of listings) {
      if (urls.length >= budget) break;
      if (visitedListings.has(listing)) continue;
      visitedListings.add(listing);
      let found = [];
      try {
        found = await adapter.collectProductUrls(
          page,
          listing,
          Math.min(perListing, budget - urls.length),
        );
      } catch (error) {
        skipped.push({ url: listing, reason: `목록 실패: ${error.message ?? error}` });
        continue;
      }
      for (const url of found) {
        if (!allowedPath(url)) {
          skipped.push({ url, reason: 'robots disallow' });
          continue;
        }
        if (visitedDetails.has(url) || urls.includes(url)) continue;
        const hint = adapter.categoryFor?.(listing) ?? null;
        if (hint) hintByUrl.set(url, hint);
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
        let raw = await extractProduct(page);
        if (!raw) {
          skipped.push({ url, reason: 'no JSON-LD / meta' });
          continue;
        }
        // 공급원이 JSON-LD 로 주지 않는 값(예: 도서 가격)을 어댑터가 보완한다.
        raw = (await adapter.enrich?.(page, raw)) ?? raw;
        raws.push(raw);
        const row = toProductRow(
          { ...raw, productUrl: raw.productUrl ?? url },
          {
            sourceId: adapter.id,
            sourceLabel: adapter.label,
            collectedAt,
            categoryHint: hintByUrl.get(url) ?? null,
          },
        );
        if (!row) {
          skipped.push({ url, reason: 'missing name or url' });
          continue;
        }
        if (seenIds.has(row.id)) continue;
        seenIds.add(row.id);
        rows.push(row);
        if (rows.length % 25 === 0) console.log(`  … ${adapter.label} ${rows.length}건`);
      } catch (error) {
        skipped.push({ url, reason: String(error.message ?? error) });
      }
      await page.waitForTimeout(600); // 공급원 부하를 낮춘다.
    }
    return raws;
  }

  let listings = startListings;
  let round = 1;
  while (rows.length < args.limit && listings.length > 0 && round <= args.maxRounds) {
    const detailUrls = await gatherDetailUrls(listings, args.limit - rows.length);
    console.log(
      `[${adapter.id}] ${round}회차 · 목록 ${listings.length}개 · 상세 후보 ${detailUrls.length}건`,
    );
    if (detailUrls.length === 0) break;

    const raws = await collectDetails(detailUrls);
    const discovered = adapter.discoverListings?.(raws) ?? [];
    listings = discovered.filter((url) => allowedPath(url) && !visitedListings.has(url));
    round += 1;
  }

  return { rows, skipped };
}

/**
 * 같은 상품을 한 번만 남긴다.
 *
 * 고르는 순서는 (1) 가격을 아는 것 (2) 품절이 아닌 것 (3) 싼 것이고,
 * 모두 같으면 id 가 작은 것을 골라 실행할 때마다 결과가 같게 한다.
 * `known` 은 이미 DB 에 있는 중복키 → 상품 id 지도다.
 */
export function mergeDuplicates(rows, known = new Map()) {
  const byKey = new Map();
  const merged = [];
  let dropped = 0;

  const better = (a, b) => {
    if ((a.price === null) !== (b.price === null)) return a.price !== null;
    if ((a.in_stock === false) !== (b.in_stock === false)) return a.in_stock !== false;
    if (a.price !== null && b.price !== null && a.price !== b.price) return a.price < b.price;
    return a.id < b.id;
  };

  for (const row of rows) {
    const key = row.dedupe_key;
    if (!key) {
      merged.push(row);
      continue;
    }
    // 이미 DB 에 같은 상품이 다른 id 로 있으면 새로 만들지 않는다.
    const existingId = known.get(key);
    if (existingId && existingId !== row.id) {
      dropped += 1;
      continue;
    }
    const seen = byKey.get(key);
    if (!seen) {
      byKey.set(key, row);
      merged.push(row);
      continue;
    }
    dropped += 1;
    if (better(row, seen)) {
      merged[merged.indexOf(seen)] = row;
      byKey.set(key, row);
    }
  }

  return { merged, dropped };
}

async function main() {
  loadDotEnv();
  const args = parseArgs(process.argv.slice(2));

  const targets =
    args.source === 'all' ? allAdapters : [adapterById(args.source)].filter(Boolean);
  if (targets.length === 0) {
    console.error(`알 수 없는 공급원: ${args.source} (사용 가능: all, ${adapterIds.join(', ')})`);
    process.exitCode = 1;
    return;
  }

  const browser = await openBrowser({ headless: args.headless });
  const page = await browser.context.newPage();

  const bySource = {};
  let rows = [];
  const skipped = [];
  try {
    for (const adapter of targets) {
      console.log(`\n=== ${adapter.label} (${adapter.id}) ===`);
      try {
        const result = await collectFromAdapter(adapter, page, args);
        bySource[adapter.id] = { label: adapter.label, collected: result.rows.length };
        rows = rows.concat(result.rows);
        skipped.push(...result.skipped.map((item) => ({ ...item, source: adapter.id })));
        console.log(`[${adapter.id}] 수집 ${result.rows.length}건`);
      } catch (error) {
        // 한 공급원이 실패해도 나머지는 계속한다.
        bySource[adapter.id] = {
          label: adapter.label,
          collected: 0,
          error: String(error.message ?? error),
        };
        console.error(`[${adapter.id}] 실패: ${error.message ?? error}`);
      }
    }
  } finally {
    await browser.close();
  }

  const credentials = readEnvCredentials();
  const client = credentials.isConfigured ? createServiceClient(credentials) : null;

  // 이미 DB 에 있는 상품과도 중복을 맞춘다.
  const known = client && !args.dryRun ? await loadDedupeKeys(client) : new Map();
  const { merged, dropped } = mergeDuplicates(rows, known);

  const outDir = path.join(ROOT, 'out');
  await mkdir(outDir, { recursive: true });
  const outFile = path.join(outDir, 'products.json');
  await writeFile(
    outFile,
    JSON.stringify(
      { finishedAt: new Date().toISOString(), bySource, rows: merged, skipped },
      null,
      2,
    ),
    'utf8',
  );

  console.log('\n--- 수집 요약 ---');
  for (const [id, info] of Object.entries(bySource)) {
    console.log(
      `  ${info.label}(${id}): ${info.collected}건${info.error ? ` · 실패: ${info.error}` : ''}`,
    );
  }
  console.log(`  중복 통합으로 제외: ${dropped}건`);
  console.log(`  올릴 상품: ${merged.length}건 / 건너뜀 ${skipped.length}건 → ${outFile}`);

  if (args.dryRun) {
    console.log('--dry-run 이라 Supabase 에는 올리지 않았습니다.');
    return;
  }
  if (!client) {
    console.warn(
      'SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY 가 없어 업로드를 건너뜁니다. crawler/.env.example 참고.',
    );
    return;
  }

  try {
    const { inserted } = await upsertProducts(client, merged);
    console.log(`Supabase upsert 완료: ${inserted}건 (is_demo = false)`);
  } catch (error) {
    console.error(`Supabase 업로드 실패: ${error.message}`);
    console.error('DB 의 기존 상품은 그대로입니다.');
    process.exitCode = 1;
  }
}

// 테스트가 mergeDuplicates 만 가져다 쓸 수 있도록, 직접 실행일 때만 수집을 시작한다.
if (process.argv[1] && process.argv[1].endsWith(path.basename(fileURLToPath(import.meta.url)))) {
  main();
}
