import { readJsonLd } from '../extract.js';

/**
 * 어댑터가 공통으로 쓰는 목록 처리 도구.
 *
 * 사이트마다 목록 화면의 생김새는 다르지만,
 * "렌더 → 상품 링크 수집 → 같은 상품은 같은 주소로 정규화" 흐름은 같다.
 */

/**
 * 목록 주소에 페이지 번호를 붙여 여러 장으로 늘린다.
 * 같은 목록에서 나온 주소는 같은 분류 힌트를 갖는다.
 */
export function listingPages(baseUrls, { param = 'page', pages = 1, start = 1 } = {}) {
  const out = [];
  for (let page = start; page < start + pages; page += 1) {
    for (const base of baseUrls) {
      const href = typeof base === 'string' ? base : base.url;
      if (page === start) {
        out.push(href);
        continue;
      }
      const url = new URL(href);
      url.searchParams.set(param, String(page));
      out.push(url.href);
    }
  }
  return out;
}

/**
 * 목록 주소 → 분류 힌트 지도를 만든다.
 * 공급원이 상품에 분류를 달아 주지 않을 때 이 힌트를 쓴다.
 */
export function hintMap(entries) {
  const map = new Map();
  for (const [pattern, category] of entries) map.set(pattern, category);
  return (listingUrl) => {
    for (const [pattern, category] of map) {
      if (listingUrl.includes(pattern)) return category;
    }
    return null;
  };
}

/**
 * 목록 페이지에서 상품 상세 주소를 모은다.
 *
 * JSON-LD `ItemList` 가 있으면 그것을 먼저 읽고(공급원이 스스로 공개한 목록),
 * 없으면 DOM 의 링크를 본다. 무한 스크롤 목록을 위해 몇 번 스크롤한다.
 */
export async function collectLinks(
  page,
  listingUrl,
  { limit, match, canonical, scrolls = 3, waitMs = 1500 },
) {
  await page.goto(listingUrl, { waitUntil: 'domcontentloaded', timeout: 45_000 });
  await page.waitForTimeout(waitMs);

  const seen = new Set();
  const urls = [];

  const take = (href) => {
    if (urls.length >= limit) return;
    const found = match.exec(href);
    if (!found) return;
    const id = found[1];
    if (seen.has(id)) return;
    seen.add(id);
    urls.push(canonical(id));
  };

  // 1) 공급원이 공개한 ItemList
  for (const node of await readJsonLd(page)) {
    const list = node['@type'] === 'ItemList' ? node : node.mainEntity;
    if (list?.['@type'] !== 'ItemList') continue;
    for (const entry of list.itemListElement ?? []) {
      const href = entry?.url ?? entry?.item?.['@id'] ?? entry?.item;
      if (typeof href === 'string') take(href);
    }
  }

  // 2) DOM 링크 (필요하면 스크롤해서 더 불러온다)
  for (let i = 0; i <= scrolls && urls.length < limit; i += 1) {
    const hrefs = await page.$$eval('a[href]', (nodes) => nodes.map((n) => n.href));
    for (const href of hrefs) take(href);
    if (urls.length >= limit || i === scrolls) break;
    await page.mouse.wheel(0, 4000);
    await page.waitForTimeout(waitMs);
  }

  return urls;
}
