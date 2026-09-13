import { GIFT_KEYWORDS, searchListings } from './helpers.js';

/**
 * 29CM 어댑터.
 *
 * robots.txt 의 `*` 그룹이 상품·검색 경로를 허용한다.
 * 검색 결과가 한 화면에 상품 링크(`/catalog/<번호>`)를 그대로 노출하고,
 * 상세에는 `schema.org/Product` JSON-LD(이름·브랜드·가격·재고·분류)가 있다.
 * 이미지만 JSON-LD에 없어 `og:image`로 보완한다.
 *
 * 향수·뷰티·패션·리빙까지 선물로 고르기 좋은 분야가 고르게 있다.
 */
const search = searchListings(
  (keyword) => `https://search.29cm.co.kr/search?keyword=${encodeURIComponent(keyword)}`,
  GIFT_KEYWORDS,
);

export const c29cmAdapter = {
  id: '29cm',
  label: '29CM',
  origin: 'https://search.29cm.co.kr',

  listingUrls: search.urls,

  /** 상세 breadcrumb 이 정확하지만, 없을 때를 대비해 검색어를 힌트로 넘긴다. */
  categoryFor: (listingUrl) => search.hintOf(listingUrl),

  async collectProductUrls(page, listingUrl, limit) {
    await page.goto(listingUrl, { waitUntil: 'domcontentloaded', timeout: 45_000 });
    await page.waitForTimeout(3_000);

    const hrefs = await page.$$eval('a[href*="/catalog/"]', (nodes) =>
      nodes.map((node) => node.href),
    );

    const seen = new Set();
    const urls = [];
    for (const href of hrefs) {
      const found = /\/catalog\/(\d+)/.exec(href);
      if (!found || seen.has(found[1])) continue;
      seen.add(found[1]);
      urls.push(`https://product.29cm.co.kr/catalog/${found[1]}`);
      if (urls.length >= limit) break;
    }
    return urls;
  },

  discoverListings() {
    return [];
  },

  /** JSON-LD 에 없는 이미지를 공개 메타데이터에서 채운다. */
  async enrich(page, raw) {
    if (raw.imageUrl) return raw;
    const imageUrl = await page.evaluate(
      () =>
        document.querySelector('meta[property="og:image"]')?.getAttribute('content') ?? null,
    );
    return imageUrl ? { ...raw, imageUrl } : raw;
  },

  async openDetail(page, url) {
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 45_000 });
    await page.waitForTimeout(1_500);
  },
};
