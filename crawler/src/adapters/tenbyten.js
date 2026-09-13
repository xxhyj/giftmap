import { readJsonLd } from '../extract.js';
import { GIFT_KEYWORDS, searchListings } from './helpers.js';

/**
 * 선물 카테고리별 검색 목록.
 * robots.txt 가 `/search/` 를 허용한다. 분류 페이지만 쓰면 문구·취미에 쏠려
 * 향수·뷰티·식품·가전이 빠지므로 검색으로 넓힌다.
 */
const search = searchListings(
  (keyword) =>
    `https://www.10x10.co.kr/search/renewal/index.asp?rect=${encodeURIComponent(keyword)}`,
  GIFT_KEYWORDS,
);

/**
 * 텐바이텐(10x10) 어댑터.
 *
 * robots.txt 가 우리 User-Agent(ClaudeBot 계열)에게 `/shopping/`, `/category/`,
 * `/search/` 를 허용한다. 이 어댑터는 그 경로 안에서만 움직이며
 * 로그인·회원 영역(`/login/`, `/member/`, `/my10x10/`)에는 접근하지 않는다.
 *
 * 목록은 자바스크립트로 그려지므로 Playwright 로 렌더한 뒤 상품 링크를 모으고,
 * 상세 페이지에서 JSON-LD(Product/Offer)를 읽는다.
 */
export const tenByTenAdapter = {
  id: '10x10',
  label: '텐바이텐',
  origin: 'https://www.10x10.co.kr',

  /**
   * 수집 시작점. 공개 카테고리 목록 페이지다.
   * 한 카테고리에 몰리지 않도록 상위 분류를 고루 넣는다(`disp` 는 10x10 의 분류 코드).
   */
  listingUrls: [
    ...[101, 102, 103, 104, 106, 107, 109, 110, 111, 112].map(
      (disp) => `https://www.10x10.co.kr/shopping/category_list.asp?disp=${disp}`,
    ),
    ...search.urls,
  ],

  /** 검색으로 들어온 목록은 검색어가 곧 분류 힌트다. */
  categoryFor: (listingUrl) => search.hintOf(listingUrl),

  /**
   * 목록 페이지에서 상품 상세 URL 을 모은다.
   *
   * 목록도 JSON-LD `ItemList` 로 공개돼 있어 그것을 먼저 읽고,
   * 없을 때만 DOM 의 링크를 본다.
   */
  async collectProductUrls(page, listingUrl, limit) {
    await page.goto(listingUrl, { waitUntil: 'domcontentloaded', timeout: 45_000 });
    await page.waitForTimeout(1_500);

    // 검색 결과는 무한 스크롤이고 상품 id 를 data-item-id 로 노출한다.
    if (listingUrl.includes('/search/')) {
      return this._collectFromSearch(page, limit);
    }

    const nodes = await readJsonLd(page);
    const fromList = nodes
      .filter((node) => node['@type'] === 'ItemList' || node.mainEntity?.['@type'] === 'ItemList')
      .flatMap((node) => (node.mainEntity ?? node).itemListElement ?? [])
      .map((item) => item?.url ?? item?.item?.['@id'] ?? item?.item)
      .filter((url) => typeof url === 'string' && url.includes('category_prd.asp'));

    const hrefs =
      fromList.length > 0
        ? fromList
        : await page.$$eval('a[href*="category_prd.asp"]', (anchors) =>
            anchors.map((a) => a.href),
          );

    const seen = new Set();
    const urls = [];
    for (const href of hrefs) {
      const itemId = new URL(href).searchParams.get('itemid');
      if (!itemId || seen.has(itemId)) continue;
      seen.add(itemId);
      // 추적 파라미터를 떼어 항상 같은 URL 로 만든다.
      urls.push(`${this.origin}/shopping/category_prd.asp?itemid=${itemId}`);
      if (urls.length >= limit) break;
    }
    return urls;
  },

  /**
   * 검색 결과에서 상품 id 를 모은다.
   *
   * 목록이 스크롤에 따라 이어지므로, 목표 개수를 채우거나 더 늘지 않을 때까지
   * 내려간다. 공급원 부하를 생각해 스크롤 횟수에 상한을 둔다.
   */
  async _collectFromSearch(page, limit) {
    const idsOnPage = () =>
      page.$$eval('[data-item-id]', (nodes) =>
        nodes.map((node) => node.getAttribute('data-item-id')).filter(Boolean),
      );

    let ids = await idsOnPage();
    for (let i = 0; i < 12 && ids.length < limit; i += 1) {
      const before = ids.length;
      await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
      await page.waitForTimeout(1_100);
      ids = await idsOnPage();
      if (ids.length === before) break; // 더 나오지 않으면 멈춘다.
    }

    const seen = new Set();
    const urls = [];
    for (const id of ids) {
      if (seen.has(id)) continue;
      seen.add(id);
      urls.push(`${this.origin}/shopping/category_prd.asp?itemid=${id}`);
      if (urls.length >= limit) break;
    }
    return urls;
  },

  /**
   * 이미 수집한 상품의 breadcrumb 에서 하위 분류 목록 주소를 얻는다.
   *
   * 분류 목록 한 장이 20개까지만 공개되므로, 공급원이 스스로 드러낸
   * 하위 분류를 따라 내려가며 범위를 넓힌다. 새로 만든 주소가 아니라
   * 공급원이 링크로 공개한 주소만 쓴다.
   */
  discoverListings(rawItems) {
    const found = new Set();
    for (const raw of rawItems) {
      for (const url of raw.breadcrumbUrls ?? []) {
        if (!url.includes('category_list.asp')) continue;
        const disp = new URL(url).searchParams.get('disp');
        // 최상위 분류(3자리)는 이미 시작점에 있으므로 하위 분류만 새로 본다.
        if (!disp || disp.length <= 3) continue;
        found.add(`${this.origin}/shopping/category_list.asp?disp=${disp}`);
      }
    }
    return [...found].sort();
  },

  /** 상세 페이지를 연다. 값 추출은 공통 extract 모듈이 맡는다. */
  async openDetail(page, url) {
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 45_000 });
    await page.waitForTimeout(500);
  },
};
