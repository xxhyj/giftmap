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

/**
 * 선물 카테고리별 검색어.
 *
 * 분류 페이지만으로는 한 공급원의 특정 분야(문구·취미)에 쏠린다.
 * 검색어로 넓게 훑어 향수·뷰티·식품·가전까지 고르게 담기게 한다.
 * `[검색어, 앱 카테고리 id]` 형태이며 카테고리 id 는 Supabase `categories` 와 같다.
 */
export const GIFT_KEYWORDS = [
  // 향수·뷰티
  ['향수', 'perfume'],
  ['perfume', 'perfume'],
  ['디퓨저', 'candle'],
  ['향초', 'candle'],
  ['인센스', 'candle'],
  ['립스틱', 'beauty'],
  ['립밤', 'beauty'],
  ['틴트', 'beauty'],
  ['파운데이션', 'beauty'],
  ['쿠션', 'beauty'],
  ['스킨케어', 'beauty'],
  ['세럼', 'beauty'],
  ['선크림', 'beauty'],
  ['마스크팩', 'beauty'],
  ['핸드크림', 'hand_care'],
  ['바디로션', 'body_care'],
  ['입욕제', 'body_care'],
  ['샴푸', 'body_care'],
  // 식품·음료
  ['디저트', 'dessert'],
  ['쿠키', 'dessert'],
  ['초콜릿', 'dessert'],
  ['마카롱', 'dessert'],
  ['잼', 'dessert'],
  ['커피', 'tea_coffee'],
  ['원두', 'tea_coffee'],
  ['드립백', 'tea_coffee'],
  ['티세트', 'tea_coffee'],
  ['홍차', 'tea_coffee'],
  ['꿀', 'dessert'],
  // 생활·주방
  ['텀블러', 'tumbler'],
  ['보온병', 'tumbler'],
  ['머그컵', 'tumbler'],
  ['식기세트', 'living'],
  ['수건', 'living'],
  ['담요', 'living'],
  ['쿠션', 'living'],
  ['수납', 'living'],
  ['주방용품', 'living'],
  // 패션·잡화
  ['지갑', 'wallet'],
  ['카드지갑', 'wallet'],
  ['목도리', 'fashion_accessory'],
  ['머플러', 'fashion_accessory'],
  ['장갑', 'fashion_accessory'],
  ['목걸이', 'fashion_accessory'],
  ['팔찌', 'fashion_accessory'],
  ['에코백', 'bag'],
  ['파우치', 'bag'],
  ['잠옷', 'homewear'],
  ['수면양말', 'homewear'],
  ['슬리퍼', 'shoes'],
  // 가전·디지털
  ['블루투스 스피커', 'appliance'],
  ['무선이어폰', 'appliance'],
  ['가습기', 'appliance'],
  ['미니 선풍기', 'appliance'],
  ['전기포트', 'appliance'],
  ['조명', 'appliance'],
  ['무드등', 'appliance'],
  ['보조배터리', 'appliance'],
  // 취미·문구
  ['퍼즐', 'hobby'],
  ['보드게임', 'hobby'],
  ['원예', 'hobby'],
  ['드로잉', 'hobby'],
  ['만년필', 'stationery'],
  ['다이어리', 'stationery'],
];

/** 검색어 목록으로 목록 주소를 만든다. 주소 → 카테고리 힌트 지도도 함께 준다. */
export function searchListings(buildUrl, keywords = GIFT_KEYWORDS, { pages = 1 } = {}) {
  const urls = [];
  const hints = new Map();
  for (const [keyword, category] of keywords) {
    for (let page = 1; page <= pages; page += 1) {
      const url = buildUrl(keyword, page);
      urls.push(url);
      hints.set(url, category);
    }
  }
  return { urls, hintOf: (url) => hints.get(url) ?? null };
}

/**
 * sitemap 에서 상품 주소를 읽는다.
 *
 * 공급원이 스스로 공개한 주소 목록이라 목록 화면을 훑는 것보다 정확하다.
 * 한쪽에 몰리지 않도록 일정 간격으로 건너뛰며 고르고, 같은 sitemap 이면
 * 항상 같은 순서가 나오도록 정렬한다.
 */
export async function sitemapProductUrls(
  sitemapUrl,
  { match, limit = 100, userAgent } = {},
) {
  const res = await fetch(sitemapUrl, {
    headers: userAgent ? { 'user-agent': userAgent } : undefined,
    signal: AbortSignal.timeout(30_000),
  });
  if (!res.ok) throw new Error(`sitemap 응답 ${res.status}`);

  const xml = await res.text();
  const all = [...xml.matchAll(/<loc>\s*([^<\s]+)\s*<\/loc>/g)]
    .map((found) => found[1])
    .filter((url) => match.test(url));
  all.sort();
  if (all.length <= limit) return all;

  // 앞쪽만 쓰면 같은 분류가 몰리므로 전체에서 고르게 뽑는다.
  const stride = Math.floor(all.length / limit);
  const out = [];
  for (let i = 0; out.length < limit && i < all.length; i += stride) out.push(all[i]);
  return out;
}
