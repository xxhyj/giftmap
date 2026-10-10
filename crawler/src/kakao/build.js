/**
 * 카카오톡 선물하기 PlayMCP 로 수집한 원본(raw) 상품을 Supabase `products` 행으로 만든다.
 *
 * Playwright 크롤러와 달리 이 데이터는 MCP(PlayMCP `KakaotalkGift-SearchGift`)를
 * 통해 대화형으로 모은 결과를 JSON으로 받아서 처리한다. 수집 자체(검색 호출)는
 * 이 스크립트 밖에서 이뤄지고, 이 스크립트는 그 결과(`crawler/out/kakao_raw.json`)를
 * 읽어 정규화하고 Supabase에 올리는 일만 한다.
 */
import { readFile } from 'node:fs/promises';
import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { toProductRow } from '../normalize.js';
import { createServiceClient, readEnvCredentials, upsertProducts } from '../supabase.js';

const SOURCE_ID = 'kakao_gift';
const SOURCE_LABEL = '카카오톡 선물하기';

const here = path.dirname(fileURLToPath(import.meta.url));
const rawPath = path.join(here, '..', '..', 'out', 'kakao_raw.json');

/** dotenv 를 따로 두지 않고 `.env` 를 직접 읽는다(dependency 최소화). */
function loadDotEnv(dir) {
  const file = path.join(dir, '.env');
  if (!existsSync(file)) return;
  for (const line of readFileSync(file, 'utf8').split(/\r?\n/)) {
    const match = /^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/.exec(line);
    if (!match) continue;
    const value = match[2].replace(/^["']|["']$/g, '');
    if (!process.env[match[1]]) process.env[match[1]] = value;
  }
}

function toRawItem(item, categoryHint) {
  const price = typeof item.price === 'number' ? item.price : null;
  const listPrice =
    price !== null && item.discountRate > 0
      ? Math.round(price / (1 - item.discountRate / 100))
      : null;
  return {
    name: item.itemName,
    productUrl: item.link,
    sku: String(item.itemId),
    price,
    listPrice,
    imageUrl: item.itemImageUrl,
    brand: null,
    breadcrumb: [categoryHint],
    keywords: [],
    description: '',
    // PlayMCP 검색 결과는 재고 상태를 알려주지 않는다. 품절로 단정하지 않는다.
    availability: null,
  };
}

async function main() {
  loadDotEnv(path.join(here, '..', '..'));
  const { url, key, isConfigured } = readEnvCredentials();
  if (!isConfigured) {
    console.error('SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY 가 필요하다 (crawler/.env).');
    process.exitCode = 1;
    return;
  }

  const raw = JSON.parse(await readFile(rawPath, 'utf8'));
  const collectedAt = raw.collectedAt ?? new Date().toISOString();

  const rows = [];
  const seenIds = new Set();
  let rank = 0;
  for (const group of raw.groups) {
    for (const item of group.items) {
      const rawItem = toRawItem(item, group.categoryHint);
      const row = toProductRow(rawItem, {
        sourceId: SOURCE_ID,
        sourceLabel: SOURCE_LABEL,
        collectedAt,
        categoryHint: group.categoryHint,
        rank: rank++,
      });
      if (!row || seenIds.has(row.id)) continue;
      seenIds.add(row.id);
      rows.push(row);
    }
  }

  console.log(`정규화된 상품 ${rows.length}건 (원본 ${raw.groups.flatMap((g) => g.items).length}건)`);

  const client = createServiceClient({ url, key });
  const { inserted } = await upsertProducts(client, rows);
  console.log(`Supabase 에 ${inserted}건 upsert 완료 (source=${SOURCE_ID})`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
